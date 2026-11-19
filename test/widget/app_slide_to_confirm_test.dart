import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/core/ui/app_slide_to_confirm.dart';

final _thumb = find.byIcon(Icons.chevron_right);

Future<void> _pump(
  WidgetTester tester, {
  bool enabled = true,
  required Future<void> Function() onConfirmed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: AppSlideToConfirm(
              label: 'スライドして実行',
              semanticLabel: '実行する',
              enabled: enabled,
              onConfirmed: onConfirmed,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('右端まで動かして離すと確定し、触覚のフィードバックを出す', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    var count = 0;
    await _pump(tester, onConfirmed: () async => count++);

    await tester.drag(_thumb, const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(count, 1);
    expect(haptics, ['HapticFeedbackType.heavyImpact']);
  });

  testWidgets('途中で離すと確定せず、つまみが左端へ戻る', (tester) async {
    var count = 0;
    await _pump(tester, onConfirmed: () async => count++);
    final start = tester.getCenter(_thumb);

    await tester.drag(_thumb, const Offset(150, 0));
    await tester.pumpAndSettle();

    expect(count, 0);
    expect(tester.getCenter(_thumb), start);
  });

  testWidgets('途中から素早く弾いても確定しない', (tester) async {
    var count = 0;
    await _pump(tester, onConfirmed: () async => count++);

    await tester.fling(_thumb, const Offset(100, 0), 3000);
    await tester.pumpAndSettle();

    expect(count, 0);
  });

  testWidgets('無効の間はつまみを動かせない', (tester) async {
    var count = 0;
    await _pump(tester, enabled: false, onConfirmed: () async => count++);
    final start = tester.getCenter(_thumb);

    await tester.drag(_thumb, const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(count, 0);
    expect(tester.getCenter(_thumb), start);
  });

  testWidgets('トラックのつまみ以外から動かしても確定しない', (tester) async {
    var count = 0;
    await _pump(tester, onConfirmed: () async => count++);

    await tester.drag(find.text('スライドして実行'), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(count, 0);
  });

  testWidgets('実行中は二度目を受け付けず、終わると左端へ戻る（失敗時も同じ）', (tester) async {
    final completer = Completer<void>();
    var count = 0;
    await _pump(
      tester,
      onConfirmed: () {
        count++;
        return completer.future;
      },
    );
    final start = tester.getCenter(_thumb);

    await tester.drag(_thumb, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);

    // 右端に留まったつまみをもう一度動かす
    await tester.drag(find.byIcon(Icons.check), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(count, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(tester.getCenter(_thumb), start);
  });

  testWidgets('読み上げではボタンとして実行できる', (tester) async {
    final semantics = tester.ensureSemantics();
    var count = 0;
    await _pump(tester, onConfirmed: () async => count++);

    expect(
      tester.getSemantics(find.byType(AppSlideToConfirm)),
      matchesSemantics(
        label: '実行する',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    final node = tester.getSemantics(find.byType(AppSlideToConfirm));
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();

    expect(count, 1);
    semantics.dispose();
  });

  testWidgets('無効の間は読み上げからも実行できない', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, enabled: false, onConfirmed: () async {});

    expect(
      tester.getSemantics(find.byType(AppSlideToConfirm)),
      matchesSemantics(label: '実行する', isButton: true, hasEnabledState: true),
    );
    semantics.dispose();
  });
}
