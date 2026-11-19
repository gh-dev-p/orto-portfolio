import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/domain/models/message.dart';
import 'package:multi_id_msg/domain/models/sticker_pack.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/chat/view_models/chat_image_providers.dart';
import 'package:multi_id_msg/ui/chat/widgets/message_bubble.dart';
import 'package:multi_id_msg/ui/chat/widgets/sticker_picker_panel.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';

/// [imageUrl]は画像のURLの取得処理
Widget _app(Widget home, {required Future<String> Function(String path) imageUrl}) => ProviderScope(
  retry: noProviderRetry,
  overrides: [chatImageUrlProvider.overrideWith((ref, path) => imageUrl(path))],
  child: MaterialApp(
    locale: const Locale('ja'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  ),
);

Message _sticker({required String packId}) => Message(
  id: 'm1',
  senderId: 'peer',
  text: '',
  type: MessageType.sticker,
  stickerPackId: packId,
  stickerId: '01',
  createdAt: DateTime(2026, 10, 1, 12),
  readBy: const [],
);

Widget _bubble(Message message) => MessageBubble(
  message: message,
  isMine: false,
  isReadByPeer: false,
  isSelectable: false,
  onRetry: (_) {},
  onLongPress: (_, _) {},
  onOpenImage: (_) {},
  onTapReactions: (_, _) {},
);

void main() {
  test('stickerの種類を読み取れる', () {
    expect(MessageType.fromValue('sticker'), MessageType.sticker);
  });

  test('パックのドキュメントを読み取れる（データ設計書3.9）', () {
    final pack = StickerPack.fromMap({
      'packId': 'pack',
      'stickerIds': ['01', '02'],
    });

    expect(pack.id, 'pack');
    expect(pack.stickerIds, ['01', '02']);
  });

  test('形式の合わないIDはStorageのパスにしない', () {
    expect(StickerPack.storagePath('pack', '01'), 'stickers/pack/01.webp');
    expect(StickerPack.storagePath('', '01'), isNull);
    expect(StickerPack.storagePath('../accounts', '01'), isNull);
    expect(StickerPack.storagePath('pack', 'a/b'), isNull);
  });

  testWidgets('画像を取得できないスタンプは、代替の文言を表示する（機能仕様書4.4.8）', (tester) async {
    await tester.pumpWidget(
      _app(_bubble(_sticker(packId: 'missing')), imageUrl: (_) => Future.error('object-not-found')),
    );
    await tester.pumpAndSettle();

    expect(find.text('スタンプを表示できません'), findsOneWidget);
  });

  testWidgets('失敗したスタンプは、タップで読み込み直す（機能仕様書4.4.8）', (tester) async {
    final requested = <String>[];
    await tester.pumpWidget(
      _app(
        _bubble(_sticker(packId: 'pack')),
        imageUrl: (path) {
          requested.add(path);
          return Future.error('offline');
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('スタンプを表示できません'));
    await tester.pumpAndSettle();

    expect(requested, ['stickers/pack/01.webp', 'stickers/pack/01.webp']);
  });

  testWidgets('形式の合わないIDのスタンプは、取得せずに代替の文言を表示する', (tester) async {
    final requested = <String>[];
    await tester.pumpWidget(
      _app(
        _bubble(_sticker(packId: '../accounts')),
        imageUrl: (path) {
          requested.add(path);
          return Future.error('unexpected');
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('スタンプを表示できません'), findsOneWidget);
    expect(requested, isEmpty);
  });

  testWidgets('選択パネルでタップしたスタンプを返す（機能仕様書4.4.8）', (tester) async {
    StickerSelection? selected;
    await tester.pumpWidget(
      _app(
        StickerPickerPanel(
          packs: const [
            StickerPack(id: 'pack', stickerIds: ['01', '02']),
          ],
          onSelected: (selection) => selected = selection,
        ),
        imageUrl: (_) => Completer<String>().future,
      ),
    );

    await tester.tap(find.byKey(const Key('sticker-pack-02')));
    await tester.pump();

    expect(selected, (packId: 'pack', stickerId: '02'));
  });
}
