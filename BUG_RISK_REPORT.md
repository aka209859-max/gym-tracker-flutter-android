# 🔍 GYM MATCH App バグリスク分析レポート

**分析日**: 2025-11-28  
**対象**: GYM MATCH App (iOS専用)  
**総ファイル数**: 167個のDartファイル

---

## 📋 エグゼクティブサマリー

全コードベースを分析し、以下のバグリスクを特定しました：

| リスクレベル | 件数 | 影響 |
|------------|------|------|
| 🔴 **Critical** | 3件 | アプリクラッシュ・データ損失 |
| 🟠 **High** | 8件 | 機能不全・ユーザー体験の重大な問題 |
| 🟡 **Medium** | 15件 | パフォーマンス低下・UI問題 |
| 🟢 **Low** | 多数 | 軽微な問題 |

---

## 🔴 Critical リスク（緊急対応推奨）

### 1. ❌ setState without mounted check（470箇所）

**リスク**: アプリクラッシュ

**場所**: 全画面で広範囲

**問題**:
```dart
// 危険なパターン
Future<void> _loadData() async {
  final data = await fetchData();
  setState(() {  // ❌ mountedチェックなし
    _data = data;
  });
}
```

**影響**:
- 非同期処理完了前にユーザーが画面を閉じた場合、クラッシュ
- 「setState() called after dispose()」エラー
- アプリ強制終了

**修正案**:
```dart
Future<void> _loadData() async {
  final data = await fetchData();
  if (mounted) {  // ✅ mountedチェック追加
    setState(() {
      _data = data;
    });
  }
}
```

**優先度**: 🔴 最高
**影響範囲**: 全画面（470箇所）
**修正難易度**: 中（一括置換可能）

---

### 2. ❌ Null safety violations with `.data()!` 強制アンラップ

**リスク**: アプリクラッシュ

**場所**: 
- `lib/screens/home_screen.dart:1318`
- `lib/screens/home_screen.dart:2794`
- `lib/screens/home_screen.dart:2841`
- `lib/screens/po/po_dashboard_screen.dart:55`
- `lib/screens/po/po_login_screen.dart:81`
- 他20箇所以上

**問題**:
```dart
final data = docSnapshot.data()!;  // ❌ nullの可能性あり
```

**影響**:
- Firestoreからデータが取得できない場合にクラッシュ
- ネットワークエラー時に高確率で発生
- ユーザーがオフライン時に問題

**修正案**:
```dart
final data = docSnapshot.data();
if (data == null) {
  print('❌ データが存在しません');
  return;
}
// dataを安全に使用
```

**優先度**: 🔴 最高
**影響範囲**: データ取得処理全般
**修正難易度**: 中

---

### 3. ❌ 日付フィルタリングの境界条件（既に修正済み）

**リスク**: データ表示不具合

**場所**: `lib/screens/home_screen.dart:481-485`

**問題**: タイムゾーン・境界条件による日付マッチング失敗

**状態**: ✅ **修正完了**（コミット `e4c2fb8`）

---

## 🟠 High リスク（早期対応推奨）

### 4. ⚠️ Type casting without validation

**リスク**: クラッシュ・データ不整合

**場所**: 全画面で広範囲（特にFirestore操作）

**問題**:
```dart
final sets = data['sets'] as List<dynamic>;  // ❌ 型が違う場合クラッシュ
final weight = (set['weight'] as num).toDouble();  // ❌ null/文字列の場合クラッシュ
```

**影響**:
- Firestoreデータの型が想定と異なる場合にクラッシュ
- 古いバージョンのデータとの互換性問題

**修正案**:
```dart
final sets = data['sets'] as List<dynamic>? ?? [];
final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
```

**優先度**: 🟠 高
**影響範囲**: データ取得・保存処理全般
**修正難易度**: 中

---

### 5. ⚠️ List index access without bounds check

**リスク**: クラッシュ

**問題**:
```dart
final firstSet = sets[0];  // ❌ sets.isEmptyの場合クラッシュ
```

**修正案**:
```dart
if (sets.isNotEmpty) {
  final firstSet = sets[0];
  // 処理
}
```

**優先度**: 🟠 高
**修正難易度**: 低

---

### 6. ⚠️ Memory leaks - Controller not disposed

**リスク**: メモリリーク・パフォーマンス低下

**場所**: 
- `TextEditingController`
- `ScrollController`
- `AnimationController`

**問題**:
```dart
final TextEditingController _controller = TextEditingController();

// ❌ dispose()が呼ばれていない
```

**修正案**:
```dart
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

**優先度**: 🟠 高
**影響**: 長時間使用でメモリ使用量増加
**修正難易度**: 低

---

### 7. ⚠️ Firebase query without error handling

**リスク**: ユーザー体験の低下

**問題**:
```dart
Future<void> _loadData() async {
  // ❌ try-catchなし
  final snapshot = await FirebaseFirestore.instance
      .collection('workout_logs')
      .get();
}
```

**影響**:
- ネットワークエラー時に無限ローディング
- エラーメッセージが表示されない

**修正案**:
```dart
Future<void> _loadData() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('workout_logs')
        .get();
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの取得に失敗しました: $e')),
      );
    }
  }
}
```

**優先度**: 🟠 高
**修正難易度**: 低

---

### 8. ⚠️ AdMob ad loading race condition

**リスク**: 広告収益の損失

**場所**: 
- `lib/services/reward_ad_service.dart`
- `lib/services/admob_service.dart`

**問題**:
- 広告が完全にロードされる前に表示しようとする
- リワード広告のインスタンスが複数作成される（既に一部修正済み）

**状態**: ⚠️ **一部修正済み**（グローバルインスタンス化）

**残存リスク**:
- 広告ロード失敗時のリトライロジックがない
- 広告在庫がない場合の処理が不十分

**優先度**: 🟠 高（収益に直結）
**修正難易度**: 中

---

### 9. ⚠️ Subscription status race condition

**リスク**: 課金処理の不整合

**場所**: 
- `lib/services/subscription_service.dart`
- `lib/services/revenue_cat_service.dart`

**問題**:
- RevenueCatとローカルキャッシュの同期タイミング問題
- サブスクリプション状態の更新中に機能へアクセス

**影響**:
- 有料プランなのに機能が使えない
- 無料プランなのに機能が使える

**優先度**: 🟠 高（課金に直結）
**修正難易度**: 高

---

### 10. ⚠️ AI credit count synchronization issue

**リスク**: AI機能の誤動作

**場所**: 
- `lib/services/ai_credit_service.dart`
- `SharedPreferences`キャッシュ

**問題**:
- ローカルキャッシュとFirestoreの同期問題
- 月次リセットのタイミング問題

**影響**:
- AI回数が正しくカウントされない
- リワード広告視聴後にAI回数が増えない

**優先度**: 🟠 高
**修正難易度**: 中

---

### 11. ⚠️ Workout data cleanup timing issue

**リスク**: データ消失

**場所**: `lib/screens/home_screen.dart:1236` (_cleanupEmptySets)

**問題**:
```dart
// 有効なセットだけをフィルタ（重量または回数が0より大きい）
final validSets = sets.where((set) {
  final weight = (set['weight'] as num).toDouble();
  final reps = set['reps'] as int;
  return weight > 0 || reps > 0;
}).toList();

if (validSets.isEmpty) {
  // 全セットが空の場合、ドキュメント削除
  await FirebaseFirestore.instance
      .collection('workout_logs')
      .doc(doc.id)
      .delete();
}
```

**リスク**:
- 入力途中のデータが削除される可能性
- ユーザーが「重量0kg, 回数0回」を意図的に入力した場合も削除

**影響**:
- トレーニング記録が消える

**修正案**:
- クリーンアップ対象を「作成から24時間以上経過した空セット」に限定
- ユーザーに確認ダイアログを表示

**優先度**: 🟠 高
**修正難易度**: 低

---

## 🟡 Medium リスク（中期対応）

### 12. ⚠️ Performance - Unnecessary widget rebuilds

**リスク**: パフォーマンス低下・バッテリー消費

**場所**: 全画面（StatefulWidget）

**問題**:
- setStateが頻繁に呼ばれる
- 大きなウィジェットツリー全体が再構築される

**修正案**:
- `const` constructorの活用
- StatefulWidget → StatelessWidget変換
- Provider/Riverpodでの状態管理

**優先度**: 🟡 中
**修正難易度**: 中〜高

---

### 13. ⚠️ Firestore query optimization

**リスク**: コスト増加・パフォーマンス低下

**問題**:
- 全ドキュメント取得後にメモリ内フィルタリング
- インデックスが使われていない

**例**:
```dart
// 全記録を取得
final querySnapshot = await FirebaseFirestore.instance
    .collection('workout_logs')
    .where('user_id', isEqualTo: user.uid)
    .get();

// メモリ内でフィルタリング
final filteredWorkouts = allWorkouts.where((workout) {
  // 条件
}).toList();
```

**影響**:
- データ量が増えるとパフォーマンス低下
- Firestoreの読み取り回数増加（コスト増）

**修正案**:
- Firestoreクエリでフィルタリング
- 複合インデックスの作成

**優先度**: 🟡 中
**修正難易度**: 中

---

### 14. ⚠️ Image loading without caching

**リスク**: データ通信量増加

**場所**: ジム画像、ユーザープロフィール画像

**問題**:
- 画像が毎回ダウンロードされる
- キャッシュが効いていない

**修正案**:
- `cached_network_image` パッケージの活用
- 画像サイズの最適化

**優先度**: 🟡 中
**修正難易度**: 低

---

### 15. ⚠️ Deep widget tree causing overflow

**リスク**: レイアウトエラー

**場所**: 複雑な画面（home_screen, workout_log_screen）

**問題**:
- ネストが深すぎる
- `SingleChildScrollView` の不適切な使用

**修正案**:
- ウィジェットの分割
- `ListView.builder` の活用

**優先度**: 🟡 中
**修正難易度**: 中

---

### 16-26. その他のMediumリスク

- Date/Time formatting issues
- Localization missing
- Network timeout not configured
- Background task handling
- Push notification edge cases
- その他...

（詳細は別途調査可能）

---

## 🟢 Low リスク（低優先度）

- コードの可読性
- 命名規則の不統一
- コメント不足
- デバッグログの残存
- etc...

---

## 📊 推奨対応順序

### フェーズ1: 緊急対応（1週間以内）

1. ✅ **setState without mounted check** - 一括修正スクリプトで対応
2. ✅ **Null safety violations** - Critical箇所から順次修正
3. ✅ **Workout data cleanup** - ロジック改善

### フェーズ2: 早期対応（2週間以内）

4. **Type casting validation** - データ取得処理の堅牢化
5. **Error handling** - 全async関数にtry-catch追加
6. **Controller disposal** - メモリリーク対策

### フェーズ3: 中期対応（1ヶ月以内）

7. **Performance optimization** - 段階的な改善
8. **Firestore query optimization** - コスト削減
9. **Image caching** - UX改善

---

## 🎯 最重要修正項目（TOP 3）

### 🥇 1. setState without mounted check（470箇所）

**理由**: 最も頻繁に発生するクラッシュの原因

**対策**: 一括置換スクリプトで修正可能

**修正例**:
```bash
# 全setStateにmountedチェックを追加
sed -i 's/setState((/if (mounted) setState((/g' lib/screens/**/*.dart
```

---

### 🥈 2. Null safety violations（.data()!強制アンラップ）

**理由**: ネットワークエラー時に高確率でクラッシュ

**対策**: Critical箇所（ログイン、データ保存）から優先修正

---

### 🥉 3. Workout data cleanup timing issue

**理由**: ユーザーデータの消失リスク

**対策**: クリーンアップロジックの条件を厳しくする

---

## 📋 次のアクション

ユーザー様の判断を仰ぎます：

1. **🔴 全Critical修正を実施する**
2. **🟠 High優先度のみ修正する**
3. **⚠️ 特定の問題のみ修正する**
4. **📊 さらに詳細な調査を行う**

どの項目を修正するか、ご指示をお願いします。
