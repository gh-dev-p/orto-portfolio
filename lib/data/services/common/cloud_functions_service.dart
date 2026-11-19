import 'package:cloud_functions/cloud_functions.dart';

// ============================================================
// サービス
// ============================================================

/// Cloud Functions（Admin SDK）の関数を呼ぶサービス
/// 状態を持たず、Cloud Functionsのエラーをそのまま投げる（エラーの変換は各リポジトリが行う）。関数はasia-northeast1に置いている（firebase/functions/index.js）
class CloudFunctionsService {
  CloudFunctionsService(this._functions);

  // ---- 状態・初期化 ----

  /// Cloud Functionsのインスタンス
  final FirebaseFunctions _functions;

  // ---- 呼び出し ----

  /// 関数[name]を、[data]を渡して呼ぶ
  /// 失敗したら[FirebaseFunctionsException]を投げる
  /// [timeout]は既定（60秒）より長くかかる関数で指定する
  Future<void> call(String name, [Map<String, dynamic>? data, Duration? timeout]) => _functions
      .httpsCallable(name, options: timeout == null ? null : HttpsCallableOptions(timeout: timeout))
      .call<void>(data);

  /// 関数[name]を、[data]を渡して呼び、結果を返す
  /// 失敗したら[FirebaseFunctionsException]を投げる
  Future<Map<String, dynamic>> callForResult(String name, [Map<String, dynamic>? data]) async {
    final result = await _functions.httpsCallable(name).call<Map<Object?, Object?>>(data);
    return Map<String, dynamic>.from(result.data);
  }
}
