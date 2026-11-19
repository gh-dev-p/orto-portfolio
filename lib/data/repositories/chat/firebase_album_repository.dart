import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/album.dart';
import '../../../domain/models/firestore_values.dart';
import '../../../domain/models/report_reason.dart';
import '../../services/chat/chat_image_storage_service.dart';
import '../../services/common/firestore_paths.dart';
import '../../services/common/storage_paths.dart';
import '../report/report_repository.dart';
import 'album_repository.dart';
import 'chat_repository.dart';

// ============================================================
// リポジトリ
// ============================================================

/// トークのアルバムの、Firebase SDKでの実装（機能仕様書4.4.9、データ設計書3.13・7章）
/// アルバムと項目はFirestore、画像・動画・サムネイルはCloud Storageに置く
///
/// 件数・使用量・カバーの集計と、ファイルの削除はサーバー（Cloud Functionsの`albums.js`）が行う。
/// 上限・参加者・読み取り専用・ブロック・閉じたオフ会グループの拒否は、firestore.rules・storage.rulesが保証する
class FirebaseAlbumRepository implements AlbumRepository {
  FirebaseAlbumRepository(this._paths, this._storageService, this._chatRepository, this._reportRepository);

  // ---- 状態・初期化 ----

  final FirestorePaths _paths;
  final ChatImageStorageService _storageService;
  final ChatRepository _chatRepository;
  final ReportRepository _reportRepository;

  // ---- 読み込み ----

  @override
  Stream<List<Album>> watchAlbums(String chatRoomId) {
    return _paths
        .albums(chatRoomId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => parseSkippingBroken(snap.docs, (doc) => albumFromMap(doc.id, doc.data())));
  }

  @override
  Stream<Album?> watchAlbum({required String chatRoomId, required String albumId}) {
    return _paths.albums(chatRoomId).doc(albumId).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : albumFromMap(doc.id, data);
    });
  }

  @override
  Stream<List<AlbumItem>> watchItems({required String chatRoomId, required String albumId, required int limit}) {
    return _paths
        .albumItems(chatRoomId, albumId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => parseSkippingBroken(snap.docs, (doc) => albumItemFromMap(doc.id, albumId, doc.data())));
  }

  @override
  Future<String> mediaUrl(String path) => _storageService.downloadUrl(path);

  @override
  Future<void> downloadFile(String path, File file) => _storageService.downloadToFile(path, file);

  // ---- アルバムの操作 ----

  @override
  Future<String> createAlbum({
    required String chatRoomId,
    required String name,
    required String accountId,
    required String? peerAccountId,
  }) async {
    final ref = _paths.albums(chatRoomId).doc();
    final batch = _paths.batch();
    if (peerAccountId != null) {
      // 1対1の最初のトークでは、ルームを同じリクエストで作る（firestore.rulesは書き込み後の状態を見る）
      final roomRef = _paths.chatRoom(chatRoomId);
      if (!(await roomRef.get()).exists) {
        batch.set(roomRef, {
          'chatRoomId': chatRoomId,
          'participantIds': [accountId, peerAccountId]..sort(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    batch.set(ref, {
      'albumId': ref.id,
      'name': name,
      'createdByAccountId': accountId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return ref.id;
  }

  @override
  Future<void> renameAlbum({
    required String chatRoomId,
    required String albumId,
    required String name,
    required String accountId,
  }) {
    return _paths.albums(chatRoomId).doc(albumId).update({'name': name, 'updatedByAccountId': accountId});
  }

  @override
  Future<void> deleteAlbum({required String chatRoomId, required String albumId}) {
    // 項目とファイルは、サーバー（onChatAlbumDeleted）が消す
    return _paths.albums(chatRoomId).doc(albumId).delete();
  }

  // ---- 項目の操作 ----

  @override
  Future<void> addItem({
    required String chatRoomId,
    required String albumId,
    required String accountId,
    required PreparedAlbumMedia media,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _paths.albumItems(chatRoomId, albumId).doc();
    final isVideo = media.type == AlbumItemType.video;
    final path = isVideo
        ? StoragePaths.albumVideo(chatRoomId, albumId, ref.id)
        : StoragePaths.albumImage(chatRoomId, albumId, ref.id);
    final thumbnailPath = StoragePaths.albumThumbnail(chatRoomId, albumId, ref.id);
    try {
      await _storageService.uploadFile(thumbnailPath, media.thumbnail, contentType: 'image/jpeg');
      await _storageService.uploadFile(
        path,
        media.file,
        contentType: isVideo ? 'video/mp4' : 'image/jpeg',
        onProgress: onProgress,
      );
      await ref.set({
        'itemId': ref.id,
        'albumId': albumId,
        'type': media.type.value,
        'path': path,
        'thumbnailPath': thumbnailPath,
        'width': media.width,
        'height': media.height,
        'durationMs': ?media.durationMs,
        // 申告値。サーバー（onChatAlbumItemCreated）がStorageの実際の大きさで数え直す
        'sizeBytes': await media.file.length() + await media.thumbnail.length(),
        'uploaderAccountId': accountId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AlbumAddException(isRejection(e.code) ? AlbumAddFailure.rejected : AlbumAddFailure.failed);
    }
  }

  @override
  Future<void> deleteItem({required String chatRoomId, required String albumId, required String itemId}) {
    // ファイルは、サーバー（onChatAlbumItemDeleted）が消す
    return _paths.albumItems(chatRoomId, albumId).doc(itemId).delete();
  }

  // ---- トークとの連携 ----

  @override
  Future<void> sendNotice({
    required String chatRoomId,
    required String senderAccountId,
    required String? peerAccountId,
    required String albumId,
    required String albumName,
    required AlbumEvent event,
    required int itemCount,
  }) {
    return _chatRepository.sendAlbumNotice(
      chatRoomId: chatRoomId,
      senderAccountId: senderAccountId,
      peerAccountId: peerAccountId,
      albumId: albumId,
      albumName: albumName,
      event: event,
      itemCount: itemCount,
    );
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
  }) {
    // 項目のファイルは、サーバー（onAlbumItemReported）が運営者の確認用に複製する
    return _reportRepository.report(
      reporterAccountId: reporterAccountId,
      targetAccountId: targetAccountId,
      reason: reason,
      detail: detail,
      chatRoomId: chatRoomId,
      albumId: albumId,
      albumItemId: itemId,
    );
  }
}

// ============================================================
// 関数
// ============================================================

/// 拒否（上限・ブロック・読み取り専用・閉じたグループ）を表すFirebase SDKのエラーか
/// Firestoreは`permission-denied`、Storageは`unauthorized`を返す
bool isRejection(String code) => code == 'permission-denied' || code == 'unauthorized';

/// `albums`のドキュメントから[Album]を作る（データ設計書3.13）
Album albumFromMap(String albumId, Map<String, dynamic> data) {
  return Album(
    albumId: albumId,
    name: stringOrNull(data['name']) ?? '',
    createdByAccountId: stringOrNull(data['createdByAccountId']) ?? '',
    createdAt: dateOrNull(data['createdAt']),
    updatedAt: dateOrNull(data['updatedAt']),
    itemCount: intOrNull(data['itemCount']) ?? 0,
    coverThumbnailPath: stringOrNull(data['coverThumbnailPath']),
  );
}

/// `items`のドキュメントから[AlbumItem]を作る（データ設計書3.13）
/// 保存先が無い項目は表示できないので、[FormatException]を投げる（一覧では飛ばす）
AlbumItem albumItemFromMap(String itemId, String albumId, Map<String, dynamic> data) {
  final path = stringOrNull(data['path']);
  final thumbnailPath = stringOrNull(data['thumbnailPath']);
  if (path == null || thumbnailPath == null) throw const FormatException('album item without path');
  return AlbumItem(
    itemId: itemId,
    albumId: albumId,
    type: AlbumItemType.fromValue(stringOrNull(data['type'])),
    path: path,
    thumbnailPath: thumbnailPath,
    width: intOrNull(data['width']) ?? 0,
    height: intOrNull(data['height']) ?? 0,
    durationMs: intOrNull(data['durationMs']),
    uploaderAccountId: stringOrNull(data['uploaderAccountId']) ?? '',
    createdAt: dateOrNull(data['createdAt']),
  );
}
