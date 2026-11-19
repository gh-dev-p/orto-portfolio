import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/account/active_account_repository.dart';
import 'package:multi_id_msg/data/repositories/chat/chat_repository.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
import 'package:multi_id_msg/ui/account/widgets/account_creation_screen.dart';
import 'package:multi_id_msg/ui/account/widgets/account_list_screen.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/passcode/view_models/passcode_providers.dart';
import 'package:multi_id_msg/ui/profile/widgets/self_profile_screen.dart';

class _FakeActiveAccountRepository implements ActiveAccountRepository {
  String? saved;

  @override
  String? read() => saved;

  @override
  Future<void> save(String accountId) async => saved = accountId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatRepository implements ChatRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 指定したアカウントにだけ未読があるトーク一覧を返す
class _UnreadChatRepository extends _FakeChatRepository {
  _UnreadChatRepository(this.unreadAccountId);

  final String unreadAccountId;

  @override
  Future<List<ChatListEntry>> fetchChatList(String accountId) async => [
    if (accountId == unreadAccountId) const ChatListEntry(chatRoomId: 'room', peerAccountId: 'peer', unreadCount: 3),
  ];
}

/// AuthGateの代わり：アクティブアカウントが無ければACC-01、あればホームを表示する
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(activeAccountIdProvider) == null ? const AccountListScreen() : const Text('HOME');
  }
}

const _groupRequest = GroupRequest(chatRoomId: 'room', invitedBy: 'someone', name: 'group', memberCount: 2);

void main() {
  testWidgets('グループへの招待があるアカウントの行だけに「!」を出す', (tester) async {
    Account account(String id) =>
        Account(id: id, displayName: id);
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          activeAccountRepositoryProvider.overrideWithValue(_FakeActiveAccountRepository()),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
          accountsProvider.overrideWithValue(AsyncData([account('alice'), account('bob')])),
          accountLimitProvider.overrideWithValue(const AsyncData(null)),
          passcodeEnabledProvider.overrideWith((ref, accountId) => Stream.value(false)),
          groupRequestsForAccountProvider.overrideWith(
            (ref, accountId) => Stream.value(accountId == 'bob' ? const [_groupRequest] : const []),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccountListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('!'), findsOneWidget);
    expect(find.descendant(of: find.widgetWithText(Row, 'bob'), matching: find.text('!')), findsOneWidget);
  });

  testWidgets('ロック中のアカウントは、ひとことと招待を隠し、未読の件数は出す', (tester) async {
    Account account(String id) => Account(
      id: id,
      displayName: id,
      bio: 'bio of $id',
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          activeAccountRepositoryProvider.overrideWithValue(_FakeActiveAccountRepository()),
          chatRepositoryProvider.overrideWithValue(_UnreadChatRepository('bob')),
          accountsProvider.overrideWithValue(AsyncData([account('alice'), account('bob')])),
          accountLimitProvider.overrideWithValue(const AsyncData(null)),
          passcodeEnabledProvider.overrideWith((ref, accountId) => Stream.value(accountId == 'bob')),
          groupRequestsForAccountProvider.overrideWith((ref, accountId) => Stream.value(const [_groupRequest])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccountListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('bio of alice'), findsOneWidget);
    expect(find.text('bio of bob'), findsNothing);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('!'), findsOneWidget, reason: 'ロック中のbobの招待は出ない');
    expect(find.descendant(of: find.widgetWithText(Row, 'bob'), matching: find.text('3')), findsOneWidget);
  });

  /// [showAccountSwitcherDialog]を開くボタンだけの画面を表示し、ボタンをタップして開く
  Future<void> openSwitcher(WidgetTester tester, List<Account> accounts, {String? activeId}) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          activeAccountRepositoryProvider.overrideWithValue(_FakeActiveAccountRepository()..saved = activeId),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
          accountsProvider.overrideWithValue(AsyncData(accounts)),
          accountLimitProvider.overrideWithValue(const AsyncData(null)),
          passcodeEnabledProvider.overrideWith((ref, accountId) => Stream.value(false)),
          groupRequestsForAccountProvider.overrideWith((ref, accountId) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => showAccountSwitcherDialog(context), child: const Text('OPEN')),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  Account account(String id) =>
      Account(id: id, displayName: id);

  // Dialog自体は画面全体の大きさなので、カードの大きさはその中のMaterialで測る
  final card = find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first;

  testWidgets('アカウント切り替えは中央のカードで開き、外側のタップで閉じる', (tester) async {
    await openSwitcher(tester, [account('alice'), account('bob')]);

    final screenCenter = tester.getCenter(find.byType(Navigator));
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.getCenter(card), screenCenter);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('カードで「＋」を押すと作成画面へ進み、アカウントを選ぶとカードが閉じる', (tester) async {
    await openSwitcher(tester, [account('alice')]);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byType(AccountCreationScreen), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('alice'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
  });

  group('「プロフィール」ボタン', () {
    const button = Key('account-list-profile');

    testWidgets('カードでは使用中の行にだけ出す', (tester) async {
      await openSwitcher(tester, [account('alice'), account('bob')], activeId: 'bob');

      expect(find.byKey(button), findsOneWidget);
      expect(find.descendant(of: find.widgetWithText(Row, 'bob'), matching: find.byKey(button)), findsOneWidget);
      expect(find.descendant(of: find.widgetWithText(Row, 'alice'), matching: find.byKey(button)), findsNothing);
    });

    testWidgets('押すとカードを閉じて自分のプロフィールを開き、アカウントは切り替えない', (tester) async {
      await openSwitcher(tester, [account('alice'), account('bob')], activeId: 'bob');

      await tester.tap(find.byKey(button));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(SelfProfileScreen), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);
    });

    testWidgets('小さなピル型で文字が中央にあり、タップ領域は44を確保する', (tester) async {
      await openSwitcher(tester, [account('alice')], activeId: 'alice');

      final label = find.descendant(of: find.byKey(button), matching: find.text('Profile'));
      final pill = find.ancestor(of: label, matching: find.byType(Container)).first;

      expect(tester.getSize(find.byKey(button)).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(find.byKey(button)).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(pill).height, 28);
      expect(tester.getCenter(label), tester.getCenter(pill));
      expect(tester.getCenter(pill), tester.getCenter(find.byKey(button)));
    });

    testWidgets('全画面の表示では出さない', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            activeAccountRepositoryProvider.overrideWithValue(_FakeActiveAccountRepository()..saved = 'alice'),
            chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
            accountsProvider.overrideWithValue(AsyncData([account('alice')])),
            accountLimitProvider.overrideWithValue(const AsyncData(null)),
            passcodeEnabledProvider.overrideWith((ref, accountId) => Stream.value(false)),
            groupRequestsForAccountProvider.overrideWith((ref, accountId) => Stream.value(const [])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AccountListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget);
      expect(find.byKey(button), findsNothing);
    });

    testWidgets('長い表示名でも行が崩れない', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await openSwitcher(tester, [account('a' * 40)], activeId: 'a' * 40);

      expect(tester.takeException(), isNull);
      expect(find.byKey(button), findsOneWidget);
    });
  });

  testWidgets('カードの高さはアカウントの数に合わせる', (tester) async {
    await openSwitcher(tester, [account('alice')]);

    expect(tester.getSize(card).height, lessThan(tester.getSize(find.byType(Navigator)).height / 2));
  });

  group('カードの上下の余白', () {
    /// カードの上端から「＋」ボタンまでの余白
    double topGap(WidgetTester tester) => tester.getTopLeft(find.byIcon(Icons.add)).dy - tester.getTopLeft(card).dy;

    /// 名前が[name]の行の下端からカードの下端までの余白
    double bottomGap(WidgetTester tester, String name) {
      final row = find.ancestor(of: find.text(name), matching: find.byType(Material)).first;
      return tester.getBottomLeft(card).dy - tester.getBottomLeft(row).dy;
    }

    testWidgets('アカウントが少ないときは、最後の行の下を上端と同じ20空ける', (tester) async {
      await openSwitcher(tester, [account('alice'), account('bob')], activeId: 'bob');

      expect(topGap(tester), 20);
      expect(bottomGap(tester, 'bob'), 20);
    });

    testWidgets('使用中でない行が最後でも同じ余白になる', (tester) async {
      await openSwitcher(tester, [account('alice'), account('bob')], activeId: 'alice');

      expect(bottomGap(tester, 'bob'), 20);
    });

    testWidgets('スクロールするときは、最後までスクロールすると同じ余白になる', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await openSwitcher(tester, [for (var i = 0; i < 20; i++) account('account$i')]);
      await tester.dragUntilVisible(find.text('account19'), find.byType(ListView), const Offset(0, -200));
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(topGap(tester), 20);
      expect(bottomGap(tester, 'account19'), 20);
    });
  });

  testWidgets('小さい画面でアカウントが多くても、カードは画面に収まり中でスクロールする', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openSwitcher(tester, [for (var i = 0; i < 20; i++) account('account$i')]);

    final cardRect = tester.getRect(card);
    expect(cardRect.top, greaterThan(0));
    expect(cardRect.bottom, lessThan(480));
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('account19'), findsNothing);

    await tester.dragUntilVisible(find.text('account19'), find.byType(ListView), const Offset(0, -200));

    expect(find.text('account19'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
  });

  testWidgets('全画面のACC-01でアカウントを選んでも、画面のスタックを差し替えずゲートに切り替えを任せる', (tester) async {
    final account = Account(
      id: 'alice',
      displayName: 'Alice',
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          activeAccountRepositoryProvider.overrideWithValue(_FakeActiveAccountRepository()),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
          accountsProvider.overrideWithValue(AsyncData([account])),
          accountLimitProvider.overrideWithValue(const AsyncData(null)),
          passcodeEnabledProvider.overrideWith((ref, accountId) => Stream.value(false)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _Gate(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    // ゲート（最初の画面）が残ったままホームに切り替わる（ゲートが消えると、退会等のサインアウトで画面が切り替わらない）
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(_Gate), findsOneWidget);
    expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
  });
}
