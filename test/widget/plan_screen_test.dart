import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/app_flavor.dart';
import 'package:multi_id_msg/config/legal_links.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/config/store_products.dart';
import 'package:multi_id_msg/data/repositories/billing/billing_repository.dart';
import 'package:multi_id_msg/data/services/billing/store_purchase_service.dart';
import 'package:multi_id_msg/domain/models/auth_user.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/auth/view_models/auth_providers.dart';
import 'package:multi_id_msg/ui/core/ui/app_primary_button.dart';
import 'package:multi_id_msg/ui/plan/widgets/plan_screen.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class _FakeStore implements StorePurchaseService {
  _FakeStore(this.active, this.scheduled, this.storeProductIds);

  final ActiveSubscription? active;
  final ScheduledSubscriptionChange? scheduled;
  final List<String> storeProductIds;
  int purchaseCount = 0;
  int restoreCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<void> start(String billingId) async {}

  @override
  Future<ActiveSubscription?> fetchActiveSubscription() async => active;

  @override
  Future<ScheduledSubscriptionChange?> fetchScheduledChange() async => scheduled;

  @override
  Future<List<String>> fetchStoreProductIds() async => storeProductIds;

  @override
  Future<void> purchase(StoreProduct product, {String? replacing, bool upgrade = false}) async => purchaseCount++;

  @override
  Future<bool> restore() async {
    restoreCount++;
    return false;
  }

  @override
  Future<List<StoreProduct>> fetchProducts(Set<String> productIds) async => [
    for (final id in productIds) StoreProduct(id, '', '', 0, id.contains('grade1') ? '¥280' : '¥650', 'JPY'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBilling implements BillingRepository {
  @override
  Future<String> getBillingId() async => 'billing-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccount implements Account {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeStore> _pump(
  WidgetTester tester, {
  required String plan,
  required int accountCount,
  bool kept = false,
  ActiveSubscription? active,
  ScheduledSubscriptionChange? scheduled,
  List<String> storeProductIds = const [],
  bool showLimitNotice = false,
}) async {
  final store = _FakeStore(active, scheduled, storeProductIds);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userPlanProvider.overrideWith((ref) => Stream.value(plan)),
        keptAccountsProvider.overrideWith((ref) => Stream.value((ids: const <String>[], chosen: kept))),
        accountsProvider.overrideWith((ref) => Stream.value([for (var i = 0; i < accountCount; i++) _FakeAccount()])),
        authStateChangesProvider.overrideWith((ref) => Stream.value(const AuthUser(uid: 'uid'))),
        storePurchaseServiceProvider.overrideWithValue(store),
        billingRepositoryProvider.overrideWithValue(_FakeBilling()),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlanScreen(showLimitNotice: showLimitNotice),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  setUpAll(() => currentFlavor = AppFlavor.dev);

  const upgradeNotice = 'アカウント数が上限に達しました。プランを変更すると増やせます。';
  const topPlanNotice = 'アカウント数が上限に達しました。これ以上は増やせません。';

  testWidgets('＋から開いて上限に達していれば、プランを変更すると増やせると案内する', (tester) async {
    await _pump(tester, plan: 'free', accountCount: 2, showLimitNotice: true);

    expect(find.text(upgradeNotice), findsOneWidget);
    expect(find.text(topPlanNotice), findsNothing);
  });

  testWidgets('一番上のプランなら、これ以上増やせないと案内する', (tester) async {
    await _pump(tester, plan: 'grade2', accountCount: 5, showLimitNotice: true);

    expect(find.text(topPlanNotice), findsOneWidget);
    expect(find.text(upgradeNotice), findsNothing);
  });

  testWidgets('上限内になれば、＋から開いても案内を出さない', (tester) async {
    await _pump(tester, plan: 'grade1', accountCount: 2, showLimitNotice: true);

    expect(find.text(upgradeNotice), findsNothing);
  });

  testWidgets('＋以外から開いたときは、上限に達していても案内を出さない', (tester) async {
    await _pump(tester, plan: 'free', accountCount: 2);

    expect(find.text(upgradeNotice), findsNothing);
  });

  testWidgets('増えるアカウント数とストアの価格を出し、人・単価の表記は出さない', (tester) async {
    await _pump(tester, plan: 'free', accountCount: 2);

    expect(find.text('＋1アカウント'), findsOneWidget);
    expect(find.text('＋3アカウント'), findsOneWidget);
    expect(find.text('¥280／月'), findsOneWidget);
    expect(find.text('¥650／月'), findsOneWidget);
    expect(find.textContaining('人'), findsNothing);
    expect(find.textContaining('あたり'), findsNothing);
    expect(find.text('購入する'), findsNWidgets(2));
  });

  testWidgets('今のプランは購入できず、もう一方は変更になる', (tester) async {
    await _pump(tester, plan: 'grade1', accountCount: 3);

    expect(find.text('利用中'), findsOneWidget);
    expect(find.text('このプランに変更'), findsOneWidget);
    expect(find.text('解約・プラン変更（Google Play）'), findsOneWidget);
  });

  group('ダウングレードの予約中', () {
    ScheduledSubscriptionChange scheduled() =>
        (productId: StoreProducts.productIdFor('grade1'), startsAt: DateTime(2026, 11, 15, 12));

    testWidgets('今のプランと変更予定を出し、予約中のプランは押せない', (tester) async {
      await _pump(tester, plan: 'grade2', accountCount: 3, scheduled: scheduled());

      expect(find.text('現在のプラン：グレード2（11月15日からグレード1）'), findsOneWidget);
      expect(find.text('利用中'), findsOneWidget);
      expect(find.text('このプランに変更'), findsNothing);
      final button = tester.widget<AppPrimaryButton>(find.widgetWithText(AppPrimaryButton, '変更予約済み'));
      expect(button.enabled, isFalse);
    });

    testWidgets('期間中は上限を超えず、読み取り専用の説明も出さない', (tester) async {
      await _pump(tester, plan: 'grade2', accountCount: 5, scheduled: scheduled());

      expect(find.text('アカウント 5 / 5'), findsOneWidget);
      expect(find.textContaining('読み取り専用です。'), findsNothing);
      expect(find.text('使い続けるアカウントを選ぶ'), findsNothing);
    });

    testWidgets('プランが下がると予約の表示は消え、上限を超えていれば選択へ案内する', (tester) async {
      await _pump(tester, plan: 'grade1', accountCount: 5, scheduled: scheduled());

      expect(find.text('現在のプラン：グレード1'), findsOneWidget);
      expect(find.text('変更予約済み'), findsNothing);
      expect(find.textContaining('読み取り専用です。'), findsOneWidget);
      expect(find.text('使い続けるアカウントを選ぶ'), findsOneWidget);
    });
  });

  group('ストアの契約の引き継ぎ', () {
    const notice = 'グレード1の契約があります。';

    testWidgets('紐付いていない契約があれば案内し、購入せず復元する', (tester) async {
      final store = await _pump(
        tester,
        plan: 'free',
        accountCount: 2,
        storeProductIds: [StoreProducts.productIdFor('grade1')],
      );

      expect(find.textContaining(notice), findsOneWidget);
      expect(find.text('購入する'), findsNothing);
      expect(find.text('契約を引き継ぐ'), findsNWidgets(2));
      expect(store.restoreCount, 0);

      await tester.tap(find.text('契約を引き継ぐ').first);
      await tester.pumpAndSettle();
      expect(store.restoreCount, 1);
      expect(store.purchaseCount, 0);
    });

    testWidgets('今のログインに紐付いていれば案内しない', (tester) async {
      await _pump(
        tester,
        plan: 'grade1',
        accountCount: 3,
        active: (store: SubscriptionStore.playStore, productId: 'product'),
        storeProductIds: [StoreProducts.productIdFor('grade1')],
      );

      expect(find.textContaining(notice), findsNothing);
      expect(find.text('契約を引き継ぐ'), findsNothing);
    });

    testWidgets('ストアに契約が無ければ、通常の購入になる', (tester) async {
      final store = await _pump(tester, plan: 'free', accountCount: 2);

      expect(find.textContaining(notice), findsNothing);
      await tester.tap(find.text('購入する').first);
      await tester.pumpAndSettle();
      expect(store.purchaseCount, 1);
      expect(store.restoreCount, 0);
    });
  });

  testWidgets('別のストアに有効な契約があれば購入ボタンを隠し、契約元のストアへ案内する', (tester) async {
    await _pump(
      tester,
      plan: 'grade1',
      accountCount: 3,
      active: (store: SubscriptionStore.appStore, productId: 'product'),
    );

    expect(find.text('このプランに変更'), findsNothing);
    expect(find.text('利用中'), findsNothing);
    expect(find.text('このプランはApp Storeで契約しています。変更・解約はApp Storeで行ってください。'), findsOneWidget);
    expect(find.text('解約・プラン変更（App Store）'), findsOneWidget);
  });

  testWidgets('特定商取引法に基づく表記へのリンクを出す', (tester) async {
    await _pump(tester, plan: 'free', accountCount: 2);

    await tester.scrollUntilVisible(find.text('特定商取引法に基づく表記'), 200);
    expect(find.text('特定商取引法に基づく表記'), findsOneWidget);
    expect(LegalLinks.tokushohoUrl('ja'), 'https://orto.example.com/legal/commerce');
    expect(LegalLinks.tokushohoUrl('en'), 'https://orto.example.com/en/legal/commerce');
  });

  testWidgets('上限を超えていれば読み取り専用の説明を出す', (tester) async {
    await _pump(tester, plan: 'free', accountCount: 3);

    expect(find.textContaining('読み取り専用です。'), findsOneWidget);
    expect(find.text('使い続けるアカウントを選ぶ'), findsOneWidget);
  });

  testWidgets('選び終えていれば選ぶボタンを出さない', (tester) async {
    await _pump(tester, plan: 'free', accountCount: 3, kept: true);

    expect(find.textContaining('読み取り専用です。'), findsOneWidget);
    expect(find.text('使い続けるアカウントを選ぶ'), findsNothing);
  });
}
