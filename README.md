# GYM MATCH - Android版

[![Flutter](https://img.shields.io/badge/Flutter-3.35.4-blue.svg)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android-green.svg)](https://developer.android.com/)
[![License](https://img.shields.io/badge/License-Private-red.svg)]()

## 📱 アプリ概要

**GYM MATCH**は、フィットネス愛好家のためのトレーニング記録・ジム検索・パートナーマッチングアプリのAndroid版です。

### 主要機能
- 🏋️ トレーニング記録管理
- 🗺️ ジム検索・混雑度表示
- 🤖 AIコーチング機能
- 👥 トレーニングパートナー検索
- 💰 サブスクリプション（Premium / Pro）
- 📊 トレーニング統計・分析

---

## 🚀 開発環境セットアップ

### 必要な環境
- Flutter SDK 3.35.4+
- Android Studio Arctic Fox以降
- JDK 11以降
- Android SDK (minSdk: 24, targetSdk: 34)

### セットアップ手順

1. **リポジトリクローン**
```bash
git clone https://github.com/aka209859-max/gym-tracker-flutter-android.git
cd gym-tracker-flutter-android
```

2. **依存関係インストール**
```bash
flutter pub get
```

3. **Firebase設定**
- `google-services.json` を `android/app/` に配置
- Firebase Console でAndroidアプリを登録

4. **署名鍵設定**
- `key.properties` を `android/` に作成（詳細は後述）

5. **ビルド実行**
```bash
# デバッグビルド
flutter run

# リリースビルド
flutter build apk --release
flutter build appbundle --release
```

---

## 🔐 リリース署名設定

### 1. 署名鍵生成

```bash
keytool -genkey -v \
  -storetype PKCS12 \
  -keystore ~/gym-match-android-release-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias gym-match-release
```

### 2. key.properties作成

`android/key.properties` を作成：

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=gym-match-release
storeFile=gym-match-android-release-key.jks
```

⚠️ **重要**: `key.properties` と署名鍵ファイルは `.gitignore` に追加済みです。

---

## 📦 ビルド

### デバッグビルド
```bash
flutter build apk --debug
```

### リリースビルド（APK）
```bash
flutter build apk --release
```

### リリースビルド（AAB - Google Play推奨）
```bash
flutter build appbundle --release
```

---

## 🏪 Google Play Store リリース

### 内部テスト
1. Google Play Consoleにアクセス
2. 内部テストトラックを作成
3. AABファイルをアップロード

### 本番リリース
1. ストアリスティング作成
2. スクリーンショット準備
3. プライバシーポリシー設定
4. 審査提出

---

## 🔧 トラブルシューティング

### ビルドエラー
```bash
# クリーンビルド
flutter clean
flutter pub get
flutter build apk --release
```

### 署名エラー
- `key.properties` の内容を確認
- 署名鍵ファイルのパスを確認
- パスワードが正しいか確認

---

## 📝 バージョン履歴

### v1.0.0 (2025-12-03)
- 🎉 Android版初回リリース
- iOS版の全機能を移植
- Android固有の最適化

---

## 🔗 関連リンク

- [iOS版リポジトリ](https://github.com/aka209859-max/gym-tracker-flutter)
- [プライバシーポリシー](https://gym-match-e560d.web.app/privacy_policy.html)
- [利用規約](https://gym-match-e560d.web.app/terms.html)

---

## 📧 お問い合わせ

開発者: Hajime Inoue  
Email: aka209859@gmail.com

---

**© 2025 GYM MATCH - Android Version**
