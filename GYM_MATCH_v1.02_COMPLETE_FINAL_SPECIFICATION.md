# 🏋️ GYM MATCH v1.02 完全版仕様書

**最終更新日**: 2025-12-01  
**バージョン**: v1.0.99 (App Store v1.02)  
**ビルド番号**: 99  
**開発元**: NEXA  
**プラットフォーム**: iOS 15.0+

---

## 📋 目次

1. [エグゼクティブサマリー](#エグゼクティブサマリー)
2. [v1.01 → v1.02 主要変更点](#v101--v102-主要変更点)
3. [全機能リスト（82画面・56サービス）](#全機能リスト82画面56サービス)
4. [コア機能詳細](#コア機能詳細)
5. [料金プラン・マネタイズ戦略](#料金プランマネタイズ戦略)
6. [技術スタック](#技術スタック)
7. [ビジネスモデル・収益予測](#ビジネスモデル収益予測)
8. [今後の展開](#今後の展開)

---

## 🎯 エグゼクティブサマリー

**GYM MATCH v1.02** は、トレーニング記録管理・AI コーチング・パートナーマッチング・ジム検索の4つのコア機能を統合した**総合フィットネスアプリ**です。

### 🌟 主要機能（4つのコア）
1. **📝 トレーニング記録管理** - 詳細記録・カレンダー・統計・テンプレート（82画面）
2. **🤖 AI コーチング** - Google Gemini 2.0 Flash による完全自動メニュー生成・成長予測・疲労管理
3. **👥 パートナーマッチング** - Skill-based Matching（±15% 1RM）・時空間マッチング
4. **🗺️ ジム検索** - Google Places API・混雑度表示・お気に入り・レビュー

### 💰 マネタイズ戦略（3層収益構造）
1. **広告収益**（無料プラン）: バナー広告 + リワード広告
2. **サブスクリプション収益**: Premium ¥500/月、Pro ¥980/月
3. **追加課金収益**: AI追加パック ¥300/5回

### 📊 ARR予測（12ヶ月）
- **目標**: ¥100,000,000（1億円）
- **v1.02実績予測**: **¥144,800,000（144.8%達成）**
- **内訳**: サブスク ¥140M + 広告 ¥4.8M

---

## 🔄 v1.01 → v1.02 主要変更点

### ✅ 追加機能（6つ）
1. **🎬 リワード広告実装** - 動画視聴で +1 AI使用回数
2. **🔗 バイラルループ最適化** - 紹介コード・SNSシェア強化
3. **📊 マジックナンバーガイドUI** - 5記録/30日で習慣化
4. **⏸️ 一時停止・ダウングレード** - チャーン防止機能
5. **⏰ 時空間コンテキストマッチング** - 同じジム・±2時間
6. **🎯 Skill-based Matching** - ±15% 1RM による実力マッチング

### 🐛 修正（Critical Bug Fix）
- **履歴表示バグ修正**（v1.02最優先）
  - 症状: トレーニング履歴が表示されない致命的バグ
  - 原因: 日付フィルタリング処理の比較エラー
  - 修正: `c071bb1` commit で完全解決

### 🗑️ 削除機能
- **AI疲労度分析カード** - `_buildAICard()` 削除（疲労管理システムと統合）
- **一時停止機能** - iOS設定から直接キャンセル可能のため削除

### 📱 AdMob広告本番化
- **バナー広告ID**: `ca-app-pub-2887531479031819/1682429555`（本番）
- **リワード広告ID**: `ca-app-pub-2887531479031819/6163055454`（本番）
- **app-ads.txt配信**: https://gym-match-e560d.web.app/app-ads.txt

---

## 📱 全機能リスト（82画面・56サービス）

### 🏠 ホーム画面（記録画面）
**画面数**: 15画面  
**サービス数**: 12サービス

#### 画面リスト
1. `home_screen.dart` - メイン記録画面
2. `add_workout_screen.dart` - トレーニング記録追加
3. `add_workout_screen_complete.dart` - 記録完了画面
4. `workout_log_screen.dart` - 記録一覧
5. `workout_detail_screen.dart` - 記録詳細
6. `simple_workout_detail_screen.dart` - シンプル詳細
7. `template_screen.dart` - テンプレート管理
8. `create_template_screen.dart` - テンプレート作成
9. `workout_import_preview_screen.dart` - CSVインポート
10. `workout_memo_list_screen.dart` - ワークアウトメモ
11. `body_measurement_screen.dart` - 体組成記録
12. `body_part_tracking_screen.dart` - 部位別追跡
13. `visit_history_screen.dart` - ジム訪問履歴
14. `trainer_records_screen.dart` - トレーナー記録
15. `statistics_dashboard_screen.dart` - 統計ダッシュボード

#### サービス
- `workout_service.dart` - トレーニング記録CRUD
- `workout_import_service.dart` - CSV/データインポート
- `workout_share_service.dart` - SNSシェア
- `workout_note_service.dart` - ワークアウトメモ管理
- `template_service.dart` - テンプレート管理
- `body_measurement_service.dart` - 体組成管理
- `statistics_service.dart` - 統計計算
- `visit_history_service.dart` - ジム訪問履歴
- `trainer_records_service.dart` - トレーナー記録管理
- `achievement_service.dart` - 達成バッジ
- `goal_service.dart` - 目標管理
- `personal_record_service.dart` - パーソナルレコード管理

---

### 🤖 AI機能（コーチング・分析）
**画面数**: 8画面  
**サービス数**: 6サービス

#### 画面リスト
1. `ai_coaching_screen.dart` - AIコーチング（旧版）
2. `ai_coaching_screen_tabbed.dart` - AIコーチング（タブ版）
3. `growth_prediction_screen.dart` - 成長予測
4. `training_effect_analysis_screen.dart` - 効果分析
5. `weekly_reports_screen.dart` - 週次レポート
6. `fatigue_management_screen.dart` - 疲労管理
7. `personal_factors_screen.dart` - 個人要因設定
8. `ai_addon_purchase_screen.dart` - AI追加パック購入

#### サービス
- `ai_coaching_service.dart` - Google Gemini 2.0 Flash API統合
- `growth_prediction_service.dart` - 成長予測計算
- `training_effect_service.dart` - 効果分析
- `weekly_report_service.dart` - 週次レポート生成
- `fatigue_management_service.dart` - 疲労度計算
- `ai_credit_service.dart` - AI使用回数管理

#### AI使用回数制限
| プラン | 月間回数 | リワード広告 | 追加パック |
|--------|----------|--------------|------------|
| **無料** | 0回 | 月3回まで | ¥300/5回 |
| **Premium** | 10回 | 利用可能 | ¥300/5回 |
| **Pro** | ∞（無制限） | 利用可能 | ¥300/5回 |

---

### 🗺️ ジムマップ機能
**画面数**: 12画面  
**サービス数**: 9サービス

#### 画面リスト
1. `map_screen.dart` - Google Mapsマップ
2. `gym_list_screen.dart` - ジム一覧
3. `gym_detail_screen.dart` - ジム詳細
4. `crowd_report_screen.dart` - 混雑度報告
5. `gym_review_screen.dart` - レビュー投稿
6. `favorites_screen.dart` - お気に入り
7. `search_screen.dart` - ジム検索
8. `gym_announcement_editor_screen.dart` - お知らせ編集
9. `gym_equipment_editor_screen.dart` - 設備編集
10. `partner_dashboard_screen.dart` - パートナージムダッシュボード
11. `partner_equipment_editor_screen.dart` - パートナー設備編集
12. `partner_photos_screen.dart` - ジム写真管理

#### サービス
- `gym_service.dart` - Google Places API統合
- `gym_search_service.dart` - ジム検索
- `crowd_report_service.dart` - 混雑度管理
- `gym_review_service.dart` - レビュー管理
- `favorites_service.dart` - お気に入り管理
- `gym_announcement_service.dart` - お知らせ管理
- `gym_equipment_service.dart` - 設備管理
- `partner_dashboard_service.dart` - パートナージム管理
- `notification_service.dart` - 混雑度アラート通知

#### Google Places API機能
- ✅ キーワード検索
- ✅ GPS位置検索
- ✅ 営業時間・定休日
- ✅ 写真ギャラリー
- ✅ 電話番号・住所
- ✅ Google Maps連携

---

### 👥 トレーニングパートナー機能（Proプラン限定）
**画面数**: 10画面  
**サービス数**: 8サービス

#### 画面リスト
1. `partner_screen.dart` - パートナーホーム
2. `partner_search_screen.dart` - パートナー検索
3. `partner_search_screen_new.dart` - 新パートナー検索
4. `partner_profile_detail_screen.dart` - プロフィール詳細
5. `partner_profile_edit_screen.dart` - プロフィール編集
6. `partner_requests_screen.dart` - フレンドリクエスト
7. `chat_screen.dart` - チャット一覧
8. `chat_detail_screen.dart` - チャット詳細
9. `chat_screen_partner.dart` - パートナーチャット
10. `messages_screen.dart` - メッセージ画面

#### サービス
- `partner_service.dart` - パートナー検索
- `partner_profile_service.dart` - プロフィール管理
- `friend_request_service.dart` - フレンドリクエスト
- `chat_service.dart` - Firebase Realtime Database チャット
- `messaging_service.dart` - メッセージング
- `skill_based_matching_service.dart` - ±15% 1RMマッチング
- `spatiotemporal_matching_service.dart` - 時空間マッチング
- `asymmetric_visibility_service.dart` - Pro限定可視性制御

#### マッチングアルゴリズム（3層）
1. **Skill-based Matching**
   - BIG3（ベンチプレス・スクワット・デッドリフト）の1RMで ±15% 以内をマッチング
   - 初心者・中級者・上級者の実力格差を自動調整
   
2. **時空間コンテキストマッチング**
   - 同じジムをお気に入り登録
   - 同じ曜日・時間帯（±2時間）に活動
   
3. **Pro Plan限定可視性**
   - 無料ユーザーはPro会員を検索不可
   - Pro会員は全ユーザーを検索可能（非対称性）

---

### 🎯 目標・達成管理
**画面数**: 3画面  
**サービス数**: 3サービス

#### 画面リスト
1. `goals_screen.dart` - 目標設定
2. `achievements_screen.dart` - 達成バッジ
3. `personal_records_screen.dart` - パーソナルレコード

#### サービス
- `goal_service.dart` - 目標CRUD
- `achievement_service.dart` - バッジ管理
- `personal_record_service.dart` - PR自動更新

---

### 🧮 計算ツール（全プラン共通）
**画面数**: 2画面  
**サービス数**: 2サービス

#### 画面リスト
1. `calculators_screen.dart` - 1RM計算 + プレート計算（タブ版）
2. `rm_calculator_screen.dart` - 1RM計算（独立版）

#### サービス
- `strength_calculators.dart` - RM計算・プレート計算
- `plate_calculator_service.dart` - プレート組み合わせ最適化

#### 計算機能
1. **1RM（最大挙上重量）計算**
   - Epley公式: 1RM = 重量 × (1 + 回数 / 30)
   - Brzycki公式: 1RM = 重量 / (1.0278 - 0.0278 × 回数)
   - Lander公式: 1RM = 100 × 重量 / (101.3 - 2.67123 × 回数)
   
2. **プレート計算機**
   - 目標重量から必要なプレート枚数を自動計算
   - バーベル重量（20kg/15kg）を考慮
   - 片側のプレート構成を表示

---

### 💳 課金・サブスクリプション
**画面数**: 4画面  
**サービス数**: 5サービス

#### 画面リスト
1. `subscription_screen.dart` - プラン管理
2. `ai_addon_purchase_screen.dart` - AI追加パック購入
3. `trial_progress_screen.dart` - トライアル進捗
4. `redeem_invite_code_screen.dart` - 紹介コード入力

#### サービス
- `subscription_service.dart` - RevenueCat統合
- `revenue_cat_service.dart` - iOS課金管理
- `trial_service.dart` - トライアル期限管理
- `referral_service.dart` - 紹介プログラム
- `ai_credit_service.dart` - AI使用回数管理

#### RevenueCat Product IDs
| Product Type | Product ID | 価格 |
|--------------|------------|------|
| Premium Monthly | `com.nexa.gymmatch.premium.monthly` | ¥500/月 |
| Pro Monthly | `com.nexa.gymmatch.pro.monthly` | ¥980/月 |
| Premium Annual | `com.nexa.gymmatch.premium.annual` | ¥4,800/年 |
| Pro Annual | `com.nexa.gymmatch.pro.annual` | ¥8,000/年 |
| AI追加パック | `com.nexa.gymmatch.ai_pack_5_v2` | ¥300/5回 |

---

### 📱 広告（AdMob）
**画面数**: 0画面（ウィジェット統合）  
**サービス数**: 4サービス

#### サービス
- `ad_service.dart` - AdMob SDK統合
- `admob_service.dart` - AdMob初期化
- `reward_ad_service.dart` - リワード広告
- `interstitial_ad_manager.dart` - インタースティシャル広告

#### 広告タイプ（2種類）
1. **バナー広告**（無料プランのみ）
   - 表示位置: ホーム画面下部
   - Ad Unit ID: `ca-app-pub-2887531479031819/1682429555`
   - サイズ: 320x50（標準バナー）
   
2. **リワード広告**（全プラン）
   - 目的: 動画視聴で +1 AI使用回数
   - トリガー: 「動画を見て1回分ゲット」ボタン
   - Ad Unit ID: `ca-app-pub-2887531479031819/6163055454`
   - 動画時間: 約30秒

#### app-ads.txt配信
```
google.com, pub-2887531479031819, DIRECT, f08c47fec0942fa0
```
配信URL: https://gym-match-e560d.web.app/app-ads.txt

---

### 🎨 プロフィール・設定
**画面数**: 12画面  
**サービス数**: 8サービス

#### 画面リスト
1. `profile_screen.dart` - プロフィールホーム
2. `profile_edit_screen.dart` - プロフィール編集
3. `auth_screen.dart` - 認証画面
4. `notification_settings_screen.dart` - 通知設定
5. `onboarding_screen.dart` - オンボーディング
6. `campaign_registration_screen.dart` - キャンペーン登録
7. `campaign_sns_share_screen.dart` - SNSシェア
8. `terms_of_service_screen.dart` - 利用規約
9. `tokutei_shoutorihikihou_screen.dart` - 特定商取引法
10. `personal_training_screen.dart` - パーソナルトレーニング
11. `reservation_form_screen.dart` - 予約フォーム
12. `phase_migration_screen.dart` - フェーズ移行

#### サービス
- `auth_service.dart` - Firebase Auth（匿名認証）
- `profile_service.dart` - プロフィール管理
- `notification_service.dart` - 通知管理
- `onboarding_service.dart` - オンボーディング進捗
- `campaign_service.dart` - キャンペーン管理
- `referral_service.dart` - 紹介プログラム
- `personal_training_service.dart` - PT予約
- `offline_service.dart` - Hiveオフラインキャッシュ

---

### 🔒 開発者・管理者機能
**画面数**: 9画面  
**サービス数**: 4サービス

#### 画面リスト
1. `developer_menu_screen.dart` - 開発者メニュー
2. `password_gate_screen.dart` - パスワードゲート
3. `debug_log_screen.dart` - デバッグログ
4. `po_login_screen.dart` - PO（プロダクトオーナー）ログイン
5. `po_dashboard_screen.dart` - POダッシュボード
6. `po_analytics_screen.dart` - PO分析画面
7. `po_members_screen.dart` - PO会員管理
8. `po_member_detail_screen.dart` - PO会員詳細
9. `po_sessions_screen.dart` - POセッション管理

#### サービス
- `console_logger.dart` - コンソールログ（JS Interop）
- `debug_service.dart` - デバッグ機能
- `po_service.dart` - プロダクトオーナー管理
- `analytics_service.dart` - アナリティクス集計

---

## 🎯 コア機能詳細

### 1️⃣ トレーニング記録管理

#### **機能概要**
詳細記録（種目・重量・回数・セット・RPE）→ カレンダービュー → 統計ダッシュボード → テンプレート → CSVエクスポート

#### **主要機能**
1. **詳細記録**
   - 種目選択（300+ 種目データベース）
   - 重量・回数・セット数
   - RPE（主観的運動強度 6-20）
   - セットタイプ（通常・ウォームアップ・ドロップセット・スーパーセット）
   - メモ機能
   
2. **カレンダービュー**
   - 月間カレンダーでトレーニング日を視覚化
   - 日付タップで当日の記録詳細表示
   
3. **統計ダッシュボード**
   - 7日間総挙上重量
   - 今月総挙上重量
   - 全期間総挙上重量
   - 月間ワークアウト日数
   - 部位別トレーニング量
   
4. **テンプレート機能**
   - よく行うメニューを保存
   - ワンタップで適用
   
5. **CSV インポート/エクスポート**
   - 他アプリからのデータ移行
   - バックアップ作成

#### **ユーザーシーン**
- **シーン1**: トレーニング直後に即座に記録
- **シーン2**: 月間の成長を統計で確認
- **シーン3**: テンプレートを使って効率的に記録

---

### 2️⃣ AI コーチング（Google Gemini 2.0 Flash）

#### **機能概要**
Google Gemini 2.0 Flash AI を搭載し、部位別・レベル別に最適なトレーニングメニューを自動生成。

#### **主要機能**
1. **部位別メニュー生成**
   - 胸・背中・脚・肩・腕（二頭筋・三頭筋）・体幹・有酸素
   
2. **レベル別カスタマイズ**
   - **初心者モード**: フォーム重視、安全な種目選定
   - **中級者モード**: ボリューム重視、複合種目中心
   - **上級者モード**: 高強度、ドロップセット・スーパーセット推奨
   
3. **成長予測**
   - 1RM予測（理論的最大挙上重量）
   - 成長曲線予測
   - 個人要因補正（年齢・経験年数・睡眠・栄養・飲酒）
   
4. **週次レポート自動生成**
   - 週間総挙上重量
   - 部位別トレーニング量分析
   - 前週比較・変化率
   - AI による改善提案
   
5. **疲労管理システム**
   - トレーニング量から疲労度を自動計算
   - 部位別疲労度の可視化
   - オーバートレーニング警告

#### **AI使用回数制限**
| プラン | 月間回数 | リワード広告 | 追加パック |
|--------|----------|--------------|------------|
| **無料** | 0回 | 月3回まで | ¥300/5回 |
| **Premium** | 10回 | 利用可能 | ¥300/5回 |
| **Pro** | ∞（無制限） | 利用可能 | ¥300/5回 |

#### **リワード広告（新機能 v1.02）**
- **トリガー**: AIクレジット0回のとき「動画を見て1回分ゲット」ボタン表示
- **報酬**: 30秒動画視聴で +1 AI使用回数
- **上限**: 月3回まで（無料プラン）

---

### 3️⃣ パートナーマッチング（Proプラン限定）

#### **機能概要**
同じ目標を持つトレーニング仲間をマッチング。3層マッチングアルゴリズムで最適なパートナーを提案。

#### **マッチングアルゴリズム**
1. **Skill-based Matching（±15% 1RM）**
   - BIG3（ベンチプレス・スクワット・デッドリフト）の1RMで ±15% 以内をマッチング
   - 実力差が大きすぎるユーザーは除外（初心者と上級者のミスマッチ防止）
   
2. **時空間コンテキストマッチング**
   - 同じジムをお気に入り登録
   - 同じ曜日・時間帯（±2時間）に活動
   
3. **Pro Plan限定可視性**
   - 無料ユーザーはPro会員を検索不可
   - Pro会員は全ユーザーを検索可能（非対称性）

#### **主要機能**
1. **条件検索**
   - 距離（現在地から〇km 圏内）
   - トレーニング目標（筋肥大・筋力向上・減量等）
   - 経験レベル（初心者・中級者・上級者）
   - 性別・年齢・よく行く曜日・時間帯
   
2. **メッセージング機能**
   - 1対1チャット
   - リアルタイム更新（Firebase Realtime Database）
   - チャットルーム一覧
   
3. **フレンドリクエスト**
   - リクエスト送信・受信
   - 承認・拒否機能

---

### 4️⃣ ジム検索・混雑度表示

#### **機能概要**
GPS位置情報とGoogle Maps連携で、現在地周辺のジムをリアルタイム混雑度付きで検索・表示。

#### **主要機能**
1. **リアルタイム混雑度表示（5段階）**
   - 空いている 🟢 → やや混雑 🟡 → 混雑 🟠 → 非常に混雑 🔴
   - ユーザーレポート（24時間有効）を最優先
   - 統計データから推定混雑度を算出
   
2. **ジム詳細情報**
   - 営業時間・定休日・電話番号・住所
   - 設備情報（フリーウェイト・マシン・有酸素・シャワー等）
   - 写真ギャラリー
   - Google Maps連携（ルート検索ワンタップ）
   
3. **お気に入り登録（Premium以上）**
   - よく行くジムをブックマーク
   - お気に入り一覧から素早くアクセス

---

## 💰 料金プラン・マネタイズ戦略

### 📊 プラン比較表

| 機能 | 無料 | Premium | Pro |
|------|------|---------|-----|
| **月額料金** | ¥0 | ¥500/月<br>¥4,800/年 | ¥980/月<br>¥8,000/年 |
| **無料トライアル** | - | 30日間 | 14日間 |
| **トレーニング記録** | ✅ | ✅ | ✅ |
| **AI 機能** | 🎬 広告視聴で月3回 | ✅ 月10回 | ✅ 無制限（∞） |
| **お気に入り保存** | ⚠️ 制限あり | ✅ 無制限 | ✅ 無制限 |
| **パートナー検索** | ❌ | ❌ | ✅ |
| **メッセージング** | ❌ | ❌ | ✅ |
| **広告表示** | ⚠️ あり | ✅ なし | ✅ なし |

---

### 🆓 無料プラン（¥0 / 永久無料）

#### **利用可能機能**
- ✅ トレーニング記録
- ✅ カレンダービュー
- ✅ 統計ダッシュボード
- ✅ 計算ツール（RM・プレート）
- ✅ 目標設定・達成バッジ
- ✅ AI 機能（リワード広告視聴で月3回まで）

#### **制限事項**
- ⚠️ **お気に入り保存**: 制限あり
- ⚠️ **AI 機能**: リワード広告視聴必須（月3回まで）
- ⚠️ **広告表示**: バナー広告あり
- ❌ **パートナー検索**: 不可

#### **マネタイズ戦略**
- **バナー広告**: ホーム画面下部に常時表示
- **リワード広告**: AI 機能使用のために視聴

---

### 💎 Premium プラン

#### **料金体系**
| 期間 | 料金 | 月換算 | 割引率 | 年間節約額 |
|------|------|--------|--------|------------|
| **月額** | ¥500/月 | ¥500/月 | - | - |
| **年額** | ¥4,800/年 | ¥400/月 | **20% OFF** | **¥1,200お得** |

#### **無料トライアル**
- **期間**: 30日間
- **特典**: 全 Premium 機能を無料体験

#### **利用可能機能**
- ✨ **無料プランの全機能**
- 🤖 **AI 機能 月10回**
- ❤️ **お気に入り無制限**
- 📊 **詳細な混雑度統計**
- 🔔 **混雑度アラート通知**
- 📝 **ジムレビュー投稿**
- 🚫 **広告なし**

---

### 🌟 Pro プラン

#### **料金体系**
| 期間 | 料金 | 月換算 | 割引率 | 年間節約額 |
|------|------|--------|--------|------------|
| **月額** | ¥980/月 | ¥980/月 | - | - |
| **年額** | ¥8,000/年 | ¥667/月 | **32% OFF** | **¥3,760お得** |

#### **無料トライアル**
- **期間**: 14日間
- **特典**: 全 Pro 機能を無料体験

#### **利用可能機能**
- ✨ **Premium プランの全機能**
- 🤖 **AI 機能 無制限（∞）**
- 👥 **トレーニングパートナー検索**
- 💬 **メッセージング機能**
- 🤝 **フレンドリクエスト**

---

### 🎁 AI 追加パック（全ユーザー対象）

#### **料金・内容**
- **価格**: **¥300 / 5回**
- **単価**: ¥60/回
- **対象**: 全ユーザー（無料・Premium・Pro 問わず）
- **有効期限**: 今月末まで（月次リセット）
- **Product ID**: `com.nexa.gymmatch.ai_pack_5_v2`

---

## 💻 技術スタック

### **フロントエンド**
| カテゴリ | 技術 | バージョン |
|----------|------|------------|
| **開発言語** | Dart | 3.5.0+ |
| **フレームワーク** | Flutter | 3.35.4 |
| **状態管理** | Provider | 6.1.5 |

### **バックエンド・データベース**
| カテゴリ | 技術 | 用途 |
|----------|------|------|
| **データベース** | Firebase Firestore | メインデータストア（22コレクション）|
| **認証** | Firebase Authentication | 匿名ログイン |
| **ストレージ** | Firebase Storage | 画像保存 |
| **ローカルDB** | Hive | オフラインキャッシュ |

### **外部API連携**
| サービス | 用途 | 詳細 |
|----------|------|------|
| **Google Places API** | ジム検索 | 全国のジム情報取得 |
| **Google Maps API** | 地図表示 | ルート検索 |
| **Google Gemini 2.0 Flash** | AI コーチング | メニュー生成・成長予測 |
| **RevenueCat** | iOS 課金管理 | サブスクリプション |
| **Google AdMob** | 広告配信 | バナー・リワード広告 |

### **Firestore データ構造（22コレクション）**
```
gyms/                    # ジム情報
users/                   # ユーザープロファイル
workout_logs/            # トレーニング記録
personal_records/        # パーソナルレコード
weekly_reports/          # 週次レポート
goals/                   # 目標
achievements/            # 達成バッジ
crowd_reports/           # 混雑度レポート
reviews/                 # ジムレビュー
favorites/               # お気に入り
training_partners/       # トレーニングパートナー
chat_rooms/              # チャットルーム
chat_messages/           # チャットメッセージ
friend_requests/         # フレンドリクエスト
... (他8コレクション)
```

---

## 📈 ビジネスモデル・収益予測

### **収益源（3層構造）**
1. **サブスクリプション収益**（主収益）
   - Premium プラン: ¥500/月 or ¥4,800/年
   - Pro プラン: ¥980/月 or ¥8,000/年
   
2. **広告収益**（無料プラン）
   - バナー広告（ホーム画面）
   - リワード広告（AI 機能使用）
   
3. **追加課金収益**
   - AI 追加パック: ¥300/5回

### **ARR予測（12ヶ月）**
- **目標**: ¥100,000,000（1億円）
- **v1.02実績予測**: **¥144,800,000（144.8%達成）**
- **内訳**:
  - サブスクリプション: ¥140,000,000
  - 広告収益: ¥4,800,000

---

## 🎯 今後の展開

### **短期（3ヶ月）**
- ✅ iOS App Store リリース（完了）
- 🔄 AdMob 広告配信開始（テスト中）
- 📢 マーケティング開始（SNS・ブログ等）

### **中期（6ヶ月）**
- 📱 プッシュ通知実装
- 📊 データバックアップ・復元機能
- 🎥 動画フォームチェック機能（予定）

### **長期（1年）**
- 🤖 Android版リリース
- 🌍 多言語対応（英語・中国語）
- ⌚ Apple Watch 対応

---

## 📞 お問い合わせ

**開発元**: NEXA  
**アプリ名**: GYM MATCH  
**App Store**: https://apps.apple.com/jp/app/gym-match/id6755346813  
**GitHub**: https://github.com/aka209859-max/gym-tracker-flutter  
**お問い合わせ**: アプリ内「設定」→「お問い合わせ」

---

**© 2025 NEXA. All Rights Reserved.**
