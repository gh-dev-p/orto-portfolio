import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/widgets/account_creation_screen.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences _preferences;

Account _account(String id) => Account(
  id: id,
  displayName: id,
);

/// [accounts]を流すアカウントの一覧で、ACC-02を[locale]で表示する
Future<void> _pumpScreen(WidgetTester tester, Stream<List<Account>> accounts, {Locale locale = const Locale('ja')}) {
  return tester.pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      overrides: [
        accountsProvider.overrideWith((ref) => accounts),
        sharedPreferencesProvider.overrideWithValue(_preferences),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountCreationScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _preferences = await SharedPreferences.getInstance();
  });

  testWidgets('アカウントが0件なら「1つ目」と表示する', (tester) async {
    await _pumpScreen(tester, Stream.value(const []));
    await tester.pump();

    expect(find.text('1つ目のアカウントを作成'), findsOneWidget);
  });

  testWidgets('アカウントがあれば、その件数＋1を表示する', (tester) async {
    await _pumpScreen(tester, Stream.value([_account('alice')]));
    await tester.pump();

    expect(find.text('2つ目のアカウントを作成'), findsOneWidget);
  });

  testWidgets('一覧の読み込み前は番号を出さず、読み込めたら番号を出す', (tester) async {
    final accounts = StreamController<List<Account>>();
    addTearDown(accounts.close);
    await _pumpScreen(tester, accounts.stream);

    expect(find.text('アカウント作成'), findsOneWidget);

    accounts.add(const []);
    await tester.pump();

    expect(find.text('1つ目のアカウントを作成'), findsOneWidget);
  });

  testWidgets('作成で一覧が増えても、番号は変わらない', (tester) async {
    final accounts = StreamController<List<Account>>();
    addTearDown(accounts.close);
    await _pumpScreen(tester, accounts.stream);

    accounts.add([_account('alice')]);
    await tester.pump();
    accounts.add([_account('alice'), _account('bob')]);
    await tester.pump();

    expect(find.text('2つ目のアカウントを作成'), findsOneWidget);
  });

  testWidgets('英語は序数で表示する', (tester) async {
    for (final (count, title) in [
      (0, 'Create your 1st account'),
      (1, 'Create your 2nd account'),
      (2, 'Create your 3rd account'),
      (3, 'Create your 4th account'),
    ]) {
      await _pumpScreen(
        tester,
        Stream.value([for (var i = 0; i < count; i++) _account('a$i')]),
        locale: const Locale('en'),
      );
      await tester.pump();

      expect(find.text(title), findsOneWidget);

      // ProviderScopeを作り直すため、いったん画面を外す
      await tester.pumpWidget(const SizedBox());
    }
  });

  group('招待してくれた人のIDの入力欄（機能仕様書4.3.5.2）', () {
    testWidgets('1つ目のアカウントの作成では出す', (tester) async {
      await _pumpScreen(tester, Stream.value(const []));
      await tester.pump();
      expect(find.text('招待してくれた人のアカウントID（任意）'), findsOneWidget);
    });

    testWidgets('2つ目以降では出さない', (tester) async {
      await _pumpScreen(tester, Stream.value([_account('alice')]));
      await tester.pump();
      expect(find.text('招待してくれた人のアカウントID（任意）'), findsNothing);
    });

    testWidgets('招待リンクで受け取った招待があれば出さない', (tester) async {
      await _preferences.setString('pendingInviteAccountId', 'friend');
      await _pumpScreen(tester, Stream.value(const []));
      await tester.pump();
      expect(find.text('招待してくれた人のアカウントID（任意）'), findsNothing);
    });
  });
}
