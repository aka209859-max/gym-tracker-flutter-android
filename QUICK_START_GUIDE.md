# GYM MATCH Android版 - クイックスタートガイド

**バージョン**: v1.0.254+279  
**最終更新**: 2025-12-16

---

## 🚀 5分でセットアップ

### 前提条件
- ✅ Flutter SDK 3.35.4以降
- ✅ Android Studio (Arctic Fox以降)
- ✅ JDK 11以降
- ✅ Git

### ステップ1: リポジトリクローン（30秒）
```bash
git clone https://github.com/aka209859-max/gym-tracker-flutter-android.git
cd gym-tracker-flutter-android
```

### ステップ2: 依存関係取得（2分）
```bash
flutter pub get
```

### ステップ3: Firebase設定（2分）
```bash
# Firebase Consoleから google-services.json をダウンロード
# 1. https://console.firebase.google.com にアクセス
# 2. GYM MATCHプロジェクトを選択
# 3. Androidアプリを追加/選択
# 4. Package name: com.gymmatch.app
# 5. google-services.json をダウンロード

# ダウンロードしたファイルを配置
cp ~/Downloads/google-services.json android/app/
```

### ステップ4: 実行（30秒）
```bash
# エミュレーター起動（Android Studio経由）
# または USB デバッグ有効化した実機を接続

# アプリ起動
flutter run
```

---

## 🧪 主要機能の検証手順

### 1. PR記録画面の部位別表示（3分）

#### 期待される動作:
1. アプリ起動
2. ホーム画面からトレーニング記録を追加
3. PR画面に移動
4. **8つの部位**（胸・背中・肩・二頭・三頭・腹筋・脚・有酸素）が表示される
5. 記録のない部位をタップ → 「まだ○○の記録がありません」メッセージ
6. 記録のある部位をタップ → 種目一覧 → グラフ詳細

#### 確認ポイント:
- [ ] 全8部位が常に表示される（記録なしでも）
- [ ] 各部位に「X種目」と表示される
- [ ] 3階層遷移が正しく動作する

---

### 2. 未完了セットのPR反映（2分）

#### テスト手順:
1. ホーム画面でトレーニング記録を追加
2. セットを入力するが**チェックを付けない**（未完了状態）
3. 保存
4. PR画面に移動
5. 該当種目を確認

#### 期待される動作:
- ✅ 未完了セット（チェックなし）でもPR画面に表示される
- ✅ 筋トレ: 回数が入力されていればPRに反映
- ✅ 有酸素: 時間または距離/回数が入力されていればPRに反映

#### 確認ポイント:
- [ ] 未完了セットがPR画面に表示される
- [ ] グラフに未完了セットのデータが反映される

---

### 3. 有酸素運動の入力表示（2分）

#### テスト手順:

**パターンA: 距離式有酸素（ランニング）**
1. ホーム画面 → トレーニング追加
2. 「有酸素」カテゴリー選択
3. 「ランニング」を選択
4. 入力フィールドを確認

**期待される表示**:
```
時間 (分): [入力欄]
距離 (km): [入力欄]
```

**パターンB: 回数式有酸素（バーピー）**
1. ホーム画面 → トレーニング追加
2. 「有酸素」カテゴリー選択
3. 「バーピージャンプ」を選択
4. 入力フィールドを確認

**期待される表示**:
```
時間 (分): [入力欄]
回数: [入力欄]
```

#### 確認ポイント:
- [ ] ランニング: 「時間/距離」が表示される
- [ ] サイクリング: 「時間/距離」が表示される
- [ ] バーピージャンプ: 「時間/回数」が表示される
- [ ] マウンテンクライマー: 「時間/回数」が表示される

---

## 🔧 トラブルシューティング

### 問題1: `flutter pub get` が失敗する
```bash
# 解決策: Flutterをクリーンして再実行
flutter clean
flutter pub get
```

### 問題2: ビルドエラー「google-services.json not found」
```bash
# 解決策: Firebaseファイルを正しい場所に配置
ls -la android/app/google-services.json  # ファイル存在確認

# なければ Firebase Consoleからダウンロード
# 配置先: android/app/google-services.json
```

### 問題3: エミュレーターが表示されない
```bash
# エミュレーター一覧確認
flutter devices

# 何も表示されない場合 → Android Studioでエミュレーター作成
# 1. Android Studio → Tools → Device Manager
# 2. Create Device → Pixel 5 (推奨) → Next
# 3. System Image → Android 14 (API 34) → Next → Finish
```

### 問題4: Firebase接続エラー
```bash
# 解決策: google-services.json の内容確認
cat android/app/google-services.json | grep package_name

# "package_name": "com.gymmatch.app" が含まれているか確認
# 異なる場合 → Firebase Consoleで正しいPackage nameで再作成
```

---

## 📱 デバイス接続方法

### Android実機の場合:
1. **開発者向けオプション有効化**
   - 設定 → デバイス情報 → ビルド番号を7回タップ

2. **USBデバッグ有効化**
   - 設定 → システム → 開発者向けオプション → USBデバッグ ON

3. **PC接続**
   ```bash
   # デバイス確認
   flutter devices
   
   # 出力例:
   # Android SDK built for x86_64 (mobile) • emulator-5554 • android-x64
   ```

4. **アプリ起動**
   ```bash
   flutter run
   ```

### Androidエミュレーターの場合:
1. **Android Studio経由で起動**
   - Android Studio → Tools → Device Manager → ▶ボタン

2. **コマンドラインから起動**
   ```bash
   # エミュレーター一覧
   emulator -list-avds
   
   # 起動（例: Pixel_5_API_34）
   emulator -avd Pixel_5_API_34
   ```

3. **アプリ起動**
   ```bash
   flutter run
   ```

---

## 📊 動作環境仕様

### 最小要件
- **Android**: 7.0 (Nougat, API 24)以上
- **RAM**: 2GB以上
- **ストレージ**: 100MB以上の空き容量

### 推奨環境
- **Android**: 14 (API 34)
- **RAM**: 4GB以上
- **ストレージ**: 500MB以上の空き容量

### テスト済みデバイス
- ✅ Pixel 5 (Android 14)
- ✅ Pixel 4a (Android 13)
- ✅ Samsung Galaxy S21 (Android 14)

---

## 🎯 次にやること

### 開発継続する場合:
1. ✅ Android Studioで `lib/` フォルダを開く
2. ✅ Hot Reload を活用して高速開発（`r`キー）
3. ✅ `lib/screens/workout/personal_records_screen.dart` で部位別表示を確認
4. ✅ `lib/services/exercise_master_data.dart` で有酸素運動判定ロジックを確認

### リリース準備する場合:
1. ⏳ 署名鍵生成（`RELEASE_GUIDE.md` 参照）
2. ⏳ `key.properties` 作成
3. ⏳ リリースビルド実行
   ```bash
   flutter build appbundle --release
   ```
4. ⏳ Google Play Console内部テストアップロード

---

## 📚 関連ドキュメント

- [詳細ビルド検証レポート](./ANDROID_BUILD_VERIFICATION_REPORT.md)
- [リリースガイド](./RELEASE_GUIDE.md)
- [README](./README.md)
- [プライバシーポリシー](https://gym-match-e560d.web.app/privacy_policy.html)

---

## 💬 サポート

**開発者**: Hajime Inoue  
**Email**: aka209859@gmail.com  
**GitHub Issues**: https://github.com/aka209859-max/gym-tracker-flutter-android/issues

---

**© 2025 GYM MATCH - Android Version**
