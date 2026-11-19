import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/services/passcode/passcode_store.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/view_models/invite_account_choice_provider.dart';
import 'package:multi_id_msg/ui/account/widgets/invite_account_sheet.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/friend/widgets/invite_share.dart';

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

Account _account(String id, String name) => Account(id: id, displayName: name);

/// シートを開くための土台。開いた後の戻り値を持つ
class _Harness {
  String? result;
  bool closed = false;
  late BuildContext context;

  Widget app() => ProviderScope(
    overrides: [
      passcodeStoreProvider.overrideWithValue(PasscodeStore(_MemoryStorage())),
      accountsProvider.overrideWith((ref) => Stream.value([_account('daily.me', '普段の私')])),
    ],
    child: MaterialApp(
      locale: const Locale('ja'),
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          this.context = context;
          return const Scaffold();
        },
      ),
    ),
  );

  Future<void> openAccountSheet(WidgetTester tester, {required bool forGroup}) async {
    showInviteAccountSheet(
      context,
      ask: InviteAccountAsk(
        accounts: [_account('daily.me', '普段の私'), _account('event.me', 'イベントの私'), _account('old.me', '前の私')],
        readOnlyIds: const {'old.me'},
        initialAccountId: 'daily.me',
      ),
      forGroup: forGroup,
    ).then((value) {
      result = value;
      closed = true;
    });
    await tester.pumpAndSettle();
  }
}

void main() {
  group('外部から届いた招待で使うアカウントを選ぶシート', () {
    testWidgets('自分のアカウントを、表示名とIDで並べ、使用中の印と説明を出す', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app());
      await harness.openAccountSheet(tester, forGroup: false);

      expect(find.text('どのアカウントで友だち追加しますか？'), findsOneWidget);
      expect(find.text('相手には、選んだアカウントだけが見えます'), findsOneWidget);
      expect(find.text('普段の私'), findsOneWidget);
      expect(find.text('ID：daily.me'), findsOneWidget);
      expect(find.text('イベントの私'), findsOneWidget);
      expect(find.text('ID：event.me'), findsOneWidget);
      expect(find.text('使用中'), findsOneWidget);
    });

    testWidgets('グループのときは、参加の見出しにする', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app());
      await harness.openAccountSheet(tester, forGroup: true);

      expect(find.text('どのアカウントで参加しますか？'), findsOneWidget);
    });

    testWidgets('タップしたアカウントのIDを返して閉じる', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app());
      await harness.openAccountSheet(tester, forGroup: false);

      await tester.tap(find.byKey(const Key('invite-account-event.me')));
      await tester.pumpAndSettle();
      expect(harness.closed, isTrue);
      expect(harness.result, 'event.me');
    });

    testWidgets('読み取り専用のアカウントは理由を出し、タップしても選べない', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app());
      await harness.openAccountSheet(tester, forGroup: false);

      expect(find.text('読み取り専用のため選べません'), findsOneWidget);
      expect(find.text('ID：old.me'), findsNothing);
      await tester.tap(find.byKey(const Key('invite-account-old.me')));
      await tester.pumpAndSettle();
      expect(harness.closed, isFalse);
    });

    testWidgets('キャンセルではnullを返す（招待は開かない）', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app());
      await harness.openAccountSheet(tester, forGroup: true);

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(harness.closed, isTrue);
      expect(harness.result, isNull);
    });
  });

  group('FRI-03：招待に使うアカウントを見せてから送る', () {
    testWidgets('使用中のアカウントの表示名とIDを出し、「招待文を送る」で送る', (tester) async {
      final harness = _Harness();
      var sent = 0;
      await tester.pumpWidget(harness.app());
      showModalBottomSheet<void>(
        context: harness.context,
        isScrollControlled: true,
        builder: (_) => InviteShareSheet(myAccountId: 'daily.me', onSend: () => sent++),
      );
      await tester.pumpAndSettle();

      expect(find.text('このアカウントで招待します'), findsOneWidget);
      expect(find.text('普段の私'), findsOneWidget);
      expect(find.text('ID：daily.me'), findsOneWidget);

      await tester.tap(find.text('招待文を送る'));
      await tester.pump();
      expect(sent, 1);
    });
  });
}
