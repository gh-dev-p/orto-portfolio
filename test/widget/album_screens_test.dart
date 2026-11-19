import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/domain/models/album.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/album/view_models/album_providers.dart';
import 'package:multi_id_msg/ui/album/widgets/album_detail_screen.dart';
import 'package:multi_id_msg/ui/album/widgets/album_list_screen.dart';
import 'package:multi_id_msg/ui/album/widgets/album_viewer_screen.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/group/widgets/meetup_closed_bar.dart';

const _album = Album(
  albumId: 'a1',
  name: '旅行',
  createdByAccountId: 'alice',
  createdAt: null,
  updatedAt: null,
  itemCount: 2,
);

AlbumItem _item(String id, {AlbumItemType type = AlbumItemType.image, String uploader = 'alice'}) => AlbumItem(
  itemId: id,
  albumId: 'a1',
  type: type,
  path: 'chatRooms/room/albums/a1/$id.jpg',
  thumbnailPath: 'chatRooms/room/albums/a1/${id}_thumb.jpg',
  width: 720,
  height: 1280,
  durationMs: type == AlbumItemType.video ? 5000 : null,
  uploaderAccountId: uploader,
  createdAt: null,
);

/// 閉じたオフ会グループ（機能仕様書4.4.9.5）
final _closedMeetup = GroupRoom(
  chatRoomId: 'room',
  kind: GroupKind.meetup,
  closesAt: DateTime(2026, 11, 1, 22),
  closedAt: DateTime(2026, 11, 1, 22),
);

Widget _app(
  Widget home, {
  bool canEdit = true,
  List<Album> albums = const [_album],
  List<AlbumItem>? items,
  GroupRoom? closedRoom,
}) {
  return ProviderScope(
    retry: noProviderRetry,
    overrides: [
      albumsProvider.overrideWith((ref, _) => Stream.value(albums)),
      albumProvider.overrideWith((ref, _) => Stream.value(_album)),
      albumItemsProvider.overrideWith((ref, _) => Stream.value(items ?? [_item('i1'), _item('i2')])),
      canEditAlbumsProvider.overrideWith((ref, _) => canEdit),
      albumClosedRoomProvider.overrideWith((ref, _) => closedRoom),
      albumThumbnailFileProvider.overrideWith((ref, _) => Completer<Never>().future),
      albumMediaUrlProvider.overrideWith((ref, _) => Completer<String>().future),
    ],
    child: MaterialApp(
      locale: const Locale('ja'),
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  const list = AlbumListScreen(chatRoomId: 'room', myAccountId: 'alice', peerAccountId: 'bob');
  const detail = AlbumDetailScreen(chatRoomId: 'room', albumId: 'a1', myAccountId: 'alice', peerAccountId: 'bob');

  // 読み込みが終わらないサムネイルの枠を残したまま確かめる（pumpAndSettleは使わない）。
  Future<void> show(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump();
  }

  group('ALB-01', () {
    testWidgets('アルバムの名前と件数を出す', (tester) async {
      await show(tester, _app(list));
      expect(find.text('旅行'), findsOneWidget);
      expect(find.text('2件'), findsOneWidget);
      expect(find.byKey(const Key('album-create')), findsOneWidget);
    });

    testWidgets('0件の案内を出す', (tester) async {
      await show(tester, _app(list, albums: const []));
      expect(find.text('アルバムはまだありません'), findsOneWidget);
    });

    testWidgets('変更できない間は作成ボタンを出さない', (tester) async {
      await show(tester, _app(list, canEdit: false));
      expect(find.byKey(const Key('album-create')), findsNothing);
    });

    testWidgets('閉じたオフ会グループでは、記録が消える日を出す', (tester) async {
      await show(tester, _app(list, canEdit: false, closedRoom: _closedMeetup));
      expect(find.byType(MeetupClosedBar), findsOneWidget);
      expect(find.textContaining('このグループは閉じました。'), findsOneWidget);
    });

    testWidgets('閉じていなければ、閉じた案内を出さない', (tester) async {
      await show(tester, _app(list));
      expect(find.byType(MeetupClosedBar), findsNothing);
    });
  });

  group('ALB-02', () {
    testWidgets('項目をグリッドで出し、追加ボタンを出す', (tester) async {
      await show(tester, _app(detail));
      expect(find.byType(AlbumItemTile), findsNWidgets(2));
      expect(find.byKey(const Key('album-add')), findsOneWidget);
    });

    testWidgets('変更できない間は追加ボタンを出さない', (tester) async {
      await show(tester, _app(detail, canEdit: false));
      expect(find.byKey(const Key('album-add')), findsNothing);
    });

    testWidgets('閉じたオフ会グループでは、追加・削除を出さず、閉じた案内を出す', (tester) async {
      await show(tester, _app(detail, canEdit: false, closedRoom: _closedMeetup));
      expect(find.byKey(const Key('album-add')), findsNothing);
      expect(find.byType(MeetupClosedBar), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('選択'), findsOneWidget);
      expect(find.text('アルバムを削除'), findsNothing);
    });

    testWidgets('項目をタップすると全画面表示を開く', (tester) async {
      await show(tester, _app(detail));
      await tester.tap(find.byType(AlbumItemTile).first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AlbumViewerScreen), findsOneWidget);
    });
  });

  group('ALB-03', () {
    Widget viewer(List<AlbumItem> items, {GroupRoom? closedRoom}) => _app(
      closedRoom: closedRoom,
      AlbumViewerScreen(
        chatRoomId: 'room',
        albumId: 'a1',
        myAccountId: 'alice',
        peerAccountId: 'bob',
        items: items,
        initialIndex: 0,
      ),
    );

    testWidgets('自分の項目には削除を出す', (tester) async {
      await show(tester, viewer([_item('i1')]));
      expect(find.byKey(const Key('album-viewer-delete')), findsOneWidget);
      expect(find.byKey(const Key('album-viewer-report')), findsNothing);
      expect(find.byKey(const Key('album-viewer-save')), findsOneWidget);
    });

    testWidgets('閉じたオフ会グループでは、自分の項目も削除を出さず、保存はできる', (tester) async {
      await show(tester, viewer([_item('i1')], closedRoom: _closedMeetup));
      expect(find.byKey(const Key('album-viewer-delete')), findsNothing);
      expect(find.byKey(const Key('album-viewer-save')), findsOneWidget);
    });

    testWidgets('閉じたオフ会グループでも、他の人の項目は通報できる', (tester) async {
      await show(tester, viewer([_item('i1', uploader: 'bob')], closedRoom: _closedMeetup));
      expect(find.byKey(const Key('album-viewer-report')), findsOneWidget);
    });

    testWidgets('動画は再生ボタンを出すだけで読み込まない', (tester) async {
      await show(tester, viewer([_item('i1', type: AlbumItemType.video)]));
      expect(find.byIcon(CupertinoIcons.play_circle_fill), findsOneWidget);
    });
  });
}
