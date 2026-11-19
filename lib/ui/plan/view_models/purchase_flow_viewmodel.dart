import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../config/service_providers.dart';
import '../../../config/store_products.dart';
import '../../../data/services/billing/store_purchase_service.dart';
import '../../account/view_models/account_providers.dart';
import '../../auth/view_models/auth_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// 画面操作の購入・復元の結果（SET-07のSnackBar用）
enum PurchaseOutcome {
  /// planに反映した
  applied,

  /// 変更を予約した（ダウングレードは次回の更新日から反映する）
  scheduled,

  /// 承認待ち（保護者の承認など）
  pending,

  /// すでに契約中、または変更を予約済み
  alreadyOwned,

  /// サーバーの反映、またはストアの処理に失敗した
  failed,

  /// 復元できる購入が無かった
  nothingToRestore,
}

/// 予約中のプラン変更
/// [startsAt]は変わる日時
typedef ScheduledPlanChange = ({String plan, DateTime startsAt});

/// 購入の処理の状態
class PurchaseFlowState {
  const PurchaseFlowState({this.busy = false, this.outcome});

  /// 購入・復元の処理中か
  final bool busy;

  /// 直近の画面操作の結果
  /// 画面が読み取ったら[PurchaseFlowViewModel.clearOutcome]で消す
  final PurchaseOutcome? outcome;
}

// ============================================================
// ViewModel
// ============================================================

/// 購入の処理（機能仕様書4.6.4）
/// 購入・復元の直後にサーバーへ反映を頼む。自動更新・解約はストアからRevenueCatとWebhookを通ってサーバーへ届くため、
/// アプリは関わらない
class PurchaseFlowViewModel extends Notifier<PurchaseFlowState> {

  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  @override
  PurchaseFlowState build() => const PurchaseFlowState();

  // ---- 操作 ----

  /// [product]を購入する
  /// 同じストアの別のプランを契約中なら、そのプランから変更する
  Future<void> buy(StoreProduct product, {required String plan}) => _run(() async {
    final store = ref.read(storePurchaseServiceProvider);
    await ref.read(billingSessionProvider.future);
    final active = await ref.read(activeSubscriptionProvider.future);
    final currentRank = StoreProducts.paidPlans.indexOf(ref.read(userPlanProvider).value ?? '');
    final newRank = StoreProducts.paidPlans.indexOf(plan);
    await store.purchase(
      product,
      replacing: active?.store == SubscriptionStore.playStore ? active?.productId : null,
      upgrade: newRank > currentRank,
    );
    await ref.read(billingRepositoryProvider).syncPlan();
    return newRank < currentRank ? PurchaseOutcome.scheduled : PurchaseOutcome.applied;
  });

  /// 購入を復元する
  Future<void> restore() => _run(() async {
    await ref.read(billingSessionProvider.future);
    if (!await ref.read(storePurchaseServiceProvider).restore()) return PurchaseOutcome.nothingToRestore;
    await ref.read(billingRepositoryProvider).syncPlan();
    return PurchaseOutcome.applied;
  });

  /// 結果を読み取り済みにする
  void clearOutcome() => state = PurchaseFlowState(busy: state.busy);

  // ---- 内部処理 ----

  /// 画面操作の購入・復元を[action]で行い、結果を状態に入れる
  Future<void> _run(Future<PurchaseOutcome> Function() action) async {
    if (state.busy) return;
    state = const PurchaseFlowState(busy: true);
    PurchaseOutcome? outcome;
    try {
      outcome = await action();
    } on PurchaseCancelledException {
      outcome = null;
    } on PurchasePendingException {
      outcome = PurchaseOutcome.pending;
    } on PurchaseAlreadyOwnedException {
      outcome = PurchaseOutcome.alreadyOwned;
    } catch (_) {
      outcome = PurchaseOutcome.failed;
    }
    ref.invalidate(activeSubscriptionProvider);
    ref.invalidate(scheduledPlanChangeProvider);
    ref.invalidate(transferablePlanProvider);
    state = PurchaseFlowState(outcome: outcome);
  }
}

// ============================================================
// Provider
// ============================================================

/// [PurchaseFlowViewModel]のProvider
final purchaseFlowViewModelProvider = NotifierProvider<PurchaseFlowViewModel, PurchaseFlowState>(
  PurchaseFlowViewModel.new,
);

/// SDKを今のuidのbillingIdで使える状態にする（SET-07を開いたときに動く）
/// 購入できない設定ならfalse
final billingSessionProvider = FutureProvider.autoDispose<bool>((ref) async {
  final store = ref.watch(storePurchaseServiceProvider);
  final uid = ref.watch(authStateChangesProvider.select((user) => user.value?.uid));
  if (uid == null || !store.isAvailable) return false;
  await store.start(await ref.watch(billingRepositoryProvider).getBillingId());
  return true;
});

/// 有効なサブスクリプション（SET-07）
/// 別のストアの契約なら、購入ボタンを隠して契約元のストアへ案内する
final activeSubscriptionProvider = FutureProvider.autoDispose<ActiveSubscription?>((ref) async {
  if (!await ref.watch(billingSessionProvider.future)) return null;
  return ref.watch(storePurchaseServiceProvider).fetchActiveSubscription();
});

/// 予約中のプラン変更（SET-07）。無ければnull
final scheduledPlanChangeProvider = FutureProvider.autoDispose<ScheduledPlanChange?>((ref) async {
  if (!await ref.watch(billingSessionProvider.future)) return null;
  final change = await ref.watch(storePurchaseServiceProvider).fetchScheduledChange();
  if (change == null) return null;
  final plan = StoreProducts.planForProductId(change.productId);
  return plan == null ? null : (plan: plan, startsAt: change.startsAt);
});

/// 引き継げる契約のプラン（SET-07、機能仕様書4.6.4.2）。無ければnull
/// ストアに有効な契約があるのに、今のbillingIdの顧客に紐付いていない状態を見つける。
/// 開いただけでは移さず、画面操作の[PurchaseFlowViewModel.restore]で移す
final transferablePlanProvider = FutureProvider.autoDispose<String?>((ref) async {
  if (!await ref.watch(billingSessionProvider.future)) return null;
  if (await ref.watch(activeSubscriptionProvider.future) != null) return null;
  final productIds = await ref.watch(storePurchaseServiceProvider).fetchStoreProductIds();
  return productIds.map(StoreProducts.planForProductId).nonNulls.firstOrNull;
});

/// 有料プランの商品（SET-07）
/// プランごとの商品を返す。ストアが使えないときは空
final planProductsProvider = FutureProvider.autoDispose<Map<String, StoreProduct>>((ref) async {
  if (!await ref.watch(billingSessionProvider.future)) return const {};
  final productIds = {for (final plan in StoreProducts.paidPlans) StoreProducts.productIdFor(plan): plan};
  final products = await ref.watch(storePurchaseServiceProvider).fetchProducts(productIds.keys.toSet());
  // Google Playの商品は`商品ID:基本プランID`で返る
  return {for (final product in products) productIds[product.identifier.split(':').first]!: product};
});
