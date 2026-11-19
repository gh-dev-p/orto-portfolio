import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/domain/models/sticker_pack.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/chat/view_models/chat_image_providers.dart';
import 'package:multi_id_msg/ui/chat/widgets/message_input_bar.dart';
import 'package:multi_id_msg/ui/chat/widgets/sticker_picker_panel.dart';
import 'package:multi_id_msg/ui/core/themes/app_colors.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';

const _image = Key('message-input-image');
const _sticker = Key('message-input-sticker');
const _send = Key('message-input-send');
const _field = Key('message-input-field');
const _outside = Key('outside');

Widget _app({
  TextEditingController? controller,
  bool sending = false,
  bool preparingImage = false,
  VoidCallback? onSend,
  VoidCallback? onPickImage,
  List<StickerPack> packs = const [
    StickerPack(id: 'pack', stickerIds: ['01']),
  ],
  ValueChanged<StickerSelection>? onSelectSticker,
  ThemeData? theme,
}) => ProviderScope(
  retry: noProviderRetry,
  overrides: [chatImageUrlProvider.overrideWith((ref, path) => Completer<String>().future)],
  child: MaterialApp(
    locale: const Locale('ja'),
    theme: theme ?? AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        children: [
          const Expanded(child: SizedBox.expand(key: _outside)),
          MessageInputBar(
            controller: controller ?? TextEditingController(),
            sending: sending,
            preparingImage: preparingImage,
            maxLength: 2000,
            onSend: onSend ?? () {},
            onPickImage: onPickImage ?? () {},
            stickerPacks: packs,
            onSelectSticker: onSelectSticker ?? (_) {},
          ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('画像の読み込み中は表示を出し、画像ボタンを押せなくする（テキストは入力できる）', (tester) async {
    var picks = 0;
    await tester.pumpWidget(_app(preparingImage: true, onPickImage: () => picks++));

    expect(find.text('画像を準備しています…'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('message-input-preparing-image')),
        matching: find.byType(CupertinoActivityIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(_image));
    await tester.pump();
    expect(picks, 0);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isNot(false));
  });

  testWidgets('画像の読み込みが終わると表示を消し、画像ボタンを押せる', (tester) async {
    var picks = 0;
    await tester.pumpWidget(_app(onPickImage: () => picks++));

    expect(find.byKey(const Key('message-input-preparing-image')), findsNothing);
    await tester.tap(find.byKey(_image));
    await tester.pump();
    expect(picks, 1);
  });

  testWidgets('スタンプボタンは入力欄の内側の右端にある', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.descendant(of: find.byKey(_field), matching: find.byKey(_sticker)), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.smiley), findsOneWidget);
    expect(tester.getTopRight(find.byKey(_sticker)).dx, tester.getTopRight(find.byKey(_field)).dx);
  });

  testWidgets('スタンプがなければスタンプボタンを出さない', (tester) async {
    await tester.pumpWidget(_app(packs: const []));

    expect(find.byKey(_sticker), findsNothing);
  });

  testWidgets('送信ボタンは常に出て、入力が空のときは押しても送信しない', (tester) async {
    final controller = TextEditingController();
    var sent = 0;
    await tester.pumpWidget(_app(controller: controller, onSend: () => sent++));
    final button = tester.getRect(find.byKey(_send));
    final field = tester.getRect(find.byKey(_field));

    await tester.tap(find.byKey(_send), warnIfMissed: false);
    await tester.pump();
    expect(sent, 0);

    controller.text = '   ';
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_send), warnIfMissed: false);
    await tester.pump();
    expect(sent, 0);

    controller.text = 'こんにちは';
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_send));
    expect(sent, 1);

    expect(tester.getRect(find.byKey(_send)), button);
    expect(tester.getRect(find.byKey(_field)), field);
  });

  testWidgets('送信ボタンは入力欄の外の右にある', (tester) async {
    await tester.pumpWidget(_app());

    expect(tester.getTopLeft(find.byKey(_send)).dx, tester.getTopRight(find.byKey(_field)).dx);
  });

  testWidgets('送信中は入力欄が空でもインジケーターを出し、各操作を止める', (tester) async {
    final controller = TextEditingController(text: '本文');
    var picked = 0;
    var sent = 0;
    await tester.pumpWidget(
      _app(controller: controller, sending: true, onSend: () => sent++, onPickImage: () => picked++),
    );
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byKey(_send), findsNothing);

    await tester.tap(find.byKey(_image), warnIfMissed: false);
    await tester.pump();
    expect(picked, 0);
    expect(sent, 0);

    controller.clear();
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('画像ボタンをタップすると画像選択を呼ぶ', (tester) async {
    var picked = 0;
    await tester.pumpWidget(_app(onPickImage: () => picked++));

    await tester.tap(find.byKey(_image));

    expect(picked, 1);
  });

  testWidgets('複数行で入力欄が伸びても、左右のボタンは下端に残る', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_app(controller: controller));
    final singleLine = tester.getSize(find.byKey(_field)).height;

    controller.text = List.generate(10, (i) => '$i').join('\n');
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byKey(_field));

    expect(singleLine, 36);
    expect(field.height, greaterThan(singleLine));
    expect(field.height, lessThan(singleLine * 6));
    expect(tester.getRect(find.byKey(_sticker)).bottom, field.bottom);
    expect(tester.getRect(find.byKey(_image)).bottom, field.bottom);
  });

  testWidgets('スタンプボタンでパネルを開き、選んでも開いたままにする', (tester) async {
    StickerSelection? selected;
    await tester.pumpWidget(_app(onSelectSticker: (selection) => selected = selection));

    await tester.tap(find.byKey(_sticker));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.keyboard), findsOneWidget);

    await tester.tap(find.byKey(const Key('sticker-pack-01')));
    await tester.pumpAndSettle();

    expect(selected, (packId: 'pack', stickerId: '01'));
    expect(find.byType(StickerPickerPanel), findsOneWidget);
  });

  testWidgets('パネルの外をタップすると閉じる', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byKey(_sticker));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getTopLeft(find.byKey(_outside)) + const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(StickerPickerPanel), findsNothing);
    expect(find.byIcon(CupertinoIcons.smiley), findsOneWidget);
  });

  testWidgets('キーボードアイコンで入力欄へ切り替えると、キーボードが上がる間はパネルを残してから閉じる', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byKey(_sticker));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_sticker));
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    expect(find.byType(StickerPickerPanel), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(StickerPickerPanel), findsNothing);
  });

  testWidgets('キーボードが下がる間も、キーボードとパネルで入力欄の位置が動かない', (tester) async {
    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pump();
    final top = tester.getTopLeft(find.byKey(_field)).dy;

    await tester.tap(find.byKey(_sticker));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_field)).dy, top);

    tester.view.viewInsets = FakeViewPadding(bottom: 120 * tester.view.devicePixelRatio);
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_field)).dy, top);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(_field)).dy, top);
  });

  group('入力バーの下端', () {
    const background = Key('message-input-background');

    /// ホームインジケータとキーボードの高さを、実機と同じ関係で設定する
    void setBottom(WidgetTester tester, {required double keyboard}) {
      final ratio = tester.view.devicePixelRatio;
      tester.view.viewPadding = FakeViewPadding(bottom: 34 * ratio);
      tester.view.padding = FakeViewPadding(bottom: math.max(0, 34 - keyboard) * ratio);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * ratio);
    }

    void resetBottom(WidgetTester tester) {
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    }

    for (final (name, theme) in [('ライト', AppTheme.light), ('ダーク', AppTheme.dark)]) {
      testWidgets('$nameでは、背景がバーと同じ色で画面の下端まで続く', (tester) async {
        addTearDown(() => resetBottom(tester));
        setBottom(tester, keyboard: 0);
        await tester.pumpWidget(_app(theme: theme));

        final box = tester.widget<ColoredBox>(
          find.descendant(of: find.byKey(background), matching: find.byType(ColoredBox)),
        );
        expect(box.color, theme.extension<AppColors>()!.surface);
        final fill = tester.getRect(find.byKey(background));
        expect(fill.bottom, tester.getSize(find.byType(Scaffold)).height);
        expect(fill.top, lessThan(tester.getTopLeft(find.byKey(_field)).dy));
      });
    }

    testWidgets('キーボードの表示中も、背景は画面の下端まで続く', (tester) async {
      addTearDown(() => resetBottom(tester));
      setBottom(tester, keyboard: 300);
      await tester.pumpWidget(_app());
      await tester.pump();

      final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getRect(find.byKey(background)).bottom, screenHeight);
    });

    testWidgets('キーボードが閉じきるときも、入力欄はフレームごとにキーボードの動きに合わせて止まる', (tester) async {
      addTearDown(() => resetBottom(tester));
      setBottom(tester, keyboard: 0);
      await tester.pumpWidget(_app());
      final rest = tester.getTopLeft(find.byKey(_field)).dy;

      setBottom(tester, keyboard: 300);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(_field)).dy, lessThan(rest));

      setBottom(tester, keyboard: 20);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(_field)).dy, rest);

      // 閉じきったフレームでも、余白が遅れず入力欄が沈まない。
      setBottom(tester, keyboard: 0);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(_field)).dy, rest);
    });

    testWidgets('パネルを閉じるアニメーションの途中でキーボードが動いても、例外にならず中身を片付ける', (tester) async {
      await tester.pumpWidget(_app());
      await tester.tap(find.byKey(_sticker));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byKey(_outside)));
      await tester.pump(const Duration(milliseconds: 50));

      addTearDown(() => resetBottom(tester));
      setBottom(tester, keyboard: 100);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(StickerPickerPanel), findsNothing);
    });
  });
}
