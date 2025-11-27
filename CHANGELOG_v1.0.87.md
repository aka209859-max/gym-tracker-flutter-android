# GYM MATCH Version 1.0.87 - ホットフィックス

リリース日: 2025年11月27日

## 🔧 重要な修正

### バグ修正
- **匿名ユーザーのサブスクリプション同期問題を修正**
  - App Storeプロモーションコード使用後、正しくProプランが反映されるように改善
  - 匿名ログイン（ゲストモード）ユーザーのFirestore同期が正常に動作
  - RevenueCat → Firestore同期ロジックの改善

### 影響範囲
- App Storeプロモーションコード使用ユーザー
- 匿名ログイン後にサブスクリプション購入したユーザー
- 招待コード使用ユーザー

### 技術的詳細
```
修正前: if (user != null && !user.isAnonymous) { /* Firestore保存 */ }
修正後: if (user != null) { /* Firestore保存 */ }
```

GYM MATCHは匿名ログインが基本仕様のため、isAnonymousチェックを削除しました。

## 📦 変更ファイル
- `lib/services/subscription_service.dart` - 匿名ユーザー対応

## 🔄 アップデート手順
1. App Storeからアップデート
2. アプリを再起動
3. プロフィール画面でプラン状態を確認

## ⚠️ 既存ユーザーへの影響
- 購入済みユーザー: 「Restore」ボタンで購入履歴復元が正常動作
- 無料ユーザー: 影響なし

---

**Git Commit**: d8405ec
**Build Number**: 87
