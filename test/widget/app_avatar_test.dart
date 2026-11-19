import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/core/themes/app_colors.dart';
import 'package:multi_id_msg/ui/core/ui/app_avatar.dart';

Future<void> _pump(WidgetTester tester, String? url, {String displayName = 'alice', double size = 48}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: Center(
          child: AppAvatar(displayName: displayName, photoURL: url, size: size),
        ),
      ),
    );

void main() {
  testWidgets('このアプリのStorageの画像は読み込む', (tester) async {
    await _pump(
      tester,
      'https://firebasestorage.googleapis.com/v0/b/example-orto-prod.firebasestorage.app/o/accounts%2Fbob%2Fprofile.jpg?alt=media',
    );

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('他のサーバーのURLは読み込まず、頭文字を出す', (tester) async {
    await _pump(tester, 'https://attacker.example/t/1.jpg');

    expect(find.byType(Image), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });
  testWidgets('表示名が空なら「?」を出す', (tester) async {
    await _pump(tester, null, displayName: '');

    expect(find.text('?'), findsOneWidget);
  });

  group('頭文字は見た目の1文字で切り出す', () {
    const cases = {
      '異体字セレクタつきの絵文字': ('\u270C\uFE0Fあいう', '\u270C\uFE0F'),
      '肌の色つきの絵文字': ('\u270C\u{1F3FD}', '\u270C\u{1F3FD}'),
      'ZWJで結合した絵文字': ('\u{1F468}\u200D\u{1F469}\u200D\u{1F467}x', '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}'),
      '国旗': ('\u{1F1EF}\u{1F1F5}\u{1F1FA}\u{1F1F8}', '\u{1F1EF}\u{1F1F5}'),
      '結合文字の濁点': ('か\u3099き', 'か\u3099'),
      'ひらがな': ('あいう', 'あ'),
      '漢字': ('山田', '山'),
      '英字': ('bob', 'B'),
    };

    for (final MapEntry(key: name, value: (displayName, expected)) in cases.entries) {
      testWidgets(name, (tester) async {
        await _pump(tester, null, displayName: displayName);

        expect(find.text(expected), findsOneWidget);
      });
    }
  });

  testWidgets('頭文字は大きく組んで縮小し、アバターの中心に置く', (tester) async {
    await _pump(tester, null, displayName: '\u270C\uFE0F', size: 40);

    final text = tester.widget<Text>(find.byType(Text));
    final scale = tester.widget<Transform>(find.ancestor(of: find.byType(Text), matching: find.byType(Transform)));

    expect(text.style!.fontSize, 100);
    expect(scale.transform.entry(0, 0), closeTo(0.16, 0.0001));
    expect(tester.getCenter(find.byType(Text)), tester.getCenter(find.byType(AppAvatar)));
  });

  testWidgets('大きく組んだ頭文字があふれてもレイアウトエラーにならない', (tester) async {
    await _pump(tester, null, displayName: 'W', size: 24);

    expect(tester.takeException(), isNull);
    expect(find.text('W'), findsOneWidget);
  });
}
