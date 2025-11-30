# 🛠️ GYM MATCH - ローカル開発環境セットアップガイド

このガイドは、CEOまたは他の開発者がローカル環境でGYM MATCHプロジェクトを開発する際の手順書です。

---

## 📋 **前提条件**

### **必須ソフトウェア:**
1. **Flutter SDK 3.35.4** (この特定バージョン推奨)
2. **Xcode 15.0+** (iOS開発用、Macのみ)
3. **Android Studio** または **VS Code** (推奨)
4. **Git** (バージョン管理)
5. **CocoaPods** (iOS依存関係管理、Macのみ)

---

## 🚀 **セットアップ手順**

### **Step 1: プロジェクトをクローン**

```bash
# GitHubからプロジェクトをクローン
git clone https://github.com/aka209859-max/gym-tracker-flutter.git

# プロジェクトディレクトリに移動
cd gym-tracker-flutter
```

---

### **Step 2: Flutter依存関係のインストール**

```bash
# Flutterパッケージをインストール
flutter pub get

# プロジェクト構造を確認
flutter doctor -v
```

**期待される出力:**
```
✓ Flutter (Channel stable, 3.35.4)
✓ Android toolchain - develop for Android devices
✓ Xcode - develop for iOS and macOS
✓ VS Code / Android Studio (at least one)
```

---

### **Step 3: iOS設定 (Macのみ)**

```bash
# iOSディレクトリに移動
cd ios

# CocoaPods依存関係をインストール
pod install

# プロジェクトディレクトリに戻る
cd ..
```

---

### **Step 4: Firebase設定ファイルの確認**

**重要:** Firebaseを使用している場合、以下のファイルが必要です:

```
ios/Runner/GoogleService-Info.plist  (iOS用)
android/app/google-services.json     (Android用)
```

**これらのファイルがない場合:**
1. Firebase Console (https://console.firebase.google.com/) にアクセス
2. GYM MATCHプロジェクトを選択
3. iOS/Android アプリの設定から設定ファイルをダウンロード
4. 上記の場所に配置

---

### **Step 5: IDE設定**

#### **Option A: VS Code (推奨)**

1. **VS Codeで開く:**
   ```bash
   code gym-tracker-flutter
   ```

2. **推奨拡張機能をインストール:**
   - Flutter (Dart Code)
   - Dart
   - GitLens

3. **プロジェクトを実行:**
   - `F5` キーを押す
   - またはコマンドパレット (`Cmd+Shift+P`) → `Flutter: Run`

#### **Option B: Android Studio**

1. **Android Studioを起動**
2. **File → Open** → `gym-tracker-flutter` フォルダを選択
3. **Run → Run 'main.dart'** でアプリを起動

---

### **Step 6: 実機/シミュレータでの実行**

#### **iOS (Macのみ):**
```bash
# iOSシミュレータで実行
flutter run -d ios

# 実機で実行 (開発者アカウント必要)
flutter run -d <デバイスID>
```

#### **Android:**
```bash
# Androidエミュレータで実行
flutter run -d android

# 実機で実行 (USBデバッグ有効化)
flutter run -d <デバイスID>
```

---

## 🔧 **よくある問題と解決策**

### **問題1: `flutter pub get` が失敗する**

**原因:** ネットワーク問題またはパッケージバージョンの不一致

**解決策:**
```bash
# キャッシュをクリア
flutter clean
flutter pub cache repair

# 再度依存関係をインストール
flutter pub get
```

---

### **問題2: iOSビルドが失敗する**

**原因:** CocoaPods依存関係の問題

**解決策:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
flutter clean
flutter run -d ios
```

---

### **問題3: Firebase初期化エラー**

**原因:** 設定ファイルが正しく配置されていない

**解決策:**
1. `ios/Runner/GoogleService-Info.plist` を確認
2. `android/app/google-services.json` を確認
3. Firebaseプロジェクト設定と一致するか検証

---

## 📦 **ビルドコマンド**

### **開発ビルド:**
```bash
# デバッグモード (開発用)
flutter run --debug
```

### **リリースビルド:**
```bash
# iOS App Store用ビルド
flutter build ipa --release

# Android APK
flutter build apk --release

# Android App Bundle (Google Play推奨)
flutter build appbundle --release
```

---

## 🧪 **テストの実行**

```bash
# 単体テスト
flutter test

# 統合テスト
flutter test integration_test/

# コード分析 (構文チェック)
flutter analyze
```

---

## 🔄 **Git ワークフロー**

### **新しい機能を開発する場合:**

```bash
# 最新のmainブランチを取得
git checkout main
git pull origin main

# 新しいブランチを作成
git checkout -b feature/new-feature-name

# 変更をコミット
git add .
git commit -m "feat: 新機能の説明"

# GitHubにプッシュ
git push origin feature/new-feature-name
```

---

## 📱 **App Store / Google Play 提出**

### **iOS App Store Connect:**
1. Xcode Archive を作成: `Product → Archive`
2. Archive から App Store Connect にアップロード
3. App Store Connect (https://appstoreconnect.apple.com/) で審査提出

### **Google Play Console:**
1. `flutter build appbundle --release` でAABを作成
2. Google Play Console (https://play.google.com/console/) にログイン
3. AABをアップロードして審査提出

---

## 🆘 **サポート**

問題が発生した場合:
1. **GitHub Issues:** https://github.com/aka209859-max/gym-tracker-flutter/issues
2. **Flutter公式ドキュメント:** https://docs.flutter.dev/
3. **Stack Overflow:** `flutter` タグで質問

---

## 📊 **プロジェクト構造**

```
gym-tracker-flutter/
├── lib/                    # Dartソースコード
│   ├── main.dart          # アプリエントリーポイント
│   ├── screens/           # 画面UI
│   ├── services/          # ビジネスロジック (AI予測等)
│   ├── models/            # データモデル
│   └── widgets/           # 再利用可能なウィジェット
├── ios/                    # iOS固有設定
├── android/                # Android固有設定
├── test/                   # 単体テスト
├── integration_test/       # 統合テスト
├── pubspec.yaml           # Flutter依存関係
└── README.md              # プロジェクト概要
```

---

**最終更新:** 2025年11月30日  
**対象バージョン:** Build #99 (Version 1.0.99+99)  
**Flutter:** 3.35.4 (Stable)
