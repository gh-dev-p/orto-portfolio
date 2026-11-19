import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/group/widgets/group_create_screen.dart';

Widget _app() => ProviderScope(
  child: MaterialApp(
    locale: const Locale('ja'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const GroupCreateScreen(myAccountId: 'me', selected: []),
  ),
);

void main() {
  testWidgets('グループ名の見出しは欄の外に固定で出し、フォーカスしても動かさない', (tester) async {
    await tester.pumpWidget(_app());

    final field = find.byType(TextField);
    final label = find.text('グループ名');
    final decoration = tester.widget<TextField>(field).decoration!;
    expect(decoration.labelText, isNull);
    expect(decoration.hintText, 'グループ名を入力');
    expect(tester.getBottomLeft(label).dy, lessThanOrEqualTo(tester.getTopLeft(field).dy));

    final before = tester.getTopLeft(label);
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(label), before);
  });

  testWidgets('文字数カウンタと画面読み上げ用のヒントは残す', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app());

    expect(find.text('0/50'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('グループ名を入力')), findsOneWidget);
    handle.dispose();
  });
}
