import '../../services/common/cloud_functions_service.dart';

// ============================================================
// リポジトリ
// ============================================================

/// 有料プランのサーバー側の処理を扱うリポジトリ（機能仕様書4.6.4）
/// `users/{uid}.plan`はCloud Functionsだけが書き換える（firestore.rules）。結果は[UserRepository.watchUserPlan]で届く
class BillingRepository {
  BillingRepository(this._functionsService);

  // ---- 状態・初期化 ----

  /// Cloud Functionsのサービス
  final CloudFunctionsService _functionsService;

  // ---- 操作 ----

  /// RevenueCatのSDKに渡すbillingIdを取得する（無ければサーバーが発行する）
  Future<String> getBillingId() async {
    final result = await _functionsService.callForResult('getBillingId');
    return result['billingId'] as String;
  }

  /// 購入・復元の結果を、サーバーがRevenueCatから取り直してplanに反映する
  Future<void> syncPlan() => _functionsService.call('syncBillingPlan');

  /// 使い続けるアカウントを[accountIds]にする（機能仕様書4.2.1.3）
  /// 上限を超えている間に、プランが変わるごとに1回だけ行える。結果は[UserRepository.watchKeptAccounts]で届く
  Future<void> setKeptAccounts(List<String> accountIds) =>
      _functionsService.call('setKeptAccounts', {'accountIds': accountIds});
}
