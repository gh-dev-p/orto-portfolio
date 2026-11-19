import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/repositories/chat/firebase_album_repository.dart';
import 'package:multi_id_msg/data/services/common/storage_paths.dart';
import 'package:multi_id_msg/domain/models/album.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/ui/album/view_models/album_providers.dart';
import 'package:multi_id_msg/ui/group/view_models/group_providers.dart';

void main() {
  group('アルバムのドキュメントの読み取り（データ設計書3.13）', () {
    test('集計値と日時を読む', () {
      final createdAt = DateTime(2026, 11, 17, 10);
      final album = albumFromMap('a1', {
        'albumId': 'a1',
        'name': '旅行',
        'createdByAccountId': 'alice',
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(createdAt),
        'itemCount': 3,
        'usageBytes': 100,
        'coverThumbnailPath': 'chatRooms/g1/albums/a1/i1_thumb.jpg',
      });
      expect(album.albumId, 'a1');
      expect(album.name, '旅行');
      expect(album.createdByAccountId, 'alice');
      expect(album.createdAt, createdAt);
      expect(album.itemCount, 3);
      expect(album.coverThumbnailPath, 'chatRooms/g1/albums/a1/i1_thumb.jpg');
    });

    test('サーバーが集計する前は0件でカバーなし', () {
      final album = albumFromMap('a1', {'name': '旅行', 'createdByAccountId': 'alice'});
      expect(album.itemCount, 0);
      expect(album.coverThumbnailPath, isNull);
      expect(album.createdAt, isNull);
    });
  });

  group('項目のドキュメントの読み取り', () {
    test('動画は長さを読む', () {
      final item = albumItemFromMap('i1', 'a1', {
        'type': 'video',
        'path': StoragePaths.albumVideo('g1', 'a1', 'i1'),
        'thumbnailPath': StoragePaths.albumThumbnail('g1', 'a1', 'i1'),
        'width': 720,
        'height': 1280,
        'durationMs': 5000,
        'uploaderAccountId': 'bob',
      });
      expect(item.isVideo, isTrue);
      expect(item.path, 'chatRooms/g1/albums/a1/i1.mp4');
      expect(item.thumbnailPath, 'chatRooms/g1/albums/a1/i1_thumb.jpg');
      expect(item.durationMs, 5000);
      expect(item.uploaderAccountId, 'bob');
    });

    test('保存先の無い項目は読めない（一覧では飛ばす）', () {
      expect(() => albumItemFromMap('i1', 'a1', {'type': 'image'}), throwsFormatException);
    });
  });

  test('Storageのパスは項目ごとに固定（storage.rules・firestore.rulesと同じ形）', () {
    expect(StoragePaths.albumImage('g1', 'a1', 'i1'), 'chatRooms/g1/albums/a1/i1.jpg');
  });

  test('拒否はFirestoreのpermission-deniedとStorageのunauthorized', () {
    expect(isRejection('permission-denied'), isTrue);
    expect(isRejection('unauthorized'), isTrue);
    expect(isRejection('unavailable'), isFalse);
    expect(AlbumAddFailure.values, contains(AlbumAddFailure.rejected));
  });

  group('閉じたオフ会グループの判定（機能仕様書4.4.9.5）', () {
    ProviderContainer containerWith(GroupRoom room) {
      final container = ProviderContainer(
        overrides: [groupRoomProvider(room.chatRoomId).overrideWith((ref) => Stream.value(room))],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<GroupRoom?> closedRoomOf(ProviderContainer container, String chatRoomId) async {
      final sub = container.listen(albumClosedRoomProvider(chatRoomId), (_, _) {});
      addTearDown(sub.close);
      await container.read(groupRoomProvider(chatRoomId).future);
      return container.read(albumClosedRoomProvider(chatRoomId));
    }

    test('期限を過ぎたオフ会グループは閉じている', () async {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final room = GroupRoom(chatRoomId: 'g1', kind: GroupKind.meetup, closesAt: past);
      expect(await closedRoomOf(containerWith(room), 'g1'), isNotNull);
    });

    test('期限前のオフ会グループと普通のグループは閉じていない', () async {
      final future = DateTime.now().add(const Duration(days: 1));
      final meetup = GroupRoom(chatRoomId: 'g1', kind: GroupKind.meetup, closesAt: future);
      expect(await closedRoomOf(containerWith(meetup), 'g1'), isNull);
      const standard = GroupRoom(chatRoomId: 'g2');
      expect(await closedRoomOf(containerWith(standard), 'g2'), isNull);
    });

    test('1対1はルームを読まずに閉じていない扱い', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(albumClosedRoomProvider('alice~bob')), isNull);
    });
  });
}
