import 'dart:async';
import 'dart:io';

import 'package:multi_id_msg/data/repositories/chat/album_repository.dart';
import 'package:multi_id_msg/domain/models/album.dart';
import 'package:multi_id_msg/domain/models/report_reason.dart';

/// [AlbumRepository]のメモリ上の実装（テスト用）
/// サーバーの役割（件数・カバーの集計）もここで行う
class FakeAlbumRepository implements AlbumRepository {
  final albums = <String, Album>{};
  final items = <String, List<AlbumItem>>{};
  final notices = <({AlbumEvent event, int itemCount})>[];
  final reports = <({String itemId, ReportReason reason, String targetAccountId})>[];

  /// 次の[addItem]で投げる例外を、件数ぶん順に使う（nullなら成功）
  final addFailures = <Object?>[];
  var noticeFails = false;

  final _changes = StreamController<void>.broadcast();
  var _nextId = 0;

  String _id(String prefix) => '$prefix${_nextId++}';
  void _changed() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) {
    late final StreamController<T> controller;
    late final StreamSubscription<void> subscription;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        subscription = _changes.stream.listen((_) => controller.add(read()));
      },
      onCancel: () => subscription.cancel(),
    );
    return controller.stream;
  }

  void _recount(String albumId) {
    final album = albums[albumId]!;
    final list = items[albumId] ?? const <AlbumItem>[];
    albums[albumId] = Album(
      albumId: albumId,
      name: album.name,
      createdByAccountId: album.createdByAccountId,
      createdAt: album.createdAt,
      updatedAt: DateTime.now(),
      itemCount: list.length,
      coverThumbnailPath: list.isEmpty ? null : list.first.thumbnailPath,
    );
  }

  @override
  Stream<List<Album>> watchAlbums(String chatRoomId) => _watch(() => albums.values.toList());

  @override
  Stream<Album?> watchAlbum({required String chatRoomId, required String albumId}) => _watch(() => albums[albumId]);

  @override
  Stream<List<AlbumItem>> watchItems({required String chatRoomId, required String albumId, required int limit}) =>
      _watch(() => (items[albumId] ?? const <AlbumItem>[]).take(limit).toList());

  @override
  Future<String> mediaUrl(String path) async => 'https://example.test/$path';

  @override
  Future<void> downloadFile(String path, File file) => file.writeAsBytes([1]);

  @override
  Future<String> createAlbum({
    required String chatRoomId,
    required String name,
    required String accountId,
    required String? peerAccountId,
  }) async {
    final albumId = _id('a');
    albums[albumId] = Album(
      albumId: albumId,
      name: name,
      createdByAccountId: accountId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _changed();
    return albumId;
  }

  @override
  Future<void> renameAlbum({
    required String chatRoomId,
    required String albumId,
    required String name,
    required String accountId,
  }) async {
    final album = albums[albumId]!;
    albums[albumId] = Album(
      albumId: albumId,
      name: name,
      createdByAccountId: album.createdByAccountId,
      createdAt: album.createdAt,
      updatedAt: album.updatedAt,
      itemCount: album.itemCount,
      coverThumbnailPath: album.coverThumbnailPath,
    );
    _changed();
  }

  @override
  Future<void> deleteAlbum({required String chatRoomId, required String albumId}) async {
    albums.remove(albumId);
    items.remove(albumId);
    _changed();
  }

  @override
  Future<void> addItem({
    required String chatRoomId,
    required String albumId,
    required String accountId,
    required PreparedAlbumMedia media,
    void Function(double progress)? onProgress,
  }) async {
    if (addFailures.isNotEmpty) {
      final failure = addFailures.removeAt(0);
      if (failure != null) throw failure;
    }
    onProgress?.call(1);
    final itemId = _id('i');
    (items[albumId] ??= []).insert(
      0,
      AlbumItem(
        itemId: itemId,
        albumId: albumId,
        type: media.type,
        path: 'file/$itemId',
        thumbnailPath: 'thumb/$itemId',
        width: media.width,
        height: media.height,
        durationMs: media.durationMs,
        uploaderAccountId: accountId,
        createdAt: DateTime.now(),
      ),
    );
    _recount(albumId);
    _changed();
  }

  @override
  Future<void> deleteItem({required String chatRoomId, required String albumId, required String itemId}) async {
    items[albumId]?.removeWhere((item) => item.itemId == itemId);
    _recount(albumId);
    _changed();
  }

  @override
  Future<void> sendNotice({
    required String chatRoomId,
    required String senderAccountId,
    required String? peerAccountId,
    required String albumId,
    required String albumName,
    required AlbumEvent event,
    required int itemCount,
  }) async {
    if (noticeFails) throw Exception('notice failed');
    notices.add((event: event, itemCount: itemCount));
  }

  @override
  Future<void> reportItem({
    required String chatRoomId,
    required String albumId,
    required String itemId,
    required String reporterAccountId,
    required String targetAccountId,
    required ReportReason reason,
    String? detail,
  }) async {
    reports.add((itemId: itemId, reason: reason, targetAccountId: targetAccountId));
  }
}
