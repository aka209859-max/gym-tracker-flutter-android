# 🏋️ GYM MATCH Manager 引き継ぎドキュメント

## 📅 作成日: 2025年11月21日
## 🎯 目的: 業界TOPレベル（フィットネス界のSalesforce）への昇華

---

## 📂 1. プロジェクト構造

### **現在のGYM MATCH Managerファイル一覧**

#### **画面ファイル (lib/screens/po/)**
```
po_dashboard_screen.dart          - ダッシュボード（KPI表示）
po_login_screen.dart              - ジムオーナーログイン
po_members_screen.dart            - 会員管理リスト
po_member_detail_screen.dart      - 会員詳細
po_analytics_screen.dart          - 分析画面
po_sessions_screen.dart           - セッション管理
gym_announcement_editor_screen.dart - お知らせ編集
gym_equipment_editor_screen.dart   - 設備編集
```

#### **モデルファイル (lib/models/)**
```
pt_member.dart                    - パーソナルトレーニング会員モデル
partner_profile.dart              - パートナー（ジム）プロフィール
partner_access.dart               - アクセス権限管理
training_partner.dart             - トレーニングパートナー
```

#### **サービスファイル (lib/services/)**
```
partner_service.dart              - パートナー関連ビジネスロジック
partner_search_service.dart       - パートナー検索機能
partner_merge_service.dart        - データマージ処理
```

---

## 🔑 2. Firebase Firestore データ構造

### **コレクション構造**

```
gyms/                             - ジム情報
  {gymId}/
    - name: string
    - address: string
    - facilities: array
    - openingHours: map

poOwners/                         - ジムオーナー情報
  {ownerId}/
    - email: string
    - gymName: string
    - createdAt: timestamp
    
    members/                      - サブコレクション: 会員
      {memberId}/
        - name: string
        - email: string
        - isActive: boolean
        - joinedAt: timestamp

personalTrainingMembers/          - PT会員（グローバルコレクション）
  {memberId}/
    - partnerId: string (ジムID)
    - name: string
    - email: string
    - phoneNumber: string
    - isActive: boolean
    - sessionCount: number
    - notes: string
    - createdAt: timestamp

reservations/                     - 予約情報
  {reservationId}/
    - userId: string
    - gymId: string
    - date: timestamp
    - status: string (pending/confirmed/cancelled)
```

---

## 🔧 3. 現在実装済みの機能

### ✅ **ダッシュボード (po_dashboard_screen.dart)**
- KPIカード表示
  - 総会員数
  - アクティブ会員数
  - 休眠会員数
- Firebase Firestore からリアルタイム取得
- ログアウト機能

### ✅ **会員管理 (po_members_screen.dart)**
- 会員リスト表示（StreamBuilder使用）
- フィルター機能
  - 全会員
  - アクティブ会員
  - 休眠中会員
- サマリーカード表示
- 会員詳細画面への遷移

### ✅ **認証システム (po_login_screen.dart)**
- Firebase Authentication
- メール/パスワードログイン
- エラーハンドリング

### ✅ **ジム情報編集**
- お知らせ編集機能
- 設備情報編集機能

---

## 🚀 4. 業界TOPレベルへの拡張計画

### **Phase 1: 基盤強化（12/15ピッチまで）**

#### 📊 **ダッシュボード強化**
- [ ] リアルタイム売上グラフ（fl_chart使用）
- [ ] 会員数推移グラフ（週次/月次）
- [ ] 今月 vs 先月の比較KPI
- [ ] 予約状況のカレンダー表示
- [ ] 直近のアクティビティフィード

#### 💰 **freee会計ソフト連携**
- [ ] OAuth 2.0認証フロー実装
- [ ] 会員月謝の自動仕訳
- [ ] パーソナルトレーニング売上連携
- [ ] 設備購入・経費管理連携
- [ ] 双方向データ同期

**技術スタック**:
```
Flutter → Firebase Cloud Functions → freee API
```

**必要なパッケージ**:
```yaml
dependencies:
  cloud_functions: ^latest    # Firebase Cloud Functions呼び出し
  url_launcher: ^latest       # OAuth認証用
```

#### 📅 **予約管理システム**
- [ ] 予約カレンダー（table_calendar活用）
- [ ] 予約承認/拒否機能
- [ ] 自動リマインダー（Firebase Cloud Messaging）
- [ ] ノーショー記録・管理
- [ ] キャンセルポリシー設定

### **Phase 2: Salesforceレベル機能（審査通過後）**

#### 🎯 **CRM機能**
- [ ] 顧客セグメンテーション
- [ ] マーケティングオートメーション
- [ ] メール/SMS一斉配信
- [ ] クーポン・キャンペーン管理

#### 🤖 **ビジネスインテリジェンス**
- [ ] AI売上予測
- [ ] 離脱リスク分析（機械学習）
- [ ] LTV（顧客生涯価値）計算
- [ ] レポート自動生成

#### 👥 **スタッフ管理**
- [ ] シフト管理カレンダー
- [ ] 権限設定（オーナー/マネージャー/スタッフ）
- [ ] パフォーマンス追跡
- [ ] 給与計算連携

---

## 🔐 5. セキュリティ設計

### **Firebase Auth Custom Claims**
```javascript
// Cloud Functions でカスタムクレーム設定
admin.auth().setCustomUserClaims(uid, {
  role: 'gym_owner',
  gymId: 'gym_12345',
  permissions: ['manage_members', 'view_analytics', 'edit_settings']
});
```

### **Firestore Security Rules**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ジムオーナーは自分のジムデータのみアクセス可能
    match /poOwners/{ownerId} {
      allow read, write: if request.auth.uid == ownerId;
      
      match /members/{memberId} {
        allow read, write: if request.auth.uid == ownerId;
      }
    }
    
    // PT会員は該当ジムのオーナーのみアクセス可能
    match /personalTrainingMembers/{memberId} {
      allow read: if request.auth.token.role == 'gym_owner' 
                  && resource.data.partnerId == request.auth.token.gymId;
      allow write: if request.auth.token.role == 'gym_owner' 
                   && request.auth.token.gymId == request.resource.data.partnerId;
    }
  }
}
```

---

## 📦 6. 必要な追加パッケージ

### **UI/UX強化**
```yaml
dependencies:
  # 既存（活用）
  fl_chart: ^0.69.0              # グラフ表示
  table_calendar: ^3.1.2         # カレンダー
  
  # 追加推奨
  syncfusion_flutter_charts: ^latest  # 高品質チャート
  data_table_2: ^latest          # データテーブル
  flutter_animate: ^latest       # アニメーション
  shimmer: ^latest               # ローディング効果
```

### **freee連携**
```yaml
dependencies:
  http: ^latest                  # HTTP通信
  oauth2: ^latest                # OAuth認証
  cloud_functions: ^latest       # Firebase Functions
```

### **通知・リマインダー**
```yaml
dependencies:
  firebase_messaging: ^latest    # プッシュ通知
  flutter_local_notifications: ^latest  # ローカル通知
```

---

## 🔄 7. freee API連携の詳細手順

### **Step 1: freee開発者登録**
1. https://developer.freee.co.jp/ にアクセス
2. アプリケーション登録
3. Client ID と Client Secret を取得
4. Redirect URI を設定: `https://your-app.com/callback`

### **Step 2: Firebase Cloud Functions 作成**

**functions/index.ts**:
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';

admin.initializeApp();

// freee API トークン取得
export const getFreeeAccessToken = functions.https.onCall(async (data, context) => {
  const { code } = data;
  
  const response = await axios.post('https://accounts.secure.freee.co.jp/public_api/token', {
    grant_type: 'authorization_code',
    client_id: process.env.FREEE_CLIENT_ID,
    client_secret: process.env.FREEE_CLIENT_SECRET,
    code: code,
    redirect_uri: process.env.FREEE_REDIRECT_URI,
  });
  
  return response.data;
});

// 売上データをfreeeに送信
export const syncRevenueToFreee = functions.https.onCall(async (data, context) => {
  const { accessToken, companyId, amount, description, date } = data;
  
  const response = await axios.post(
    `https://api.freee.co.jp/api/1/deals`,
    {
      company_id: companyId,
      issue_date: date,
      type: 'income',
      partner_id: null, // 取引先ID（オプション）
      details: [
        {
          account_item_id: 12345, // 売上高の勘定科目ID
          tax_code: 108, // 課税売上10%
          amount: amount,
          description: description,
        }
      ]
    },
    {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      }
    }
  );
  
  return response.data;
});
```

### **Step 3: Flutter側実装**

**lib/services/freee_service.dart**:
```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

class FreeeService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // OAuth認証開始
  Future<void> authenticateWithFreee() async {
    final authUrl = Uri.parse(
      'https://accounts.secure.freee.co.jp/public_api/authorize'
      '?client_id=YOUR_CLIENT_ID'
      '&redirect_uri=YOUR_REDIRECT_URI'
      '&response_type=code'
    );
    
    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    }
  }
  
  // 売上をfreeeに送信
  Future<void> syncRevenue({
    required String accessToken,
    required int companyId,
    required double amount,
    required String description,
    required DateTime date,
  }) async {
    final callable = _functions.httpsCallable('syncRevenueToFreee');
    
    final result = await callable.call({
      'accessToken': accessToken,
      'companyId': companyId,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD形式
    });
    
    return result.data;
  }
}
```

---

## 📊 8. ダッシュボード強化の実装例

### **リアルタイム売上グラフ**

**lib/screens/po/po_dashboard_enhanced.dart**:
```dart
import 'package:fl_chart/fl_chart.dart';

class EnhancedDashboard extends StatefulWidget {
  @override
  State<EnhancedDashboard> createState() => _EnhancedDashboardState();
}

class _EnhancedDashboardState extends State<EnhancedDashboard> {
  List<FlSpot> _revenueData = [];
  
  @override
  void initState() {
    super.initState();
    _loadRevenueData();
  }
  
  Future<void> _loadRevenueData() async {
    // Firestoreから売上データ取得
    final snapshot = await FirebaseFirestore.instance
        .collection('revenues')
        .orderBy('date')
        .limit(30)
        .get();
    
    setState(() {
      _revenueData = snapshot.docs.asMap().entries.map((entry) {
        return FlSpot(
          entry.key.toDouble(),
          (entry.value.data()['amount'] as num).toDouble(),
        );
      }).toList();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('売上推移', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _revenueData,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🎯 9. 12/15ピッチまでの開発優先度

### **最優先（必須）**
1. ✅ ダッシュボード強化（売上グラフ、KPI強化）
2. ✅ 予約管理カレンダー実装
3. ✅ デモ用サンプルデータ整備

### **高優先（できれば実装）**
4. ✅ freee連携のデモ（OAuth認証まで）
5. ✅ 会員管理の検索・フィルター強化

### **中優先（時間があれば）**
6. ⚠️ リアルタイム通知機能
7. ⚠️ レポート出力機能

---

## 📝 10. 開発時の注意点

### **既存機能を壊さない**
- GYM MATCHユーザー向け機能には影響しない
- `lib/screens/po/` 配下のみ編集
- Firebase Firestoreの既存コレクション構造は維持

### **freee連携の二度手間防止**
- 会員登録時に自動でfreeeに顧客情報送信
- 売上発生時に自動で仕訳作成
- 経費入力時に双方向同期

### **パフォーマンス**
- StreamBuilderを活用してリアルタイム更新
- ページネーション実装（会員数が多い場合）
- キャッシュ戦略（Firestoreのオフライン永続化）

---

## 🔗 11. 参考リンク

- freee API ドキュメント: https://developer.freee.co.jp/docs
- Firebase Cloud Functions: https://firebase.google.com/docs/functions
- fl_chart 公式: https://pub.dev/packages/fl_chart
- Firestore セキュリティルール: https://firebase.google.com/docs/firestore/security/get-started

---

## 📞 12. 引き継ぎ後の確認事項

- [ ] Firebase プロジェクト設定の確認
- [ ] freee開発者アカウントの作成
- [ ] OAuth Redirect URI の設定
- [ ] Cloud Functions のデプロイ環境構築
- [ ] テストデータの準備

---

**作成者**: Claude Code (Genspark AI)  
**最終更新**: 2025年11月21日  
**バージョン**: 1.0.0  
**対象プロジェクト**: GYM MATCH (flutter_app)
