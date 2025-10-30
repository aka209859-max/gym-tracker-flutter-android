/// Google Places API設定
/// 
/// セキュリティノート:
/// - 本番環境では環境変数または秘密管理サービスを使用してください
/// - APIキーはHTTP Refererで制限されています
class ApiKeys {
  // Google Places API Key
  static const String googlePlacesApiKey = 'AIzaSyA9XmQSHA1llGg7gihqjmOOIaLA856fkLc';
  
  // Google Places API Base URL
  static const String placesApiBaseUrl = 'https://maps.googleapis.com/maps/api/place';
  
  // デフォルト検索パラメータ
  static const int defaultSearchRadius = 5000; // 5km
  static const String defaultLanguage = 'ja'; // 日本語
  static const String defaultRegion = 'jp'; // 日本
}
