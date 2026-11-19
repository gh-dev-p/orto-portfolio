// GRP-10 参加時の質問（機能仕様書4.7.8.5 / 画面設計書5.10.10）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/group/widgets/join_questions_screen.dart';

Widget _app(Widget home) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('ja'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

TextButton _saveButton(WidgetTester tester) => tester.widget<TextButton>(find.byKey(const Key('join-questions-save')));

void main() {
  testWidgets('質問なしなら空の欄を1つ出し、例を出す。変えるまで保存できない', (tester) async {
    await tester.pumpWidget(
      _app(const JoinQuestionsScreen(chatRoomId: 'g1', myAccountId: 'alice', initialQuestions: [])),
    );

    expect(find.text('参加時の質問'), findsOneWidget);
    expect(find.text('質問1'), findsOneWidget);
    expect(find.text('例：Xの@IDを教えてください'), findsOneWidget);
    expect(find.text('質問を変えても、届いている申請の質問と答えはそのままです'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('join-question-0')), 'XのIDは？');
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('質問は3問まで足せ、3問になると「質問を追加」を出さない', (tester) async {
    await tester.pumpWidget(
      _app(const JoinQuestionsScreen(chatRoomId: 'g1', myAccountId: 'alice', initialQuestions: ['Q1'])),
    );

    await tester.tap(find.byKey(const Key('join-questions-add')));
    await tester.pump();
    expect(find.text('質問2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('join-questions-add')));
    await tester.pump();
    expect(find.text('質問3'), findsOneWidget);
    expect(find.byKey(const Key('join-questions-add')), findsNothing);
    // 空の欄を足しただけでは変更にならない
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('欄を消すと保存できるようになる', (tester) async {
    await tester.pumpWidget(
      _app(const JoinQuestionsScreen(chatRoomId: 'g1', myAccountId: 'alice', initialQuestions: ['Q1', 'Q2'])),
    );

    await tester.tap(find.byTooltip('質問を削除').first);
    await tester.pump();
    expect(find.text('Q1'), findsNothing);
    expect(find.text('Q2'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNotNull);
  });
}
