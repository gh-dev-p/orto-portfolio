import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/account/account_repository.dart';
import 'package:multi_id_msg/data/services/passcode/passcode_store.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/widgets/account_deletion_screen.dart';
import 'package:multi_id_msg/ui/core/ui/app_primary_button.dart';
import 'package:multi_id_msg/ui/passcode/view_models/passcode_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStorage implements PasscodeStorage {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

class _FakeAccountRepository implements AccountRepository {
  final deleted = <String>[];

  @override
  Future<void> softDeleteAccount(String accountId) async => deleted.add(accountId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _account = Account(id: 'a', displayName: 'A');

void main() {
  late _FakeAccountRepository accounts;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {required bool passcode}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _MemoryStorage();
    if (passcode) await PasscodeStore(storage).save('a', '1234');
    accounts = _FakeAccountRepository();
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        accountRepositoryProvider.overrideWithValue(accounts),
        passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
        accountsProvider.overrideWithValue(AsyncData([_account])),
        accountByIdProvider.overrideWith((ref, accountId) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountDeletionScreen(account: _account),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapDelete(WidgetTester tester) async {
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.byKey(Key('passcode-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('パスコードが無ければ、確認なしで削除する', (tester) async {
    await pump(tester, passcode: false);
    await tapDelete(tester);
    expect(accounts.deleted, ['a']);
  });

  testWidgets('ロック中のアカウントは、パスコードを入力できるまで削除しない', (tester) async {
    await pump(tester, passcode: true);
    await tapDelete(tester);
    expect(accounts.deleted, isEmpty);
    expect(find.text('現在のパスコードを入力'), findsOneWidget);

    await enter(tester, '0000');
    expect(accounts.deleted, isEmpty);

    await enter(tester, '1234');
    expect(accounts.deleted, ['a']);
  });

  testWidgets('解除済みのアカウントは、もう一度は求めない', (tester) async {
    await pump(tester, passcode: true);
    container.read(unlockedAccountIdProvider.notifier).unlock('a');
    await tapDelete(tester);
    expect(accounts.deleted, ['a']);
  });
}
