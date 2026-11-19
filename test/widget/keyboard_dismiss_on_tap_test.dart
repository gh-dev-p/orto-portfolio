import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/domain/models/sticker_pack.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/chat/view_models/chat_image_providers.dart';
import 'package:multi_id_msg/ui/chat/widgets/message_input_bar.dart';
import 'package:multi_id_msg/ui/chat/widgets/selection_mode_text.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/core/ui/keyboard_dismiss_on_tap.dart';

const _field = Key('field');
const _blank = Key('blank');
const _button = Key('button');
const _list = Key('list');

Widget _app(Widget home) => ProviderScope(
  retry: noProviderRetry,
  overrides: [chatImageUrlProvider.overrideWith((ref, path) => Completer<String>().future)],
  child: MaterialApp(
    locale: const Locale('ja'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => KeyboardDismissOnTap(child: child!),
    home: home,
  ),
);

Widget _screen({VoidCallback? onPressed}) => Scaffold(
  body: Column(
    children: [
      const TextField(key: _field),
      TextButton(key: _button, onPressed: onPressed ?? () {}, child: const Text('ボタン')),
      const Expanded(child: SizedBox.expand(key: _blank)),
      SizedBox(
        height: 200,
        child: ListView.builder(
          key: _list,
          itemCount: 50,
          itemBuilder: (_, index) => SizedBox(height: 48, child: Text('行$index')),
        ),
      ),
    ],
  ),
);

Future<void> _showKeyboard(WidgetTester tester, [Finder? field]) async {
  await tester.showKeyboard(field ?? find.byKey(_field));
  await tester.pump();
  expect(tester.testTextInput.isVisible, isTrue);
}

/// 余白は描画もタップの処理も持たないため、位置を指定してタップする
Future<void> _tapBlank(WidgetTester tester, Finder blank) => tester.tapAt(tester.getCenter(blank));

void main() {
  testWidgets('入力欄の外の余白をタップするとキーボードを閉じる', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    await _showKeyboard(tester);

    await _tapBlank(tester, find.byKey(_blank));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('ボタンをタップすると、ボタンが動いてキーボードも閉じる', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(_app(_screen(onPressed: () => pressed++)));
    await _showKeyboard(tester);

    await tester.tap(find.byKey(_button));
    await tester.pump();

    expect(pressed, 1);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('入力欄をタップしてもキーボードは閉じない', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    await _showKeyboard(tester);

    await tester.tap(find.byKey(_field));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('スクロールではキーボードを閉じない', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    await _showKeyboard(tester);

    await tester.drag(find.byKey(_list), const Offset(0, -150));
    await tester.pumpAndSettle();

    expect(find.text('行0'), findsNothing);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('長押しではキーボードを閉じない', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    await _showKeyboard(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_blank)));
    await tester.pump(kLongPressTimeout);
    await gesture.up(timeStamp: kLongPressTimeout);
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('ボトムシートの中でも閉じる', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    showModalBottomSheet<void>(
      context: tester.element(find.byKey(_blank)),
      builder: (_) => const SizedBox(
        height: 300,
        child: Column(
          children: [
            TextField(key: Key('sheet-field')),
            Expanded(child: SizedBox.expand(key: Key('sheet-blank'))),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _showKeyboard(tester, find.byKey(const Key('sheet-field')));

    await _tapBlank(tester, find.byKey(const Key('sheet-blank')));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.byKey(const Key('sheet-field')), findsOneWidget);
  });

  testWidgets('ダイアログの中でも閉じる', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    showDialog<void>(
      context: tester.element(find.byKey(_blank)),
      builder: (_) => const AlertDialog(
        title: Text('タイトル', key: Key('dialog-title')),
        content: TextField(key: Key('dialog-field')),
      ),
    );
    await tester.pumpAndSettle();
    await _showKeyboard(tester, find.byKey(const Key('dialog-field')));

    await tester.tap(find.byKey(const Key('dialog-title')));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.byKey(const Key('dialog-field')), findsOneWidget);
  });

  testWidgets('部分コピー中の本文は、外をタップしてもフォーカスと選択を保つ', (tester) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: Column(
            children: [
              SelectionModeText(text: '本文', color: Colors.black),
              Expanded(child: SizedBox.expand(key: _blank)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final editable = find.byType(EditableText);
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);

    await _tapBlank(tester, find.byKey(_blank));
    await tester.pump();

    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
  });

  group('トークの入力バー', () {
    late TextEditingController controller;
    var sent = 0;

    Widget chat() => _app(
      Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox.expand(key: _blank)),
            MessageInputBar(
              controller: controller,
              sending: false,
              maxLength: 2000,
              onSend: () => sent++,
              onPickImage: () {},
              stickerPacks: const [
                StickerPack(id: 'pack', stickerIds: ['01']),
              ],
              onSelectSticker: (_) {},
            ),
          ],
        ),
      ),
    );

    setUp(() {
      controller = TextEditingController();
      sent = 0;
    });
    tearDown(() => controller.dispose());

    testWidgets('送信ボタンを押しても入力を続けられる', (tester) async {
      await tester.pumpWidget(chat());
      await _showKeyboard(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'こんにちは');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('message-input-send')));
      await tester.pump();

      expect(sent, 1);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('入力バーの外をタップするとキーボードを閉じる', (tester) async {
      await tester.pumpWidget(chat());
      await _showKeyboard(tester, find.byType(TextField));

      await _tapBlank(tester, find.byKey(_blank));
      await tester.pump();

      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('スタンプボタンでキーボードからパネルへ切り替えられる', (tester) async {
      await tester.pumpWidget(chat());
      await _showKeyboard(tester, find.byType(TextField));

      await tester.tap(find.byKey(const Key('message-input-sticker')));
      await tester.pump();

      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byIcon(CupertinoIcons.keyboard), findsOneWidget);
    });
  });
}
