import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/core/ui/app_home_header.dart';
import 'package:multi_id_msg/ui/core/ui/count_badge.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';

Widget _header({
  required VoidCallback onTapAvatar,
  int otherAccountsUnread = 0,
  bool otherAccountsHaveGroupRequest = false,
  String? avatarDisplayName,
  Locale locale = const Locale('ja'),
}) => MaterialApp(
  theme: AppTheme.light,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: AppHomeHeader(
      title: 'トーク',
      avatarDisplayName: avatarDisplayName,
      avatarPhotoURL: null,
      otherAccountsUnread: otherAccountsUnread,
      otherAccountsHaveGroupRequest: otherAccountsHaveGroupRequest,
      onAdd: null,
      onInvite: null,
      onCreateGroup: null,
      onTapQr: () {},
      onTapAvatar: onTapAvatar,
    ),
  ),
);

void main() {
  testWidgets('アクティブなAccountが無く、アバターが空欄でも、その位置のタップでアカウント一覧を開く（画面設計書5.8.1.3）', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(_header(onTapAvatar: () => tapped++));

    // ＋・QRの右隣（行の右端）にある空欄のアバターの位置をタップする。
    final qr = tester.getCenter(find.byIcon(Icons.qr_code_2_outlined));
    await tester.tapAt(qr + const Offset(28 + 12, 0));

    expect(tapped, 1);
  });

  group('＋メニューの項目', () {
    Future<void> expectLabels(WidgetTester tester, Locale locale, List<String> labels) async {
      await tester.pumpWidget(_header(onTapAvatar: () {}, locale: locale));
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      final lefts = [for (final label in labels) tester.getTopLeft(find.text(label)).dx];
      expect(lefts, orderedEquals([...lefts]..sort()));
    }

    testWidgets('日本語は友だち追加・グループ作成・招待の順に並び、2行で表示する', (tester) async {
      await expectLabels(tester, const Locale('ja'), ['友だち\n追加', 'グループ\n作成', '招待']);
    });

    testWidgets('英語も同じ順に並び、2行で表示する', (tester) async {
      await expectLabels(tester, const Locale('en'), ['Add\nFriend', 'Create\nGroup', 'Invite']);
    });
  });

  group('アバターのバッジ', () {
    Future<void> pumpBadge(WidgetTester tester, {required int unread, required bool hasGroupRequest}) {
      return tester.pumpWidget(
        _header(
          onTapAvatar: () {},
          avatarDisplayName: 'Alice',
          otherAccountsUnread: unread,
          otherAccountsHaveGroupRequest: hasGroupRequest,
        ),
      );
    }

    testWidgets('未読だけなら件数を出す', (tester) async {
      await pumpBadge(tester, unread: 3, hasGroupRequest: false);

      expect(find.text('3'), findsOneWidget);
      expect(find.text('!'), findsNothing);
    });

    testWidgets('招待だけなら「!」を出す', (tester) async {
      await pumpBadge(tester, unread: 0, hasGroupRequest: true);

      expect(find.text('!'), findsOneWidget);
    });

    testWidgets('未読と招待が重なると「!」だけを出し、招待が無くなると未読数に戻る', (tester) async {
      await pumpBadge(tester, unread: 3, hasGroupRequest: true);

      expect(find.text('!'), findsOneWidget);
      expect(find.text('3'), findsNothing);

      await pumpBadge(tester, unread: 3, hasGroupRequest: false);

      expect(find.text('!'), findsNothing);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('どちらも無ければ出さない', (tester) async {
      await pumpBadge(tester, unread: 0, hasGroupRequest: false);

      expect(find.byType(CountBadge), findsNothing);
    });
  });
}
