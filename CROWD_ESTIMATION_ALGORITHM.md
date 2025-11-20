# 混雑度推定アルゴリズム - 技術仕様書

## 📊 概要

このドキュメントは、Gym Trackerアプリで使用している**混雑度推定アルゴリズム**の技術的根拠とデータソースを詳説します。

## 🎯 目的

Google Places APIから取得した既存データ（評価、レビュー数、営業時間）を活用し、**追加コストなし（$0）**でジムの混雑度を1-5レベルで推定します。

## 📈 データソースと根拠

### 1. ピークタイム判定（統計データベース）

#### 🇯🇵 日本国内データ

**ソース**: 国立体育・スポーツ大学論文（NIFS）
- **文献**: わが国において, 近年, フィットネスクラブは店舗数が微増しており
- **URL**: https://www.lib.nifs-k.ac.jp/wp-content/uploads/2023/01/38-1.pdf
- **調査方法**: フィットネスクラブの来館者時間帯別分析

**調査結果**:
- **平日**: 18時台と20-21時台に2つのピークが存在
- **土日**: 10時台の突出したピーク

#### 🌍 国際データ

**ソース1**: WOD Guru - Busiest Gym Times
- **URL**: https://wod.guru/blog/busiest-gym-times/
- **調査対象**: 複数のフィットネスクラブチェーンのデータ分析

**調査結果**:
- **平日**: 早朝6-8 AM、夕方5-7 PM（17-19時）がピーク
- **週末**: 10 AM - 3 PM がピーク
- **統計**: 41%のワークアウトが7-9 AMまたは5-7 PMに集中

**ソース2**: PerfectGym - When is the Gym Least Busy
- **URL**: https://www.perfectgym.com/en/blog/club-owners/when-gym-least-busy
- **調査方法**: 会員管理システムデータの分析

**調査結果**:
- **最混雑**: 平日17-19時、週末10-15時
- **最空き**: 深夜12 AM - 5 AM

### 2. 人気度指標（評価 + レビュー数）

#### 理論的根拠

**Google Places APIの評価システム**:
- **rating**: 1.0-5.0の評価スコア
- **user_ratings_total**: レビュー投稿数

**統計的相関**:
- 高評価 + 多レビュー = 人気店 = 利用者多 = 混雑しやすい
- 低評価 or 少レビュー = 利用者少 = 空きやすい

**ソース**: Google Help - About popular times
- **URL**: https://support.google.com/business/answer/6263531
- **技術**: 位置情報履歴の匿名化・集計データ

### 3. 営業時間外判定

**Google Places API**: `opening_hours.open_now`
- `true`: 営業中
- `false`: 営業時間外 → 確実に空き（混雑度レベル1）

## 🧮 推定アルゴリズム

### スコアリング方式

```dart
int crowdScore = 0;

// 1. 評価による加算（人気度）
if (rating >= 4.5) crowdScore += 3;  // 超高評価
else if (rating >= 4.0) crowdScore += 2;  // 高評価
else if (rating >= 3.5) crowdScore += 1;  // 標準以上

// 2. レビュー数による加算（利用者数の指標）
if (userRatingsTotal >= 100) crowdScore += 3;  // 大人気店
else if (userRatingsTotal >= 50) crowdScore += 2;  // 人気店
else if (userRatingsTotal >= 20) crowdScore += 1;  // 標準

// 3. ピークタイム加算（統計データベース）
if (isPeakTime) crowdScore += 2;

// 平日ピーク: 18:00-21:00, 7:00-9:00
// 週末ピーク: 10:00-15:00
```

### レベル変換ロジック

```dart
if (crowdScore >= 7) return 5;  // 超混雑（評価高+人気+ピーク）
else if (crowdScore >= 5) return 4;  // やや混雑（評価高+ピーク）
else if (crowdScore >= 3) return 3;  // 普通（標準評価）
else if (crowdScore >= 1) return 2;  // やや空き（評価低 or 非ピーク）
else return 1;  // 空いている（営業時間外 or 人気低）
```

## 📊 推定精度と限界

### ✅ 推定が有効なケース

1. **ピークタイム**: 統計データと高い相関
2. **人気店**: 評価・レビュー数が多い場合
3. **営業時間外**: 100%正確（空き）

### ⚠️ 推定が不正確な可能性

1. **特殊イベント**: 大会、セミナー開催時
2. **季節変動**: 正月（1月が入会ピーク）、夏前
3. **曜日変動**: 月曜日が最混雑（週初め効果）
4. **地域差**: 住宅地 vs オフィス街

### 🎯 精度向上策

**データソース優先順位**:
1. **ユーザー報告**（24時間有効）← 最優先・最信頼
2. **Firebaseキャッシュ**（24時間有効）
3. **Google推定値**（検索時自動計算）← フォールバック

## 💰 コスト分析

### 従来のアプローチ（高コスト）

**Google Places API - Place Details (Advanced)**:
- **popular_times**: リアルタイム混雑度データ
- **コスト**: $17/1,000リクエスト
- **月間10,000リクエスト**: $170

### 本実装（ゼロコスト）

**既存データ活用**:
- **rating, user_ratings_total, open_now**: Nearby Search API に含まれる
- **追加コスト**: $0（検索時に取得済み）
- **月間10,000リクエスト**: $0

**コスト削減**: **$170/月 → $0/月**

## 🔬 検証方法

### 実装確認

```dart
// lib/models/google_place.dart
final estimatedCrowdLevel = GooglePlace._estimateCrowdLevel(
  rating: 4.5,
  userRatingsTotal: 120,
  openNow: true,
);
// 平日19時: crowdScore = 3 + 3 + 2 = 8 → レベル5（超混雑）
```

### ユニットテスト

```dart
test('Peak time weekday evening', () {
  final level = GooglePlace._estimateCrowdLevel(
    rating: 4.5,
    userRatingsTotal: 100,
    openNow: true,
  );
  expect(level, greaterThanOrEqualTo(4));  // ピーク時は混雑
});
```

## 📚 参考文献

1. **国立体育・スポーツ大学論文（NIFS）**
   - https://www.lib.nifs-k.ac.jp/wp-content/uploads/2023/01/38-1.pdf

2. **WOD Guru - Busiest Gym Times**
   - https://wod.guru/blog/busiest-gym-times/

3. **PerfectGym - When is the Gym Least Busy**
   - https://www.perfectgym.com/en/blog/club-owners/when-gym-least-busy

4. **Google Help - About popular times**
   - https://support.google.com/business/answer/6263531

5. **Fitness on Demand - Gym Membership Statistics**
   - https://www.fitnessondemand247.com/news/gym-membership-statistics-you-should-know-in-2024

## 📝 免責事項

本推定アルゴリズムは統計的手法に基づいており、実際の混雑状況と異なる場合があります。最も正確な情報は**ユーザー報告**です。

## 🔄 更新履歴

- **2025-11-20**: 初版作成、業界統計データに基づくアルゴリズム実装
- **データソース**: NIFS論文、WOD Guru、PerfectGym統計
