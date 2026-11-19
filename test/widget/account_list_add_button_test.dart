import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/app_flavor.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/account/active_account_repository.dart';
import 'package:multi_id_msg/data/repositories/billing/billing_repository.dart';
import 'package:multi_id_msg/data/repositories/chat/chat_repository.dart';
import 'package:multi_id_msg/data/services/billing/store_purchase_service.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/models/auth_user.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/widgets/account_creation_screen.dart';
import 'package:multi_id_msg/ui/account/widgets/account_list_screen.dart';
import 'package:multi_id_msg/ui/auth/view_models/auth_providers.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/passcode/view_models/passcode_providers.dart';
import 'package:multi_id_msg/ui/plan/widgets/plan_screen.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class _FakeActiveAccountRepository implements ActiveAccountRepository {
  @override
  String? read() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatRepository implements ChatRepository {
  @override
  Future<List<ChatListEntry>> fetchChatList(String accountId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStore implements StorePurchaseService {
  @override
  bool get isAvailable => true;

  @override
  Future<void> start(String billingId) async {}

  @override
  Future<ActiveSubscription?> fetchActiveSubscription() async => null;

  @override
  Future<List<StoreProduct>> fetchProducts(Set<String> productIds) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBilling implements BillingRepository {
  @override
  Future<String> getBillingId() async => 'billing-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// ACC-01を出し、「＋」をタップする
Future<void> _tapAddButton(WidgetTester tester, {required int accountCount, required int limit}) async {
  final accounts = [
    for (var i = 0; i < accountCount; i++)
      Account(
        id: 'account$i',
        displayName: 'Account $i',
      ),
  ];
  await tester.pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      overrides: [
        activeAccountRepositoryProvider.overrideWithValue(_FakeActiveAccountRepository()),
        chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
        accountsProvider.overrideWithValue(AsyncData(accounts)),
        accountLimitProvider.overrideWithValue(AsyncData(limit)),
        passcodeEnabledProvider.overrideWith((ref, accountId) => Stream.value(false)),
        userPlanProvider.overrideWith((ref) => Stream.value('free')),
        keptAccountsProvider.overrideWith((ref) => Stream.value((ids: const <String>[], chosen: false))),
        authStateChangesProvider.overrideWith((ref) => Stream.value(const AuthUser(uid: 'uid'))),
        storePurchaseServiceProvider.overrideWithValue(_FakeStore()),
        billingRepositoryProvider.overrideWithValue(_FakeBilling()),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => currentFlavor = AppFlavor.dev);

  testWidgets('上限に達していれば、ダイアログを出さず上限の案内つきでプラン画面を開く', (tester) async {
    await _tapAddButton(tester, accountCount: 2, limit: 2);

    expect(find.byType(PlanScreen), findsOneWidget);
    expect(find.text('アカウント数が上限に達しました。プランを変更すると増やせます。'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AccountCreationScreen), findsNothing);
  });

  testWidgets('上限内なら作成画面を開く', (tester) async {
    await _tapAddButton(tester, accountCount: 1, limit: 2);

    expect(find.byType(AccountCreationScreen), findsOneWidget);
    expect(find.byType(PlanScreen), findsNothing);
  });
}
