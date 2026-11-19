import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/domain/models/album.dart';
import 'package:multi_id_msg/domain/models/message.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/album/view_models/album_providers.dart';
import 'package:multi_id_msg/ui/album/widgets/album_detail_screen.dart';
import 'package:multi_id_msg/ui/album/widgets/album_notice_card.dart';
import 'package:multi_id_msg/ui/chat/widgets/message_bubble.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';

Widget _app(Widget home, {Album? album}) => ProviderScope(
  retry: noProviderRetry,
  overrides: [albumProvider.overrideWith((ref, key) => Stream.value(album))],
  child: MaterialApp(
    locale: const Locale('ja'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: home)),
  ),
);

Message _message(AlbumEvent event) => Message(
  id: 'm1',
  senderId: 'alice',
  text: '',
  type: MessageType.album,
  albumId: 'a1',
  albumEvent: event,
  albumItemCount: 3,
  albumName: '送信時の名前',
  createdAt: null,
  readBy: const [],
);

const _album = Album(albumId: 'a1', name: '今の名前', createdByAccountId: 'alice', createdAt: null, updatedAt: null);

void main() {
  Widget card(AlbumEvent event, ValueChanged<Message> onOpen) => AlbumNoticeCard(
    chatRoomId: 'room',
    message: _message(event),
    onOpen: onOpen,
    onLongPress: (_, _) {},
  );

  testWidgets('作成の案内は今の名前と件数を出し、タップで開く', (tester) async {
    Message? opened;
    await tester.pumpWidget(_app(card(AlbumEvent.created, (message) => opened = message), album: _album));
    await tester.pumpAndSettle();
    expect(find.text('今の名前'), findsOneWidget);
    expect(find.text('アルバムを作成し、3件を追加しました'), findsOneWidget);
    await tester.tap(find.byType(AlbumNoticeCard));
    expect(opened?.albumId, 'a1');
  });

  testWidgets('追加の案内', (tester) async {
    await tester.pumpWidget(_app(card(AlbumEvent.added, (_) {}), album: _album));
    await tester.pumpAndSettle();
    expect(find.text('アルバムに3件を追加しました'), findsOneWidget);
  });

  testWidgets('消されたアルバムは、その旨を出してタップできない', (tester) async {
    Message? opened;
    await tester.pumpWidget(_app(card(AlbumEvent.created, (message) => opened = message)));
    await tester.pumpAndSettle();
    expect(find.text('削除されたアルバム'), findsOneWidget);
    await tester.tap(find.byType(AlbumNoticeCard));
    expect(opened, isNull);
  });

  testWidgets('アルバムを使えない間は、案内を非対応のメッセージとして表示する', (tester) async {
    await tester.pumpWidget(
      _app(
        MessageBubble(
          message: _message(AlbumEvent.created),
          isMine: false,
          isReadByPeer: false,
          isSelectable: false,
          onRetry: (_) {},
          onLongPress: (_, _) {},
          onOpenImage: (_) {},
          onTapReactions: (_, _) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AlbumNoticeCard), findsNothing);
    expect(find.text('アプリを更新すると表示できます'), findsOneWidget);
  });

  testWidgets('グリッドの動画には長さを出し、選択中は印を出す', (tester) async {
    const item = AlbumItem(
      itemId: 'i1',
      albumId: 'a1',
      type: AlbumItemType.video,
      path: 'p',
      thumbnailPath: 't',
      width: 720,
      height: 1280,
      durationMs: 65000,
      uploaderAccountId: 'alice',
      createdAt: null,
    );
    var tapped = false;
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [albumThumbnailFileProvider.overrideWith((ref, path) => throw StateError('offline'))],
        child: MaterialApp(
          theme: AppTheme.light,
          home: SizedBox.square(
            dimension: 120,
            child: AlbumItemTile(item: item, selected: true, onTap: () => tapped = true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1:05'), findsOneWidget);
    await tester.tap(find.byType(AlbumItemTile));
    expect(tapped, isTrue);
  });
}
