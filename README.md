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

### 📋 事前準備（必須）

#### 1. Google Play Console アカウント作成
- **URL**: https://play.google.com/console/
- **費用**: 25ドル（一度のみ）
- **必要情報**:
  - Googleアカウント
  - クレジットカード
  - 開発者名（個人 or 企業）

#### 2. アプリ登録
1. **アプリ作成**
   - アプリ名: `GYM MATCH`
   - デフォルト言語: 日本語
   - タイプ: アプリ（ゲーム以外）
   - 無料 or 有料: 無料（アプリ内課金あり）

2. **パッケージ名**: `com.gymmatch.app`
   - ⚠️ 一度設定すると変更不可

#### 3. AdMob設定（広告収益化）
- **URL**: https://admob.google.com/
- **必要な作業**:
  1. AdMobアカウント作成
  2. Androidアプリ登録
  3. 広告ユニットID取得（バナー、リワード、インタースティシャル）
  4. `AndroidManifest.xml` と広告サービスファイルに本番AdMob IDを設定
  5. 支払い情報登録（1,000円以上で支払い）

現在の設定:
```
📍 AndroidManifest.xml: テスト用AdMob Application ID使用中
📍 lib/services/ad_service.dart: Android広告ID要設定
📍 lib/services/admob_service.dart: Android広告ID要設定
📍 lib/services/reward_ad_service.dart: Android広告ID要設定
```

#### 4. Firebase設定（プッシュ通知・分析）
- **URL**: https://console.firebase.google.com/
- **既存設定**: `google-services.json` 設定済み
- **確認項目**:
  - ✅ Firebase Authentication有効化
  - ✅ Cloud Firestore有効化
  - ✅ Firebase Storage有効化
  - ⚠️ Firebase Cloud Messaging（プッシュ通知）有効化 → 未設定

#### 5. Google Maps API（ジム検索機能）
- **URL**: https://console.cloud.google.com/
- **必要なAPI**:
  - ✅ Maps SDK for Android（有効化必要）
  - ✅ Places API（有効化必要）
  - ⚠️ APIキーの制限設定（パッケージ名: `com.gymmatch.app`）

#### 6. ストアリスティング準備
- **短い説明**（80文字以内）
- **完全な説明**（4000文字以内）
- **スクリーンショット**:
  - 携帯電話: 2-8枚（1080x1920推奨）
  - 7インチタブレット: 任意
  - 10インチタブレット: 任意
- **アイコン**: 512x512 PNG（既存: `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`）
- **機能グラフィック**: 1024x500 JPG/PNG
- **プライバシーポリシーURL**: https://gym-match-e560d.web.app/privacy_policy.html

---

### 🚀 内部テスト
1. Google Play Consoleにアクセス
2. 内部テストトラックを作成
3. AABファイルをアップロード (`flutter build appbundle --release`)
4. テスターのメールアドレスを登録
5. テストリンクを共有

### 📦 本番リリース
1. ストアリスティング作成（上記準備項目）
2. コンテンツレーティング（質問票回答）
3. ターゲット年齢層・コンテンツ選択
4. データセーフティ（データ収集・使用の説明）
5. 審査提出（通常1-3日）

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
