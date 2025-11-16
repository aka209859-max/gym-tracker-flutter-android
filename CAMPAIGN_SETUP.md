# 🎉 完全自動化キャンペーンシステム - セットアップガイド

## 🎯 システム概要

**CEOが何もしなくても動作する**完全自動化キャンペーンシステム

### 自動化フロー
```
ユーザーが「投稿しました」タップ
  ↓
Firestore: status → 'checking'
  ↓
Cloud Function自動トリガー
  ↓
X API で投稿検索 (#GM2025XXXXXX)
  ↓
Gemini API で内容検証
  ↓
条件OK → 特典自動適用 + プッシュ通知
条件NG → 差し戻し + 理由通知
```

---

## 📋 セットアップ手順

### 1. Firebase プロジェクト設定

#### 1-1. Cloud Functions 有効化
```bash
# Firebase CLI インストール（初回のみ）
npm install -g firebase-tools

# Firebase ログイン
firebase login

# プロジェクト初期化（functions選択）
cd /home/user/flutter_app
firebase init functions
```

#### 1-2. Firebase Functions ディレクトリ構成
```
flutter_app/
├── functions/
│   ├── campaign_auto_verifier.js  ← メイン関数
│   ├── package.json
│   └── .gitignore
```

---

### 2. X API セットアップ

#### 2-1. X Developer Portal でアプリ作成
1. https://developer.twitter.com/en/portal/dashboard にアクセス
2. 新規アプリ作成
3. **Bearer Token** を取得

#### 2-2. Firebase に X API Key を設定
```bash
# X API Bearer Token を環境変数に設定
firebase functions:config:set x_api.bearer_token="YOUR_X_API_BEARER_TOKEN"

# 設定確認
firebase functions:config:get
```

**出力例**:
```json
{
  "x_api": {
    "bearer_token": "AAAAAAAAAAAAAAAAAAAAAxxxxxxxxxxxx"
  }
}
```

---

### 3. Gemini API セットアップ

#### 3-1. Google AI Studio で API Key 取得
1. https://makersuite.google.com/app/apikey にアクセス
2. API Key を作成

#### 3-2. Firebase に Gemini API Key を設定
```bash
# Gemini API Key を環境変数に設定
firebase functions:config:set gemini.api_key="YOUR_GEMINI_API_KEY"

# 設定確認
firebase functions:config:get
```

**出力例**:
```json
{
  "x_api": {
    "bearer_token": "AAAAAAAAAAAAAAAAAAAAAxxxxxxxxxxxx"
  },
  "gemini": {
    "api_key": "AIzaSyDxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  }
}
```

---

### 4. Cloud Functions デプロイ

#### 4-1. パッケージインストール
```bash
cd functions
npm install
```

#### 4-2. Functions デプロイ
```bash
# 全Functions デプロイ
firebase deploy --only functions

# 特定Function のみデプロイ
firebase deploy --only functions:verifyCampaignPost
firebase deploy --only functions:retryCampaignVerification
```

**デプロイ完了メッセージ**:
```
✔  functions[verifyCampaignPost(us-central1)] Successful create operation.
✔  functions[retryCampaignVerification(us-central1)] Successful create operation.

✔  Deploy complete!
```

---

### 5. Firestore セキュリティルール設定

#### 5-1. campaign_applications コレクション用ルール
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // キャンペーン申請コレクション
    match /campaign_applications/{applicationId} {
      // 自分の申請のみ読み取り可能
      allow read: if request.auth != null && 
                     resource.data.user_id == request.auth.uid;
      
      // 新規申請作成（自分のUIDのみ）
      allow create: if request.auth != null && 
                       request.resource.data.user_id == request.auth.uid;
      
      // ステータス更新（自分の申請で、checking への変更のみ）
      allow update: if request.auth != null && 
                       resource.data.user_id == request.auth.uid &&
                       request.resource.data.status == 'checking';
    }
    
    // 管理者のみ全権限（CEOダッシュボード用）
    match /campaign_applications/{applicationId} {
      allow read, write: if request.auth.token.admin == true;
    }
  }
}
```

---

### 6. Flutter アプリ側の統合

#### 6-1. キャンペーン登録画面の追加

**ProfileScreen にメニュー追加**:
```dart
Card(
  color: Colors.orange[50],
  child: ListTile(
    leading: Icon(Icons.card_giftcard),
    title: Text('🎉 乗り換え割キャンペーン'),
    subtitle: Text('初月無料 / 2ヶ月無料'),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CampaignRegistrationScreen(
            planType: 'pro', // または 'premium'
          ),
        ),
      );
    },
  ),
),
```

#### 6-2. サブスクリプション画面との統合

**SubscriptionScreen でプラン選択時**:
```dart
// Pro プラン選択時
onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CampaignRegistrationScreen(
        planType: 'pro',
      ),
    ),
  );
}
```

---

### 7. プッシュ通知設定

#### 7-1. Firebase Cloud Messaging 有効化
```bash
# Firebase プロジェクトで FCM 有効化
# Flutter アプリに firebase_messaging パッケージ追加済み
```

#### 7-2. FCM Token の保存

**ユーザー登録時に FCM Token を保存**:
```dart
import 'package:firebase_messaging/firebase_messaging.dart';

// FCM Token 取得
final fcmToken = await FirebaseMessaging.instance.getToken();

// Firestore に保存
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .set({
  'fcm_token': fcmToken,
}, SetOptions(merge: true));
```

---

## 🧪 テスト手順

### 1. ローカルエミュレータでテスト

```bash
# Firebase Emulators 起動
firebase emulators:start

# 別ターミナルで Flutter アプリ起動
cd /home/user/flutter_app
flutter run -d chrome
```

### 2. 本番環境でテスト

#### 2-1. テスト用投稿を作成
```
Xに投稿:
---
筋トレMEMO から GYM MATCH に乗り換えました！

AIが過去データを分析して、弱点を明確化してくれた。

#GM2025TEST01
#GymMatch乗り換え割 #AI筋トレ分析
---
```

#### 2-2. アプリで申請
1. キャンペーン登録画面で「筋トレMEMO」選択
2. SNSシェア画面で認証コード `#GM2025TEST01` 確認
3. 「投稿しました」ボタンタップ

#### 2-3. Cloud Functions ログ確認
```bash
# ログ確認（リアルタイム）
firebase functions:log --only verifyCampaignPost

# 特定時刻のログ確認
firebase functions:log --since 30m
```

**成功時のログ例**:
```
[START] Verifying application abc123 with code #GM2025TEST01
[FOUND] Tweet found: 筋トレMEMO から GYM MATCH に...
[GEMINI] Validation result: OK
[PASS] Post content validated successfully
[SUCCESS] Applied 2 months benefit to user user123
[SUCCESS] Push notification sent to user user123
```

---

## 📊 CEOダッシュボード（監視専用）

### 統計情報の確認

**CampaignService で統計取得**:
```dart
final stats = await CampaignService().getCampaignStats();

print('総申請数: ${stats['total_applications']}');
print('承認数: ${stats['approved']}');
print('承認率: ${stats['approval_rate']}%');
```

**Firebase Console での確認**:
1. https://console.firebase.google.com/
2. Firestore → `campaign_applications` コレクション
3. ステータス別フィルタ表示

---

## 🚨 トラブルシューティング

### 問題1: X API で投稿が見つからない
```
原因: X API の検索遅延（最大30秒）
解決策: retryCampaignVerification 関数が5分毎に自動リトライ
```

### 問題2: Gemini API がタイムアウト
```
原因: API レート制限
解決策: functions/campaign_auto_verifier.js の verifyPostContent で
       基本チェックのみで通すフォールバック実装済み
```

### 問題3: 特典が適用されない
```
原因: user_subscriptions ドキュメントが存在しない
解決策: ユーザー登録時に初期ドキュメント作成
```

---

## 💰 コスト試算

### Cloud Functions 実行コスト
```
1申請あたり:
- verifyCampaignPost: 1回実行 ≈ ¥0.0001
- X API: 無料（Free Tier内）
- Gemini API: ¥0.0003（gemini-2.0-flash-exp）

合計: 1申請 ≈ ¥0.0004（0.04円）

月1000申請でも ¥0.40（40円）
```

### リトライ関数コスト
```
retryCampaignVerification:
- 5分毎実行 = 月8,640回
- 1回実行 ≈ ¥0.00004

合計: 月 ≈ ¥0.35（35円）
```

**総計: 月1000申請で ¥0.75（75円）**

---

## ✅ デプロイチェックリスト

- [ ] X API Bearer Token 設定済み
- [ ] Gemini API Key 設定済み
- [ ] Cloud Functions デプロイ完了
- [ ] Firestore セキュリティルール更新
- [ ] FCM Token 保存処理実装
- [ ] Flutter アプリにキャンペーン画面統合
- [ ] テスト投稿で動作確認
- [ ] Cloud Functions ログ確認

---

## 🎯 次のステップ

1. **本番デプロイ前テスト**: Firebase Emulators で完全テスト
2. **監視ダッシュボード実装**: CEO用の統計画面作成
3. **エラーアラート設定**: Cloud Functions エラー時のSlack通知
4. **A/Bテスト準備**: キャンペーン効果測定

---

**このシステムで、CEOは「何もしなくても」キャンペーンが自動運用されます！** 🚀
