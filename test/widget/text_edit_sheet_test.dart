import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_colors.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/core/ui/text_edit_sheet.dart';

/// シートの戻り値。[_Harness.opened]で開いた後に読む
class _Harness {
  String? result;
  bool closed = false;
  late BuildContext context;

  Widget app({ThemeData? theme}) => MaterialApp(
    locale: const Locale('ja'),
    theme: theme ?? AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        this.context = context;
        return const Scaffold();
      },
    ),
  );

  Future<void> open(
    WidgetTester tester, {
    String initialValue = '',
    int minLength = 0,
    int maxLength = 20,
    int maxLines = 1,
  }) async {
    showTextEditSheet(
      context,
      title: 'メモ',
      initialValue: initialValue,
      minLength: minLength,
      maxLength: maxLength,
      hintText: 'ヒント',
      maxLines: maxLines,
    ).then((value) {
      result = value;
      closed = true;
    });
    await tester.pumpAndSettle();
  }
}

CupertinoButton _saveButton(WidgetTester tester) =>
    tester.widget(find.ancestor(of: find.text('保存'), matching: find.byType(CupertinoButton)));

void main() {
  testWidgets('iOSの部品で、キャンセル・タイトル・保存とプレースホルダ・文字数を出す', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await harness.open(tester);

    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('キャンセル'), findsOneWidget);
    expect(find.text('メモ'), findsOneWidget);
    expect(find.text('ヒント'), findsOneWidget);
    expect(find.text('0/20'), findsOneWidget);
  });

  testWidgets('空のまま、または変更が無いときは保存できない', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await harness.open(tester);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(CupertinoTextField), '   ');
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(CupertinoTextField), '誕生日');
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);
    expect(find.text('3/20'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), '');
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('必須の項目は、空にしても保存できない', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await harness.open(tester, initialValue: '花子', minLength: 1);

    await tester.enterText(find.byType(CupertinoTextField), '');
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('任意の項目は、値を消して保存できる（機能仕様書4.3.7）', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await harness.open(tester, initialValue: '誕生日は5月');

    await tester.enterText(find.byType(CupertinoTextField), '');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(harness.result, '');
  });

  testWidgets('保存すると前後の空白を除いた文字列を返す', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await harness.open(tester);

    await tester.enterText(find.byType(CupertinoTextField), '  誕生日  ');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(harness.result, '誕生日');
  });

  testWidgets('キャンセルするとnullを返す', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await harness.open(tester, initialValue: '誕生日');

    await tester.enterText(find.byType(CupertinoTextField), '変更');
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(harness.closed, isTrue);
    expect(harness.result, isNull);
  });

  testWidgets('1行の欄には全消去ボタンを出し、文章の欄は指定の行数の高さにする', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await harness.open(tester);
    expect(
      tester.widget<CupertinoTextField>(find.byType(CupertinoTextField)).clearButtonMode,
      OverlayVisibilityMode.editing,
    );
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    await harness.open(tester, maxLines: 5);
    final field = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
    expect(field.clearButtonMode, OverlayVisibilityMode.never);
    expect(field.minLines, 5);
    expect(field.maxLines, 5);
  });

  testWidgets('キーボードが出ていても、保存ボタンと入力欄が隠れない', (tester) async {
    addTearDown(tester.view.reset);
    // 小さい画面（iPhone SE相当）で、キーボードが画面の4割を占める
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);

    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await harness.open(tester, maxLength: 500, maxLines: 5);

    const keyboardTop = 667.0 - 260;
    expect(tester.getBottomRight(find.text('保存')).dy, lessThan(keyboardTop));
    expect(tester.getBottomRight(find.byType(CupertinoTextField)).dy, lessThan(keyboardTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('入力欄が収まらない高さでも、溢れず保存ボタンが見える', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);

    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await harness.open(tester, maxLength: 500, maxLines: 5);

    expect(tester.takeException(), isNull);
    expect(tester.getBottomRight(find.text('保存')).dy, lessThan(375 - 220));
  });

  testWidgets('ダークテーマでは、ダークの色で入力欄を描く', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app(theme: AppTheme.dark));
    await harness.open(tester);

    final field = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
    expect(field.decoration?.color, AppColors.dark.surface);
    expect(field.style?.color, AppColors.dark.primaryText);
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor, AppColors.dark.background);
  });
}
