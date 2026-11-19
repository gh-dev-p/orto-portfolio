import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/core/ui/new_message_banner.dart';

const _message = '新規メッセージがあります';
const _reaction = 'メッセージにリアクションがありました';
const _invite = 'グループに招待されました';

/// バナーが動ききるまでの時間（自動的に閉じる4秒より十分短い）
const _settle = Duration(milliseconds: 500);

Future<BuildContext> _pumpHost(WidgetTester tester, {ThemeData? theme}) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ja'),
      theme: theme ?? AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, child) => NewMessageBannerHost(child: child!),
      home: Builder(
        builder: (c) {
          context = c;
          return const Scaffold(body: Center(child: Text('画面')));
        },
      ),
    ),
  );
  return context;
}

Future<void> _show(WidgetTester tester, BuildContext context, {bool isReaction = false, VoidCallback? onTap}) async {
  showNewMessageBanner(context, isReaction: isReaction, onTap: onTap);
  await tester.pump();
  await tester.pump(_settle);
}

void main() {
  testWidgets('アプリ名と文言をセーフエリアの下に出し、「閉じる」は出さない', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 141);
    addTearDown(tester.view.resetPadding);
    final context = await _pumpHost(tester);

    await _show(tester, context);

    expect(find.text('Orto'), findsOneWidget);
    expect(find.text(_message), findsOneWidget);
    expect(find.text('閉じる'), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.getTopLeft(find.text('Orto')).dy, greaterThan(141 / tester.view.devicePixelRatio));
  });

  testWidgets('文言を通知の種類で変える', (tester) async {
    final context = await _pumpHost(tester);

    showNewMessageBanner(context, isGroupInvite: true);
    await tester.pump();
    expect(find.text(_invite), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('友だち申請の通知は「友だち申請が届きました」', (tester) async {
    final context = await _pumpHost(tester);

    showNewMessageBanner(context, isFriendRequest: true);
    await tester.pump();
    expect(find.text('友だち申請が届きました'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('約4秒で自動的に閉じる', (tester) async {
    final context = await _pumpHost(tester);
    await _show(tester, context);

    await tester.pump(const Duration(milliseconds: 3400));
    expect(find.text(_message), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(_settle);
    expect(find.text(_message), findsNothing);
  });

  testWidgets('表示中の次の新着は重ねずに差し替え、表示時間を数え直す', (tester) async {
    final context = await _pumpHost(tester);
    await _show(tester, context);
    await tester.pump(const Duration(seconds: 3));

    await _show(tester, context, isReaction: true);
    expect(find.text(_message), findsNothing);
    expect(find.text(_reaction), findsOneWidget);
    expect(find.text('Orto'), findsOneWidget);

    // 最初のバナーの4秒が過ぎても閉じない。
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_reaction), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(_settle);
    expect(find.text(_reaction), findsNothing);
  });

  testWidgets('閉じる途中で次の新着が来たら、新しい内容を出し直す', (tester) async {
    final context = await _pumpHost(tester);
    await _show(tester, context);
    await tester.pump(const Duration(milliseconds: 3600));
    await tester.pump(const Duration(milliseconds: 100));

    await _show(tester, context, isReaction: true);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_reaction), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('タップで通知先を開いて閉じる', (tester) async {
    final context = await _pumpHost(tester);
    var opened = 0;
    await _show(tester, context, onTap: () => opened++);

    await tester.tap(find.text(_message));
    await tester.pump();
    await tester.pump(_settle);

    expect(opened, 1);
    expect(find.text(_message), findsNothing);
  });

  testWidgets('開く先が無い通知は、タップすると閉じるだけ', (tester) async {
    final context = await _pumpHost(tester);
    await _show(tester, context);

    await tester.tap(find.text(_message));
    await tester.pump();
    await tester.pump(_settle);

    expect(find.text(_message), findsNothing);
  });

  testWidgets('上にスワイプすると閉じる', (tester) async {
    final context = await _pumpHost(tester);
    var opened = 0;
    await _show(tester, context, onTap: () => opened++);

    await tester.fling(find.text(_message), const Offset(0, -100), 1000);
    await tester.pump();
    await tester.pump(_settle);

    expect(find.text(_message), findsNothing);
    expect(opened, 0);
  });

  testWidgets('少しだけ引いて離すと元の位置に戻り、指で触れている間は閉じない', (tester) async {
    final context = await _pumpHost(tester);
    await _show(tester, context);
    final top = tester.getTopLeft(find.text('Orto')).dy;

    final gesture = await tester.startGesture(tester.getCenter(find.text(_message)), kind: PointerDeviceKind.touch);
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -6));
    await tester.pump();
    expect(tester.getTopLeft(find.text('Orto')).dy, lessThan(top));

    await tester.pump(const Duration(seconds: 5));
    expect(find.text(_message), findsOneWidget);

    await gesture.up();
    await tester.pump();
    await tester.pump(_settle);
    expect(tester.getTopLeft(find.text('Orto')).dy, top);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(_settle);
    expect(find.text(_message), findsNothing);
  });

  testWidgets('バナーの外のタップは下の画面に届く', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (_, child) => NewMessageBannerHost(child: child!),
        home: const _TapCounter(),
      ),
    );
    await _show(tester, tester.element(find.byType(_TapCounter)));

    await tester.tap(find.byType(TextButton));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ダークモードでも表示できる', (tester) async {
    final context = await _pumpHost(tester, theme: AppTheme.dark);
    await _show(tester, context);
    expect(find.text(_message), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('参加の申請の通知と、申請の結果の通知（グループ名入り）の文言', (tester) async {
    final context = await _pumpHost(tester);

    showNewMessageBanner(context, isJoinRequest: true);
    await tester.pump();
    await tester.pump(_settle);
    expect(find.text('参加の申請が届きました'), findsOneWidget);

    showNewMessageBanner(context, joinResult: JoinStatus.declined, groupName: 'ボドゲ会');
    await tester.pump();
    await tester.pump(_settle);
    expect(find.text('ボドゲ会への参加は承認されませんでした'), findsOneWidget);

    showNewMessageBanner(context, joinResult: JoinStatus.approved, groupName: 'ボドゲ会');
    await tester.pump();
    await tester.pump(_settle);
    expect(find.text('ボドゲ会への参加が承認されました'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('キャンセル待ちの繰り上げと、出欠の催促の文言', (tester) async {
    final context = await _pumpHost(tester);

    showNewMessageBanner(context, joinResult: JoinStatus.pending, groupName: 'ボドゲ会');
    await tester.pump();
    await tester.pump(_settle);
    expect(find.text('ボドゲ会のキャンセル待ちから繰り上がりました'), findsOneWidget);

    showNewMessageBanner(context, isJoinRequest: true, isWaitlistPromoted: true);
    await tester.pump();
    await tester.pump(_settle);
    expect(find.text('キャンセル待ちから繰り上がった人がいます'), findsOneWidget);

    showNewMessageBanner(context, isAttendanceReminder: true);
    await tester.pump();
    await tester.pump(_settle);
    expect(find.text('出欠の回答をお願いします'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}

class _TapCounter extends StatefulWidget {
  const _TapCounter();

  @override
  State<_TapCounter> createState() => _TapCounterState();
}

class _TapCounterState extends State<_TapCounter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(onPressed: () => setState(() => _count++), child: Text('$_count')),
    ),
  );
}
