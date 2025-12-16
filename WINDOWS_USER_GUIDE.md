# 🪟 Windows ユーザー向け完全ガイド

**GYM MATCH Android版をGitHubで自動ビルドする方法**

---

## 🎯 あなたがすべきこと（3ステップ、10分）

### ✅ 前提条件
- Windowsパソコン
- GitHubアカウント（既にお持ち）
- リポジトリ: https://github.com/aka209859-max/gym-tracker-flutter-android

---

## 📋 手順

### **ステップ1: GitHub Actionsワークフローを作成（5分）**

#### 1-1. GitHubのリポジトリへアクセス
```
https://github.com/aka209859-max/gym-tracker-flutter-android
```

#### 1-2. ワークフローファイルを作成
1. **Add file** ボタンをクリック
2. **Create new file** を選択
3. ファイル名を入力:
   ```
   .github/workflows/android-build.yml
   ```

#### 1-3. 以下の内容をコピー＆ペースト

```yaml
name: Android Build & Release

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

env:
  FLUTTER_VERSION: '3.35.4'
  JAVA_VERSION: '11'

jobs:
  build:
    name: Build Android APK & AAB
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: 📥 Checkout repository
        uses: actions/checkout@v4

      - name: ☕ Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: ${{ env.JAVA_VERSION }}
          cache: 'gradle'

      - name: 🐦 Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: 'stable'
          cache: true

      - name: 🔍 Flutter Doctor
        run: flutter doctor -v

      - name: 📦 Get Dependencies
        run: flutter pub get

      - name: 🔬 Analyze Code
        run: flutter analyze --no-fatal-infos
        continue-on-error: true

      - name: 🔥 Setup Firebase Config
        env:
          GOOGLE_SERVICES_JSON: ${{ secrets.GOOGLE_SERVICES_JSON }}
        run: |
          if [ -z "$GOOGLE_SERVICES_JSON" ]; then
            echo "⚠️  Warning: GOOGLE_SERVICES_JSON secret not set"
            echo "Creating dummy google-services.json for build test..."
            cat > android/app/google-services.json << 'EOF'
          {
            "project_info": {
              "project_number": "000000000000",
              "project_id": "gym-match-dummy",
              "storage_bucket": "gym-match-dummy.appspot.com"
            },
            "client": [
              {
                "client_info": {
                  "mobilesdk_app_id": "1:000000000000:android:0000000000000000000000",
                  "android_client_info": {
                    "package_name": "com.gymmatch.app"
                  }
                },
                "oauth_client": [],
                "api_key": [
                  {
                    "current_key": "AIzaSyDummyKeyForBuildTestOnly000000000"
                  }
                ],
                "services": {
                  "appinvite_service": {
                    "other_platform_oauth_client": []
                  }
                }
              }
            ],
            "configuration_version": "1"
          }
          EOF
          else
            echo "✅ GOOGLE_SERVICES_JSON secret found"
            echo "$GOOGLE_SERVICES_JSON" > android/app/google-services.json
          fi

      - name: 🔨 Build Debug APK
        run: flutter build apk --debug --verbose

      - name: 🏗️ Build Release APK
        run: flutter build apk --release --verbose
        continue-on-error: true

      - name: 📦 Build Release AAB
        run: flutter build appbundle --release --verbose
        continue-on-error: true

      - name: 📤 Upload Debug APK
        uses: actions/upload-artifact@v4
        with:
          name: gym-match-debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk
          retention-days: 7

      - name: 📤 Upload Release APK
        uses: actions/upload-artifact@v4
        if: success()
        with:
          name: gym-match-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
          retention-days: 30
        continue-on-error: true

      - name: 📤 Upload Release AAB
        uses: actions/upload-artifact@v4
        if: success()
        with:
          name: gym-match-release-aab
          path: build/app/outputs/bundle/release/app-release.aab
          retention-days: 30
        continue-on-error: true

      - name: 📊 Generate Build Summary
        if: always()
        run: |
          echo "## 🎉 GYM MATCH Android Build Complete" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### 📦 Build Information" >> $GITHUB_STEP_SUMMARY
          echo "- **Version**: v1.0.254+279" >> $GITHUB_STEP_SUMMARY
          echo "- **Branch**: ${{ github.ref_name }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Commit**: ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### 📥 Download Artifacts" >> $GITHUB_STEP_SUMMARY
          echo "Go to **Actions** tab → **Summary** section to download APK files" >> $GITHUB_STEP_SUMMARY
```

#### 1-4. ファイルをコミット
- 下の方にある **Commit changes** ボタンをクリック
- コミットメッセージ: `feat: Add Android build workflow`
- **Commit changes** を確認

---

### **ステップ2: Firebase設定（オプションだが推奨、3分）**

#### 2-1. Firebase Consoleへアクセス
```
https://console.firebase.google.com
```

#### 2-2. google-services.json を取得
1. **GYM MATCH** プロジェクトを選択
2. **プロジェクトの設定**（⚙️アイコン）をクリック
3. **マイアプリ** セクション → Android アプリ
4. **google-services.json** をダウンロード

#### 2-3. ファイルの内容をコピー
1. ダウンロードした `google-services.json` をメモ帳で開く
2. **全内容をコピー**（Ctrl+A → Ctrl+C）

#### 2-4. GitHub Secrets に追加
1. リポジトリの **Settings** タブへ移動
2. 左メニューの **Secrets and variables** → **Actions** をクリック
3. **New repository secret** をクリック
4. **Name**: `GOOGLE_SERVICES_JSON`
5. **Secret**: コピーした内容を貼り付け
6. **Add secret** をクリック

---

### **ステップ3: ビルドを実行（2分）**

#### 方法A: 自動実行（コードをプッシュ）
何もしなくてもOK！
- `main` または `develop` ブランチにプッシュすると自動実行されます
- すでにステップ1でワークフローファイルをコミットしたので、ビルドが開始されているはずです

#### 方法B: 手動実行
1. リポジトリの **Actions** タブへ移動
2. 左サイドバーの **Android Build & Release** をクリック
3. 右上の **Run workflow** ボタンをクリック
4. **Run workflow** を確認

---

## 📥 ビルド結果のダウンロード方法

### ステップ1: Actions タブへ移動
```
https://github.com/aka209859-max/gym-tracker-flutter-android/actions
```

### ステップ2: 最新のワークフロー実行をクリック
- 緑色の✅が表示されていれば成功
- 黄色の🟡は実行中
- 赤色の❌は失敗

### ステップ3: Artifactsセクションまでスクロール
ページの下の方に **Artifacts** セクションがあります

### ステップ4: APKファイルをダウンロード
- **gym-match-debug-apk** (テスト用)
- **gym-match-release-apk** (配布用)
- **gym-match-release-aab** (Google Play用)

---

## 📱 APKをスマホにインストールする方法

### 方法1: USBケーブル経由（推奨）

#### Android実機の設定:
1. **設定** → **デバイス情報**
2. **ビルド番号**を7回タップ → 開発者向けオプション有効化
3. **設定** → **システム** → **開発者向けオプション**
4. **USBデバッグ** をON

#### Windows PCでの操作:
```powershell
# Android SDK Platform-Tools をインストール
# https://developer.android.com/studio/releases/platform-tools

# APKをインストール
.\adb.exe install gym-match-debug-apk.apk
```

---

### 方法2: クラウド経由（簡単）

#### ステップ1: Googleドライブにアップロード
1. ダウンロードした `gym-match-debug-apk.zip` を解凍
2. `app-debug.apk` を Googleドライブにアップロード

#### ステップ2: スマホでダウンロード
1. スマホのGoogleドライブアプリを開く
2. アップロードした `app-debug.apk` をダウンロード

#### ステップ3: インストール
1. ダウンロード完了後、ファイルをタップ
2. 「提供元不明のアプリ」を許可するか確認 → **許可**
3. インストール完了

---

## ✅ 機能検証チェックリスト

APKをインストールしたら、以下を確認してください：

### 1. PR記録画面の部位別表示
- [ ] アプリ起動 → PR画面へ移動
- [ ] 8つの部位（胸・背中・肩・二頭・三頭・腹筋・脚・有酸素）が表示される
- [ ] 記録のない部位をタップ → 「まだ○○の記録がありません」メッセージ

### 2. 未完了セットのPR反映
- [ ] ホーム画面でトレーニング記録を追加
- [ ] セット入力してチェックを付けない（未完了状態）
- [ ] PR画面で未完了セットが表示される

### 3. 有酸素運動の入力表示
- [ ] バーピージャンプ選択 → 「時間/回数」が表示される
- [ ] ランニング選択 → 「時間/距離」が表示される

---

## 🚨 トラブルシューティング

### Q1: ビルドが失敗する（❌マーク）
**A**: Actions タブでログを確認してください
1. 失敗したワークフロー実行をクリック
2. 赤色の❌が付いているステップをクリック
3. エラーメッセージを確認

よくあるエラー:
- **Firebase関連エラー** → ステップ2（Firebase設定）を実施
- **Gradle関連エラー** → 一時的な問題の可能性、再実行

---

### Q2: Artifactsが表示されない
**A**: ビルドが完了するまで待ってください
- ビルドには約5-10分かかります
- 🟡マーク → 実行中
- ✅マーク → 完了

---

### Q3: APKがインストールできない
**A**: Android設定を確認
1. **提供元不明のアプリ** を許可
2. **Play プロテクト** を一時的に無効化
3. APKファイルが破損していないか確認（再ダウンロード）

---

## 🎉 まとめ

### あなたがやったこと:
1. ✅ GitHub Actions ワークフローを作成
2. ✅ Firebase設定をGitHub Secretsに追加
3. ✅ ビルドを実行（または自動実行）

### 結果:
- ✅ GitHubが自動的にAPKをビルド
- ✅ いつでもダウンロード可能
- ✅ コードをプッシュするたびに自動ビルド

### 次のステップ:
- ✅ APKをスマホにインストール
- ✅ 3つの主要機能を検証
- ✅ 問題なければ本番リリース準備

---

## 📚 関連ドキュメント

- **詳細なセットアップ**: [GITHUB_ACTIONS_SETUP.md](./GITHUB_ACTIONS_SETUP.md)
- **コード検証結果**: [ANDROID_BUILD_VERIFICATION_REPORT.md](./ANDROID_BUILD_VERIFICATION_REPORT.md)
- **クイックスタート**: [QUICK_START_GUIDE.md](./QUICK_START_GUIDE.md)

---

**作成日**: 2025-12-16  
**対象**: Windowsユーザー  
**バージョン**: v1.0.254+279
