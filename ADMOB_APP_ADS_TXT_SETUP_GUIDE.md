# 🚨 **AdMob app-ads.txt 設定完全ガイド**

このガイドは、AdMobで表示されている「広告配信を制限しています (Verify app to lift limit)」エラーを解決するための手順書です。

---

## 📊 **問題の詳細**

### **エラーメッセージ:**
```
GYM MATCH (iOS) を確認できませんでした
⚠️ 広告配信を制限しています - Verify app to lift limit

問題: App Store のアプリ リスティングではデベロッパー ウェブサイトが見つかりませんでした
```

### **原因:**
1. **App Store Connect** に開発者ウェブサイトが登録されていない
2. **app-ads.txt ファイル** がウェブサイトに設置されていない

---

## ✅ **解決方法: 2ステップ**

---

## **📍 Step 1: App Store Connect でウェブサイトを追加**

### **1-1. App Store Connect にログイン**
```
https://appstoreconnect.apple.com
```

### **1-2. GYM MATCH アプリを選択**
- 「マイApp」→ 「GYM MATCH」をクリック

### **1-3. App 情報を編集**
- 左サイドバー: **「App 情報」** をクリック

### **1-4. ウェブサイトURLを入力**

以下の3つのURLを設定してください:

| 項目 | URL |
|:---|:---|
| **サポートURL** | `https://gym-match-e560d.web.app` |
| **マーケティングURL** | `https://gym-match-e560d.web.app` |
| **プライバシーポリシーURL** | `https://gym-match-e560d.web.app/privacy_policy.html` |

### **1-5. 保存**
- 右上の **「保存」** ボタンをクリック
- 変更が反映されるまで数時間かかる場合があります

---

## **🔧 Step 2: Firebase Hosting に app-ads.txt をデプロイ**

### **✅ 既に完了している作業:**
- ✅ `web/app-ads.txt` ファイル作成済み
- ✅ GitHubにプッシュ済み (Commit: e0fa6cd)
- ✅ ファイル内容:
  ```
  google.com, pub-2887531479031819, DIRECT, f08c47fec0942fa0
  ```

### **2-1. Firebase CLI でデプロイ (CEOが実行)**

**前提条件:**
- Firebase CLI がインストールされていること
- Firebase プロジェクト `gym-match-e560d` へのアクセス権限

**デプロイコマンド:**

```bash
# プロジェクトディレクトリに移動
cd gym-tracker-flutter

# Flutterウェブアプリをビルド
flutter build web --release

# Firebase Hosting にデプロイ
firebase deploy --only hosting
```

**デプロイ成功のメッセージ:**
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/gym-match-e560d/overview
Hosting URL: https://gym-match-e560d.web.app
```

### **2-2. app-ads.txt の確認**

デプロイ後、以下のURLにアクセスして確認:
```
https://gym-match-e560d.web.app/app-ads.txt
```

**期待される表示:**
```
google.com, pub-2887531479031819, DIRECT, f08c47fec0942fa0
```

---

## **🔍 Step 3: AdMob で「Verify app」を実行**

### **3-1. AdMobコンソールにログイン**
```
https://apps.admob.com
```

### **3-2. GYM MATCH (iOS) アプリを選択**
- 「アプリ」タブ → 「GYM MATCH (iOS)」

### **3-3. 「Verify app」ボタンをクリック**
- ステータス欄の **「Verify app to lift limit」** をクリック
- または画面上の **「Verify app」** ダイアログで確認

### **3-4. 検証完了を待つ**
- Google が app-ads.txt を確認 (通常24〜48時間)
- 確認が完了すると:
  ```
  ✅ 広告配信制限が解除されました
  ```

---

## **❓ よくある質問**

### **Q1: 新しいキーを作成する必要がありますか？**

**❌ いいえ、不要です！**

- AdMob Publisher ID (`pub-2887531479031819`) は変更不要
- 広告ユニットID も変更不要
- これは **app-ads.txt の設定問題** であり、キーの問題ではありません

---

### **Q2: Firebase デプロイが失敗する場合**

**手動アップロード方法:**

1. **Firebase Console にログイン**
   ```
   https://console.firebase.google.com/project/gym-match-e560d/hosting
   ```

2. **Hosting タブを開く**
   - 左サイドバー: **「Hosting」**

3. **手動ファイルアップロード**
   - 「カスタムドメイン」または「詳細設定」から手動アップロード可能
   - `app-ads.txt` ファイルをルートディレクトリに配置

---

### **Q3: デプロイ後も AdMob エラーが消えない**

**確認事項:**

1. **App Store Connect のウェブサイトURL が保存されているか**
   - `https://gym-match-e560d.web.app` が正しく入力されているか

2. **app-ads.txt が正しいURLでアクセスできるか**
   - ブラウザで `https://gym-match-e560d.web.app/app-ads.txt` を開いて確認

3. **Google の検証完了を待つ**
   - 通常24〜48時間かかります
   - 最大1週間かかる場合もあります

---

## **📊 最終確認チェックリスト**

| 項目 | 状態 | 確認方法 |
|:---|:---:|:---|
| ✅ **app-ads.txt 作成** | 完了 | `web/app-ads.txt` ファイル存在 |
| ✅ **GitHub プッシュ** | 完了 | Commit: e0fa6cd |
| ⏳ **Firebase デプロイ** | 保留 | CEO が実行 |
| ⏳ **App Store ウェブサイト登録** | 保留 | CEO が実行 |
| ⏳ **AdMob Verify app** | 保留 | デプロイ後実行 |
| ⏳ **Google 検証完了** | 保留 | 24〜48時間待機 |

---

## **🎯 CEOの次のアクション**

### **今すぐ実行:**

1. **App Store Connect でウェブサイトを追加**
   - URL: https://appstoreconnect.apple.com
   - サポートURL: `https://gym-match-e560d.web.app`

2. **Firebase Hosting にデプロイ**
   ```bash
   cd gym-tracker-flutter
   flutter build web --release
   firebase deploy --only hosting
   ```

3. **app-ads.txt の確認**
   - URL: https://gym-match-e560d.web.app/app-ads.txt

4. **AdMob で「Verify app」を実行**
   - URL: https://apps.admob.com

### **待機:**
- Google の検証完了 (24〜48時間)
- AdMob ステータスが「✅ 確認済み」に変更されるのを待つ

---

## **🆘 サポート**

問題が発生した場合:
1. **Firebase Hosting ログ**: https://console.firebase.google.com/project/gym-match-e560d/hosting
2. **AdMob ヘルプ**: https://support.google.com/admob/
3. **GitHub Issues**: https://github.com/aka209859-max/gym-tracker-flutter/issues

---

**最終更新:** 2025年11月30日  
**コミット:** e0fa6cd  
**ステータス:** app-ads.txt 作成完了 → Firebase デプロイ待ち
