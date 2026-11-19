// 最初のアカウント作成後の、引き継ぎパスワードの案内（機能仕様書4.1.4.1）
// AccountRepository・AuthRepositoryはFirebaseに接続するため、必要な部分だけを持つ偽物を使う。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/account/account_repository.dart';
import 'package:multi_id_msg/data/repositories/auth/auth_repository.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/widgets/account_creation_screen.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/group/view_models/group_invite_providers.dart';
import 'package:multi_id_msg/ui/settings/view_models/transfer_password_prompt_provider.dart';
import 'package:multi_id_msg/ui/settings/widgets/transfer_password_prompt.dart';
import 'package:multi_id_msg/ui/settings/widgets/transfer_password_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends Fake implements AuthRepository {
  _FakeAuthRepository({this.registered = false, this.statusFails = false});

  final bool registered;
  final bool statusFails;

  @override
  AuthUser? get currentUser => const AuthUser(uid: 'uid-1', phoneNumber: '+819012345678');

  @override
  Future<TransferPasswordStatus> transferPasswordStatus({bool forceRefresh = false}) async {
    if (statusFails) throw Exception('network');
    return TransferPasswordStatus(registered: registered, sessionVerified: true);
  }
}

class _FakeAccountRepository extends Fake implements AccountRepository {
  @override
  Future<Account> createAccount({
    required String accountId,
    required String uid,
    required String displayName,
    String? phoneNumber,
    String? bio,
    String? photoURL,
  }) async => Account(id: accountId, displayName: displayName);
}

const _title = '引き継ぎパスワードを設定しませんか';

void main() {
  /// 案内のリスナーで包んだACC-02を表示する（作成後もACC-02が残るため、ホームの代わりになる）
  Future<ProviderContainer> pumpCreation(
    WidgetTester tester, {
    List<Account> accounts = const [],
    _FakeAuthRepository? auth,
    Map<String, Object> preferences = const {},
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    final sharedPreferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authRepositoryProvider.overrideWithValue(auth ?? _FakeAuthRepository()),
          accountRepositoryProvider.overrideWithValue(_FakeAccountRepository()),
          accountsProvider.overrideWith((ref) => Stream.value(accounts)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TransferPasswordPromptListener(child: AccountCreationScreen()),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(AccountCreationScreen)));
  }

  /// アカウントを作成する
  Future<void> create(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'たろう');
    await tester.enterText(find.byType(TextField).at(1), 'taro_01');
    await tester.pump();
    final button = find.text('作成する');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('未設定で最初のアカウントを作成すると、案内を出す', (tester) async {
    await pumpCreation(tester);
    await create(tester);

    expect(find.text(_title), findsOneWidget);
    expect(find.text('設定する'), findsOneWidget);
    expect(find.text('あとで設定する'), findsOneWidget);
  });

  testWidgets('「設定する」でSET-05を開く', (tester) async {
    await pumpCreation(tester);
    await create(tester);

    await tester.tap(find.text('設定する'));
    await tester.pumpAndSettle();

    expect(find.byType(TransferPasswordSetupScreen), findsOneWidget);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('「あとで設定する」で閉じ、次に判定しても出さない', (tester) async {
    final container = await pumpCreation(tester);
    await create(tester);

    await tester.tap(find.text('あとで設定する'));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(find.byType(TransferPasswordSetupScreen), findsNothing);

    await container.read(transferPasswordPromptProvider.notifier).offer();
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);
  });

  testWidgets('案内を出したことがあれば出さない（再起動の後）', (tester) async {
    await pumpCreation(tester, preferences: {'transferPasswordPromptShown.uid-1': true});
    await create(tester);

    expect(find.text(_title), findsNothing);
  });

  testWidgets('別のuidの記録があっても、案内を出す', (tester) async {
    await pumpCreation(tester, preferences: {'transferPasswordPromptShown.uid-2': true});
    await create(tester);

    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('設定済みなら出さない', (tester) async {
    await pumpCreation(tester, auth: _FakeAuthRepository(registered: true));
    await create(tester);

    expect(find.text(_title), findsNothing);
  });

  testWidgets('設定の有無を確認できなければ出さない', (tester) async {
    await pumpCreation(tester, auth: _FakeAuthRepository(statusFails: true));
    await create(tester);

    expect(find.text(_title), findsNothing);
  });

  testWidgets('2つ目以降のアカウントの作成では出さない', (tester) async {
    await pumpCreation(tester, accounts: const [Account(id: 'alice', displayName: 'alice')]);
    await create(tester);

    expect(find.text(_title), findsNothing);
  });

  group('招待から来た人は、次の起動で出す', () {
    const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJ0123_-x';

    testWidgets('グループの招待から来て最初のアカウントを作成しても、この起動では出さない', (tester) async {
      final container = await pumpCreation(tester);
      container.read(pendingGroupInviteProvider.notifier).set(token);
      await create(tester);

      expect(find.text(_title), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('transferPasswordPromptDeferred.uid-1'), isTrue);

      // 同じ起動の間は、先送りした分を出さない
      await container.read(transferPasswordPromptProvider.notifier).offerIfDeferred();
      await tester.pumpAndSettle();
      expect(find.text(_title), findsNothing);
    });

    testWidgets('招待してくれた人のIDを入れて作成しても、この起動では出さない', (tester) async {
      await pumpCreation(tester);
      await tester.enterText(find.byType(TextField).at(2), 'inviter');
      await create(tester);

      expect(find.text(_title), findsNothing);
    });

    testWidgets('次の起動でホームが作られたら出し、予定を消す', (tester) async {
      await pumpCreation(
        tester,
        accounts: const [Account(id: 'taro_01', displayName: 'たろう')],
        preferences: {'transferPasswordPromptDeferred.uid-1': true},
      );
      await tester.pumpAndSettle();

      expect(find.text(_title), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('transferPasswordPromptDeferred.uid-1'), isNull);
      expect(preferences.getBool('transferPasswordPromptShown.uid-1'), isTrue);
    });

    testWidgets('次の起動でも、設定済みなら出さない', (tester) async {
      await pumpCreation(
        tester,
        auth: _FakeAuthRepository(registered: true),
        accounts: const [Account(id: 'taro_01', displayName: 'たろう')],
        preferences: {'transferPasswordPromptDeferred.uid-1': true},
      );
      await tester.pumpAndSettle();

      expect(find.text(_title), findsNothing);
    });
  });
}
