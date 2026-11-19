import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/core/ui/app_bottom_nav.dart';
import 'package:multi_id_msg/ui/core/ui/count_badge.dart';
import 'package:multi_id_msg/ui/core/ui/unread_badge.dart';
import 'package:multi_id_msg/ui/group/widgets/group_request_section.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('ja'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  for (final (name, build) in <(String, Widget Function(int, bool))>[
    ('CountBadge', (count, attention) => CountBadge(count: count, attention: attention)),
    ('UnreadCountBadge', (count, attention) => UnreadCountBadge(count: count, attention: attention)),
  ]) {
    group(name, () {
      testWidgets('未読だけなら件数を出す', (tester) async {
        await tester.pumpWidget(_app(build(12, false)));

        expect(find.text('12'), findsOneWidget);
        expect(find.text('!'), findsNothing);
      });

      testWidgets('「!」だけでも出る', (tester) async {
        await tester.pumpWidget(_app(build(0, true)));

        expect(find.text('!'), findsOneWidget);
      });

      testWidgets('重なると「!」だけを出す', (tester) async {
        await tester.pumpWidget(_app(build(12, true)));

        expect(find.text('!'), findsOneWidget);
        expect(find.text('12'), findsNothing);
      });

      testWidgets('どちらも無ければ何も出さない', (tester) async {
        await tester.pumpWidget(_app(build(0, false)));

        expect(find.byType(Text), findsNothing);
      });
    });
  }

  testWidgets('「グループへの招待」のセクションには「!」を出す', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: _app(const GroupRequestSection(requests: [], myAccountId: 'alice')),
      ),
    );

    expect(find.text('!'), findsOneWidget);
  });

  group('ボトムナビの「トーク」タブ', () {
    Widget nav({required int unread, required bool hasGroupRequest}) => _app(
      AppBottomNav(currentIndex: 0, chatUnreadCount: unread, chatHasGroupRequest: hasGroupRequest, onTap: (_) {}),
    );

    testWidgets('招待だけなら「!」を出す', (tester) async {
      await tester.pumpWidget(nav(unread: 0, hasGroupRequest: true));

      expect(find.text('!'), findsOneWidget);
    });

    testWidgets('未読と重なると「!」だけを出し、招待が無くなると未読数に戻る', (tester) async {
      await tester.pumpWidget(nav(unread: 5, hasGroupRequest: true));

      expect(find.text('!'), findsOneWidget);
      expect(find.text('5'), findsNothing);

      await tester.pumpWidget(nav(unread: 5, hasGroupRequest: false));

      expect(find.text('!'), findsNothing);
      expect(find.text('5'), findsOneWidget);
    });
  });
}
