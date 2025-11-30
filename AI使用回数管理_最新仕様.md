# GYM MATCH - AI使用回数管理 最新仕様（実装コードベース）

## 作成日: 2025-11-28
## 情報源: `/home/user/webapp/lib/` 内の実装コード

---

## 💰 サブスクリプションプラン体系

### 🆓 **無料プラン**
- **料金**: ¥0（永久無料）
- **広告**: あり
- **AI使用回数**: 0回（リワード広告視聴で+1回、月3回まで）
- **機能**:
  - ジム検索・混雑度表示
  - 基本トレーニング記録
  - 営業時間確認

### 💎 **Premium プラン**
- **月額**: ¥500/月
- **年額**: ¥4,800/年
  - **月換算**: ¥400/月
  - **割引率**: 20% OFF
  - **年間節約**: ¥1,200お得
- **無料トライアル**: 30日間
- **AI使用回数**: 月10回（AIコーチ・成長予測・効果分析の合計）
- **広告**: なし
- **機能**:
  - 無料プランの全機能
  - AI機能月10回
  - お気に入り無制限
  - 詳細な混雑度統計
  - ジムレビュー投稿
  - 成長予測と効果分析

### 🌟 **Pro プラン**
- **月額**: ¥980/月
- **年額**: ¥8,000/年
  - **月換算**: ¥667/月
  - **割引率**: 32% OFF
  - **年間節約**: ¥3,760お得
- **無料トライアル**: 14日間
- **AI使用回数**: 月30回（AIコーチ・成長予測・効果分析の合計）
- **広告**: なし
- **機能**:
  - Premiumプランの全機能
  - AI機能月30回
  - トレーニングパートナー検索
  - メッセージング機能

---

## 🎁 AI追加パック（追加課金）

### 価格と内容
- **価格**: ¥300 / 5回
- **単価**: ¥60/回
- **対象**: 全ユーザー（無料・有料問わず）
- **有効期限**: 今月末まで（月次リセット）
- **商品ID**: `com.nexa.gymmatch.ai_pack_5_v2`

### 購入条件
- **無料プラン**: AIクレジットが0のとき購入可能
- **有料プラン**: 月間AI使用回数が上限に達したとき購入可能

---

## 🔄 AI使用回数管理ロジック

### 1. **有料プラン（Premium/Pro）の優先順位**
```
Step 1: 基本AI使用回数をチェック
  ├── Premium: 月10回
  └── Pro: 月30回

Step 2: 基本回数が残っている場合
  └── 1回消費（subscription_service.incrementAIUsage()）

Step 3: 基本回数が0の場合
  ├── AI追加パック残回数をチェック（¥300/5回）
  ├── 残っていれば: 1回消費（subscription_service.consumeAddonAIUsage()）
  └── 両方0の場合: AI追加パック購入画面へ誘導
```

### 2. **無料プランの優先順位**
```
Step 1: AI追加パック（¥300/5回）をチェック
  └── 残っていれば: 1回消費

Step 2: AI追加パックが0の場合
  └── AIクレジット（広告視聴分）をチェック
      └── 残っていれば: 1回消費（ai_credit_service.consumeAICredit()）

Step 3: 両方が0の場合
  ├── リワード広告を表示
  ├── 視聴完了で: AIクレジット+1回付与
  └── AI機能実行
```

---

## 💾 データ保存場所

### Firebase Firestore
```
users/{userId}/
  ├── isPremium (bool)         # 有料プランかどうか
  └── premiumType (string)     # "premium" or "pro"
```

### SharedPreferences（ローカル）
```
ai_usage_count_{year}_{month}   # 基本AI使用回数（月次リセット）
ai_addon_count_{year}_{month}   # AI追加パック残回数（月次リセット）
ai_credit_count                  # AIクレジット残回数（広告視聴分）
```

---

## 📱 RevenueCat Product IDs

### サブスクリプション（月額）
- Premium月額: `com.nexa.gymmatch.premium.monthly`
- Pro月額: `com.nexa.gymmatch.pro.monthly`

### サブスクリプション（年額）
- Premium年額: `com.nexa.gymmatch.premium.annual`
- Pro年額: `com.nexa.gymmatch.pro.annual`

### 消耗型（Consumable）
- AI追加パック: `com.nexa.gymmatch.ai_pack_5_v2`

---

## 🔍 実装ファイル

### サブスクリプション管理
- `lib/services/subscription_service.dart` - プラン管理・AI回数制限
- `lib/services/revenue_cat_service.dart` - RevenueCat連携・課金処理
- `lib/screens/subscription_screen.dart` - プラン選択画面UI

### AI使用回数管理
- `lib/services/ai_credit_service.dart` - AIクレジット管理
- `lib/screens/ai_addon_purchase_screen.dart` - AI追加パック購入画面
- `lib/screens/workout/ai_coaching_screen.dart` - AIコーチング画面

---

## 📝 変更履歴

### 2025-11-28
- ✅ AI追加パック価格確認: ¥300 / 5回（実装コードベース）
- ✅ 年額プラン確認: Premium ¥4,800/年、Pro ¥8,000/年
- ✅ 無料トライアル期間確認: Premium 30日、Pro 14日
- ✅ 月次リセット処理確認済み

---

## 🎯 CEO戦略メモ

### 年額選択率向上施策
1. **デフォルト選択**: 年額をデフォルト選択（`_isYearlySelected = true`）
2. **大幅割引**: Premium 20% OFF、Pro 32% OFF
3. **強調表示**: 「💥お得」バッジと節約金額表示
4. **月換算表示**: 年額の月換算価格を明示

### AI追加パック戦略
- 全ユーザー対象（無料・有料問わず）
- 有料プラン会員にも追加購入可能（CEO判断）
- 月次リセットで定期収益確保

---

## 🚨 重要な制約事項

### Apple審査対応
- プラン情報は RevenueCat → Firestore のみから取得
- SharedPreferences からのプラン取得は完全削除済み
- 「Restore」ボタン必須（Apple審査要件）

### iOS専用実装
- RevenueCat APIキー: iOS専用（`appl_QCxDcuCpNzWsfVJBzIQmBtszjmm`）
- `defaultTargetPlatform == TargetPlatform.iOS` チェック必須
- Web/Desktop版はローカルプラン変更のみ（プレビュー機能）

---

**このファイルは実装コードから直接抽出した最新情報です。**
