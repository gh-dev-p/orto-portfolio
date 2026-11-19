import 'dart:io';

// ============================================================
// モデル
// ============================================================

/// トークのアルバム（機能仕様書4.4.9）
/// 保存先に依存しない形で持ち、件数・カバーはサーバー側が集計する
class Album {
  const Album({
    required this.albumId,
    required this.name,
    required this.createdByAccountId,
    required this.createdAt,
    required this.updatedAt,
    this.itemCount = 0,
    this.coverThumbnailPath,
  });

  final String albumId;
  final String name;
  final String createdByAccountId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int itemCount;

  /// カバーのサムネイルの保存先を指すキー（項目が無ければnull）
  final String? coverThumbnailPath;


  /// アカウント[accountId]がこのアルバムを消せるか（表示用。拒否はサーバーが保証する）
  /// 作成者だけが消せる。グループでは、作成者が抜けていれば残った参加者が消せる（管理者がいないため）
  /// [memberAccountIds]はグループの参加者（1対1はnull）
  bool canBeDeletedBy(String accountId, {List<String>? memberAccountIds}) {
    if (createdByAccountId == accountId) return true;
    return memberAccountIds != null && !memberAccountIds.contains(createdByAccountId);
  }
}

/// アルバムの項目の種類
enum AlbumItemType {
  image('image'),
  video('video');

  const AlbumItemType(this.value);

  final String value;

  static AlbumItemType fromValue(String? value) => value == video.value ? video : image;
}

/// アルバムの画像・動画1件
class AlbumItem {
  const AlbumItem({
    required this.itemId,
    required this.albumId,
    required this.type,
    required this.path,
    required this.thumbnailPath,
    required this.width,
    required this.height,
    this.durationMs,
    required this.uploaderAccountId,
    required this.createdAt,
  });

  final String itemId;
  final String albumId;
  final AlbumItemType type;

  /// 本体の保存先を指すキー（中身はリポジトリの実装だけが扱う）
  final String path;

  /// サムネイルの保存先を指すキー
  final String thumbnailPath;
  final int width;
  final int height;

  /// 動画の長さ（画像はnull）
  final int? durationMs;

  /// 追加したアカウント
  final String uploaderAccountId;
  final DateTime? createdAt;

  bool get isVideo => type == AlbumItemType.video;

  /// 縦横比（大きさが不明なら1）
  double get aspectRatio => width > 0 && height > 0 ? width / height : 1;
}

/// アルバムの案内の種類
enum AlbumEvent {
  created('created'),
  added('added');

  const AlbumEvent(this.value);

  final String value;

  static AlbumEvent? fromValue(String? value) {
    for (final event in values) {
      if (event.value == value) return event;
    }
    return null;
  }
}

/// アップロードできる形に変換した項目（端末上のファイル）
class PreparedAlbumMedia {
  const PreparedAlbumMedia({
    required this.type,
    required this.file,
    required this.thumbnail,
    required this.width,
    required this.height,
    this.durationMs,
  });

  final AlbumItemType type;
  final File file;
  final File thumbnail;
  final int width;
  final int height;
  final int? durationMs;
}

// ============================================================
// 例外
// ============================================================

/// アルバムに追加できなかった理由
enum AlbumAddFailure {
  /// 動画が5分を超えている
  videoTooLong,

  /// 圧縮しても大きさの上限を超えている
  tooLarge,

  /// 端末が扱えない形式
  unsupported,

  /// アルバムやトークの上限に達した、またはブロック・読み取り専用で追加できない
  rejected,

  /// それ以外（通信の失敗など）
  failed,
}

/// アルバムに追加できなかった
class AlbumAddException implements Exception {
  const AlbumAddException(this.failure);

  final AlbumAddFailure failure;

  @override
  String toString() => 'AlbumAddException($failure)';
}
