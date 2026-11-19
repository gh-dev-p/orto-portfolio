import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/services/chat/album_media_service.dart';
import 'package:multi_id_msg/domain/models/album.dart';
import 'package:multi_id_msg/domain/models/message.dart';
import 'package:multi_id_msg/ui/album/widgets/album_detail_screen.dart';

void main() {
  const album = Album(albumId: 'a1', name: '旅行', createdByAccountId: 'alice', createdAt: null, updatedAt: null);

  group('canBeDeletedBy', () {
    test('作成者は消せる', () => expect(album.canBeDeletedBy('alice'), isTrue));

    test('1対1では作成者以外は消せない', () => expect(album.canBeDeletedBy('bob'), isFalse));

    test('グループでは作成者が参加中なら他の人は消せない', () {
      expect(album.canBeDeletedBy('bob', memberAccountIds: ['alice', 'bob']), isFalse);
    });

    test('グループで作成者が抜けていれば参加者が消せる', () {
      expect(album.canBeDeletedBy('bob', memberAccountIds: ['bob', 'carol']), isTrue);
    });
  });

  test('知らない項目の種類は画像として扱う', () {
    expect(AlbumItemType.fromValue('video'), AlbumItemType.video);
    expect(AlbumItemType.fromValue('image'), AlbumItemType.image);
    expect(AlbumItemType.fromValue(null), AlbumItemType.image);
  });

  test('アルバムの案内の種類を読む', () {
    expect(AlbumEvent.fromValue('created'), AlbumEvent.created);
    expect(AlbumEvent.fromValue('added'), AlbumEvent.added);
    expect(AlbumEvent.fromValue('other'), isNull);
    expect(MessageType.fromValue('album'), MessageType.album);
  });

  test('拡張子で動画を判定する（大文字を含む）', () {
    expect(isVideoFile('/tmp/a.MOV'), isTrue);
    expect(isVideoFile('/tmp/a.mp4'), isTrue);
    expect(isVideoFile('/tmp/a.heic'), isFalse);
    expect(isVideoFile('/tmp/a.jpg'), isFalse);
  });

  test('動画の長さの表示', () {
    expect(formatAlbumDuration(5000), '0:05');
    expect(formatAlbumDuration(65999), '1:05');
    expect(formatAlbumDuration(300000), '5:00');
  });
}
