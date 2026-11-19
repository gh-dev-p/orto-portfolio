import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/app_flavor.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/config/store_products.dart';
import 'package:multi_id_msg/data/repositories/billing/billing_repository.dart';
import 'package:multi_id_msg/data/services/billing/store_purchase_service.dart';
import 'package:multi_id_msg/domain/models/auth_user.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/auth/view_models/auth_providers.dart';
import 'package:multi_id_msg/ui/plan/view_models/purchase_flow_viewmodel.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class _FakeStore implements StorePurchaseService {
  Object? purchaseError;
  bool restorable = true;
  ActiveSubscription? active;
  ScheduledSubscriptionChange? scheduled;
  List<String> storeProductIds = const [];
  final started = <String>[];
  final purchases = <({StoreProduct product, String? replacing, bool upgrade})>[];

  @override
  bool get isAvailable => true;

  @override
  Future<void> start(String billingId) async => started.add(billingId);

  @override
  Future<ActiveSubscription?> fetchActiveSubscription() async => active;

  @override
  Future<ScheduledSubscriptionChange?> fetchScheduledChange() async => scheduled;

  @override
  Future<List<String>> fetchStoreProductIds() async => storeProductIds;

  @override
  Future<void> purchase(StoreProduct product, {String? replacing, bool upgrade = false}) async {
    if (purchaseError case final error?) throw error;
    purchases.add((product: product, replacing: replacing, upgrade: upgrade));
  }

  @override
  Future<bool> restore() async => restorable;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBilling implements BillingRepository {
  Object? error;
  int syncCount = 0;

  @override
  Future<String> getBillingId() async => 'billing-1';

  @override
  Future<void> syncPlan() async {
    syncCount++;
    if (error case final error?) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _product = StoreProduct('product', '', '', 280, '¥280', 'JPY');

void main() {
  late _FakeStore store;
  late _FakeBilling billing;
  late ProviderContainer container;

  PurchaseFlowViewModel notifier() => container.read(purchaseFlowViewModelProvider.notifier);
  PurchaseFlowState state() => container.read(purchaseFlowViewModelProvider);

  ProviderContainer build({String plan = 'free'}) {
    final result = ProviderContainer(
      overrides: [
        authStateChangesProvider.overrideWith((ref) => Stream.value(const AuthUser(uid: 'uid'))),
        userPlanProvider.overrideWith((ref) => Stream.value(plan)),
        storePurchaseServiceProvider.overrideWithValue(store),
        billingRepositoryProvider.overrideWithValue(billing),
      ],
    );
    addTearDown(result.dispose);
    result.listen(purchaseFlowViewModelProvider, (_, _) {});
    result.listen(billingSessionProvider, (_, _) {});
    result.listen(activeSubscriptionProvider, (_, _) {});
    result.listen(userPlanProvider, (_, _) {});
    return result;
  }

  setUpAll(() => currentFlavor = AppFlavor.dev);

  setUp(() async {
    store = _FakeStore();
    billing = _FakeBilling();
    container = build();
    await pumpEventQueue();
  });

  test('SDKはサーバーが発行したbillingIdで動かす', () {
    expect(store.started.single, 'billing-1');
  });

  test('購入：終わったらサーバーに反映を頼む', () async {
    await notifier().buy(_product, plan: 'grade1');

    expect(store.purchases.single.product, _product);
    expect(store.purchases.single.replacing, isNull);
    expect(billing.syncCount, 1);
    expect(state().busy, isFalse);
    expect(state().outcome, PurchaseOutcome.applied);
  });

  test('サーバーへの反映に失敗したら失敗と伝える', () async {
    billing.error = Exception('network');
    await notifier().buy(_product, plan: 'grade1');

    expect(state().outcome, PurchaseOutcome.failed);
  });

  test('キャンセルは結果を出さず、サーバーも呼ばない', () async {
    store.purchaseError = const PurchaseCancelledException();
    await notifier().buy(_product, plan: 'grade1');

    expect(billing.syncCount, 0);
    expect(state().busy, isFalse);
    expect(state().outcome, isNull);
  });

  test('承認待ちは承認待ちと伝える', () async {
    store.purchaseError = const PurchasePendingException();
    await notifier().buy(_product, plan: 'grade1');

    expect(state().outcome, PurchaseOutcome.pending);
  });

  test('Google Playの契約中は、そのプランからの変更にする', () async {
    store.active = (store: SubscriptionStore.playStore, productId: 'old:monthly');
    container = build(plan: 'grade1');
    await pumpEventQueue();

    await notifier().buy(_product, plan: 'grade2');
    expect(store.purchases.single.replacing, 'old:monthly');
    expect(store.purchases.single.upgrade, isTrue);
  });

  test('下位のプランへの変更はアップグレードにしない', () async {
    store.active = (store: SubscriptionStore.playStore, productId: 'old:monthly');
    container = build(plan: 'grade2');
    await pumpEventQueue();

    await notifier().buy(_product, plan: 'grade1');
    expect(store.purchases.single.upgrade, isFalse);
  });

  test('下位のプランへの変更は、反映ではなく予約と伝える', () async {
    store.active = (store: SubscriptionStore.appStore, productId: 'old');
    container = build(plan: 'grade2');
    await pumpEventQueue();

    await notifier().buy(_product, plan: 'grade1');
    expect(billing.syncCount, 1);
    expect(state().outcome, PurchaseOutcome.scheduled);
  });

  test('上位のプランへの変更は反映と伝える', () async {
    store.active = (store: SubscriptionStore.appStore, productId: 'old');
    container = build(plan: 'grade1');
    await pumpEventQueue();

    await notifier().buy(_product, plan: 'grade2');
    expect(state().outcome, PurchaseOutcome.applied);
  });

  test('契約中・予約済みの商品は失敗ではなくその旨を伝え、サーバーも呼ばない', () async {
    store.purchaseError = const PurchaseAlreadyOwnedException();
    await notifier().buy(_product, plan: 'grade1');

    expect(billing.syncCount, 0);
    expect(state().outcome, PurchaseOutcome.alreadyOwned);
  });

  group('引き継げる契約', () {
    Future<String?> read() {
      container.listen(transferablePlanProvider, (_, _) {});
      return container.read(transferablePlanProvider.future);
    }

    test('今の顧客に契約が無く、ストアにあればそのプラン', () async {
      store.storeProductIds = ['other', StoreProducts.productIdFor('grade1')];

      expect(await read(), 'grade1');
    });

    test('今の顧客に契約があれば無し', () async {
      store.storeProductIds = [StoreProducts.productIdFor('grade1')];
      store.active = (store: SubscriptionStore.appStore, productId: 'old');
      container = build();

      expect(await read(), isNull);
    });

    test('ストアに無ければ無し', () async {
      expect(await read(), isNull);
    });
  });

  test('予約中の変更：商品IDをプランに直す', () async {
    final startsAt = DateTime(2026, 11, 15);
    store.scheduled = (productId: StoreProducts.productIdFor('grade1'), startsAt: startsAt);
    container = build(plan: 'grade2');
    container.listen(scheduledPlanChangeProvider, (_, _) {});

    expect(await container.read(scheduledPlanChangeProvider.future), (plan: 'grade1', startsAt: startsAt));
  });

  test('予約中の変更：知らない商品は無視する', () async {
    store.scheduled = (productId: 'unknown', startsAt: DateTime(2026, 11, 15));
    container = build(plan: 'grade2');
    container.listen(scheduledPlanChangeProvider, (_, _) {});

    expect(await container.read(scheduledPlanChangeProvider.future), isNull);
  });

  test('App Storeの変更はストアに任せる', () async {
    store.active = (store: SubscriptionStore.appStore, productId: 'old');
    container = build(plan: 'grade1');
    await pumpEventQueue();

    await notifier().buy(_product, plan: 'grade2');
    expect(store.purchases.single.replacing, isNull);
  });

  test('復元：有効な購入があれば反映する', () async {
    await notifier().restore();

    expect(billing.syncCount, 1);
    expect(state().outcome, PurchaseOutcome.applied);
  });

  test('復元：無ければ「復元できる購入なし」', () async {
    store.restorable = false;
    await notifier().restore();

    expect(billing.syncCount, 0);
    expect(state().outcome, PurchaseOutcome.nothingToRestore);
  });
}
