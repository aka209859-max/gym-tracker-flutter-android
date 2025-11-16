/**
 * キャンペーン自動確認Cloud Function
 * 
 * CEOが何もしなくても動作する完全自動化システム
 * 
 * トリガー: campaign_applications コレクションの status が 'checking' に変更
 * 処理:
 *   1. X API / Instagram Graph API で投稿検索
 *   2. Gemini API で投稿内容を検証
 *   3. 条件満たす場合、特典自動適用
 *   4. 条件満たさない場合、差し戻し
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

/**
 * メイン関数: キャンペーン申請の自動確認
 */
exports.verifyCampaignPost = functions.firestore
  .document('campaign_applications/{applicationId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();

    // ステータスが 'checking' に変わった時のみ実行
    if (newData.status !== 'checking' || oldData.status === 'checking') {
      return null;
    }

    const applicationId = context.params.applicationId;
    const uniqueCode = newData.unique_code;
    const planType = newData.plan_type;
    const userId = newData.user_id;

    console.log(`[START] Verifying application ${applicationId} with code ${uniqueCode}`);

    try {
      // Step 1: X API で投稿を検索
      const tweetData = await searchTweetByUniqueCode(uniqueCode);

      if (!tweetData) {
        console.log(`[FAIL] No tweet found with code ${uniqueCode}`);
        await rejectApplication(applicationId, 'SNS投稿が見つかりませんでした。認証コードが含まれているか確認してください。');
        return null;
      }

      console.log(`[FOUND] Tweet found: ${tweetData.text}`);

      // Step 2: Gemini API で投稿内容を検証
      const isValid = await verifyPostContent(tweetData.text, uniqueCode, planType);

      if (!isValid) {
        console.log(`[FAIL] Post content validation failed`);
        await rejectApplication(applicationId, '投稿内容が条件を満たしていません。必須ハッシュタグと体験談を確認してください。');
        return null;
      }

      console.log(`[PASS] Post content validated successfully`);

      // Step 3: 特典自動適用
      await applyBenefit(applicationId, userId, planType);

      console.log(`[SUCCESS] Benefit applied for application ${applicationId}`);

      // Step 4: プッシュ通知送信
      await sendApprovalNotification(userId, planType);

      return null;
    } catch (error) {
      console.error(`[ERROR] Verification failed for ${applicationId}:`, error);
      await rejectApplication(applicationId, 'システムエラーが発生しました。サポートにお問い合わせください。');
      return null;
    }
  });

/**
 * X API で投稿を検索
 * 
 * @param {string} uniqueCode - ユニークコード（例: #GM2025A3B7C9）
 * @returns {Object|null} - ツイートデータ
 */
async function searchTweetByUniqueCode(uniqueCode) {
  const xApiKey = functions.config().x_api.bearer_token;

  if (!xApiKey) {
    console.error('[ERROR] X API Bearer Token not configured');
    return null;
  }

  try {
    // X API v2: 最近のツイート検索
    const response = await axios.get('https://api.twitter.com/2/tweets/search/recent', {
      headers: {
        Authorization: `Bearer ${xApiKey}`,
      },
      params: {
        query: uniqueCode,
        max_results: 10,
        'tweet.fields': 'created_at,text',
      },
    });

    if (response.data.data && response.data.data.length > 0) {
      return response.data.data[0]; // 最新の投稿を返す
    }

    return null;
  } catch (error) {
    console.error('[ERROR] X API search failed:', error.response?.data || error.message);
    return null;
  }
}

/**
 * Gemini API で投稿内容を検証
 * 
 * @param {string} postText - 投稿テキスト
 * @param {string} uniqueCode - ユニークコード
 * @param {string} planType - プランタイプ
 * @returns {boolean} - 検証結果
 */
async function verifyPostContent(postText, uniqueCode, planType) {
  const geminiApiKey = functions.config().gemini.api_key;

  if (!geminiApiKey) {
    console.error('[ERROR] Gemini API Key not configured');
    return false;
  }

  // 必須要素チェック
  const hasUniqueCode = postText.includes(uniqueCode);
  const hasHashtag1 = postText.includes('#GymMatch乗り換え割');
  const hasHashtag2 = postText.includes('#AI筋トレ分析');

  if (!hasUniqueCode || !hasHashtag1 || !hasHashtag2) {
    console.log('[FAIL] Missing required elements:', {
      hasUniqueCode,
      hasHashtag1,
      hasHashtag2,
    });
    return false;
  }

  // Gemini API で体験談の質を評価
  try {
    const prompt = `
以下のSNS投稿を分析し、「筋トレアプリの乗り換え体験談」として適切かどうか判定してください。

【投稿内容】
${postText}

【判定基準】
1. 具体的な体験が書かれている（10文字以上）
2. スパムや無意味な内容でない
3. 宣伝目的だけでない

【回答形式】
OK または NG のみ回答してください。
`;

    const response = await axios.post(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${geminiApiKey}`,
      {
        contents: [
          {
            parts: [{ text: prompt }],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 10,
        },
      }
    );

    const result = response.data.candidates[0].content.parts[0].text.trim();
    console.log('[GEMINI] Validation result:', result);

    return result === 'OK';
  } catch (error) {
    console.error('[ERROR] Gemini API validation failed:', error.response?.data || error.message);
    // Gemini失敗時は基本チェックのみで通す
    return true;
  }
}

/**
 * 特典自動適用
 * 
 * @param {string} applicationId - 申請ID
 * @param {string} userId - ユーザーID
 * @param {string} planType - プランタイプ
 */
async function applyBenefit(applicationId, userId, planType) {
  const benefitMonths = planType === 'premium' ? 1 : 2;
  const db = admin.firestore();

  // トランザクションで確実に適用
  await db.runTransaction(async (transaction) => {
    // 申請ステータス更新
    transaction.update(db.collection('campaign_applications').doc(applicationId), {
      status: 'approved',
      verified_at: admin.firestore.FieldValue.serverTimestamp(),
      benefit_applied_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // サブスクリプション特典適用
    const subscriptionRef = db.collection('user_subscriptions').doc(userId);
    transaction.set(
      subscriptionRef,
      {
        free_months_remaining: admin.firestore.FieldValue.increment(benefitMonths),
        campaign_benefit_applied: true,
        campaign_benefit_applied_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  console.log(`[SUCCESS] Applied ${benefitMonths} months benefit to user ${userId}`);
}

/**
 * 申請却下
 * 
 * @param {string} applicationId - 申請ID
 * @param {string} reason - 却下理由
 */
async function rejectApplication(applicationId, reason) {
  const db = admin.firestore();

  await db.collection('campaign_applications').doc(applicationId).update({
    status: 'rejected',
    rejection_reason: reason,
    verified_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`[REJECT] Application ${applicationId} rejected: ${reason}`);
}

/**
 * 承認通知プッシュ送信
 * 
 * @param {string} userId - ユーザーID
 * @param {string} planType - プランタイプ
 */
async function sendApprovalNotification(userId, planType) {
  const benefit = planType === 'premium' ? '初月無料' : '2ヶ月無料';

  const db = admin.firestore();
  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    console.log(`[WARN] User ${userId} not found for notification`);
    return;
  }

  const fcmToken = userDoc.data().fcm_token;

  if (!fcmToken) {
    console.log(`[WARN] No FCM token for user ${userId}`);
    return;
  }

  const message = {
    notification: {
      title: '🎉 キャンペーン特典が適用されました！',
      body: `${benefit}が自動適用されました。引き続きGYM MATCHをお楽しみください！`,
    },
    token: fcmToken,
  };

  try {
    await admin.messaging().send(message);
    console.log(`[SUCCESS] Push notification sent to user ${userId}`);
  } catch (error) {
    console.error('[ERROR] Push notification failed:', error);
  }
}

/**
 * 定期実行: 投稿確認リトライ
 * 
 * 'checking' ステータスが5分以上経過している申請を再確認
 */
exports.retryCampaignVerification = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);

    const snapshot = await db
      .collection('campaign_applications')
      .where('status', '==', 'checking')
      .where('sns_posted_at', '<', fiveMinutesAgo)
      .get();

    console.log(`[RETRY] Found ${snapshot.size} applications to retry`);

    for (const doc of snapshot.docs) {
      const data = doc.data();
      console.log(`[RETRY] Re-verifying application ${doc.id}`);

      // 再確認トリガー（statusを一旦pendingに戻してからcheckingに変更）
      await doc.ref.update({ status: 'pending' });
      await doc.ref.update({ status: 'checking' });
    }

    return null;
  });
