import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/chat/widgets/pinned_memo_bar.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/profile/widgets/friend_memo_tile.dart';

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('ja'),
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

void main() {
  testWidgets('メモが無いときは追加の案内だけで、ピン留めのチップは出さない（機能仕様書4.3.7）', (tester) async {
    var edited = 0;
    await tester.pumpWidget(
      _app(FriendMemoTile(memo: null, pinned: false, onEdit: () => edited++, onTogglePin: () {})),
    );

    expect(find.text('トークにピン留め'), findsNothing);
    expect(find.text('自分だけに表示されます'), findsNothing);
    await tester.tap(find.text('メモを追加'));
    expect(edited, 1);
  });

  testWidgets('本文のタップで編集し、チップのタップでピン留めを切り替える（機能仕様書4.3.7）', (tester) async {
    var toggled = 0;
    var edited = 0;
    await tester.pumpWidget(
      _app(FriendMemoTile(memo: '誕生日は5月', pinned: false, onEdit: () => edited++, onTogglePin: () => toggled++)),
    );

    expect(find.text('自分だけに表示されます'), findsOneWidget);
    await tester.tap(find.text('トークにピン留め'));
    expect((toggled, edited), (1, 0));
    await tester.tap(find.text('誕生日は5月'));
    expect((toggled, edited), (1, 1));
  });

  testWidgets('チップは状態に応じた文言になり、スイッチは使わない（機能仕様書4.3.7）', (tester) async {
    await tester.pumpWidget(_app(FriendMemoTile(memo: '誕生日は5月', pinned: true, onEdit: () {}, onTogglePin: () {})));
    expect(find.text('ピン留め中'), findsOneWidget);
    expect(find.text('トークにピン留め'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('補助文字は文字を大きくしても途中で切らず、2行に折り返す', (tester) async {
    await tester.pumpWidget(
      _app(
        MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.3,
          maxScaleFactor: 1.3,
          child: FriendMemoTile(memo: '誕生日は5月', pinned: false, onEdit: () {}, onTogglePin: () {}),
        ),
      ),
    );

    final label = tester.renderObject<RenderParagraph>(find.text('自分だけに表示されます'));
    expect(label.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('チップのタップ領域は44pt以上で、読み上げのラベルと状態を持つ', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(FriendMemoTile(memo: '誕生日は5月', pinned: true, onEdit: () {}, onTogglePin: () {})));

    final chip = find.bySemanticsLabel('トークにピン留め');
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(44));
    expect(
      tester.getSemantics(chip),
      matchesSemantics(label: 'トークにピン留め', isButton: true, hasToggledState: true, isToggled: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('メモのカードは、ラベルと本文をガラスの面に出す', (tester) async {
    await tester.pumpWidget(_app(FriendMemoTile(memo: '誕生日は5月', pinned: false, onEdit: () {}, onTogglePin: () {})));

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('メモ'), findsOneWidget);
    expect(tester.getTopLeft(find.text('メモ')).dy, lessThan(tester.getTopLeft(find.text('誕生日は5月')).dy));
  });

  testWidgets('メモが無いときの案内も、ガラスの面に出す', (tester) async {
    await tester.pumpWidget(_app(FriendMemoTile(memo: null, pinned: false, onEdit: () {}, onTogglePin: () {})));

    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('写真の上に置くため、ダークテーマでも文字の色は変わらない', (tester) async {
    Future<Color?> textColor(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FriendMemoTile(memo: '誕生日は5月', pinned: false, onEdit: () {}, onTogglePin: () {}),
          ),
        ),
      );
      return tester.widget<Text>(find.text('誕生日は5月')).style?.color;
    }

    expect(await textColor(AppTheme.dark), await textColor(AppTheme.light));
  });

  testWidgets('ピン留めしたメモをタップすると通知する（機能仕様書4.3.7）', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_app(PinnedMemoBar(memo: '誕生日は5月', onTap: () => tapped++)));

    await tester.tap(find.text('誕生日は5月'));
    expect(tapped, 1);
  });
}
