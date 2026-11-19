import 'dart:io';
import 'dart:math';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../config/album_limits.dart';
import '../../../domain/models/album.dart';
import '../../../utils/image_metadata.dart';
import '../../../utils/image_size.dart';
import 'video_processing_service.dart';

// ============================================================
// 関数
// ============================================================

/// ファイルの拡張子から動画かどうかを判定する（画像の選択画面は種類を返さないことがある）
bool isVideoFile(String path) {
  final extension = path.split('.').last.toLowerCase();
  return const {'mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv', 'avi'}.contains(extension);
}

/// 画像を[quality]のJPEGに変換して[output]へ書き、長辺を[maxSide]以下にする
typedef ImageCompressor = Future<void> Function(File input, File output, {required int maxSide, required int quality});

// ============================================================
// サービス
// ============================================================

/// アルバムに追加する画像・動画を、アップロードできる形に変換するサービス（機能仕様書4.4.9）
/// 画像はJPEGに縮小し、動画は圧縮する。どちらもサムネイルを作る
class AlbumMediaService {
  AlbumMediaService(this._videoProcessing, {ImageCompressor? compressImage})
    : _compressImage = compressImage ?? _compressWithPlugin;

  // ---- 状態・初期化 ----

  final VideoProcessingService _videoProcessing;
  final ImageCompressor _compressImage;

  static Future<void> _compressWithPlugin(
    File input,
    File output, {
    required int maxSide,
    required int quality,
  }) async {
    // minWidth・minHeightは短辺に効くため、長辺が[maxSide]になる大きさを求めて渡す（拡大はされない）。
    final size = await readImageSize(input);
    final scale = maxSide / max(size.width, size.height);
    final result = await FlutterImageCompress.compressAndGetFile(
      input.path,
      output.path,
      minWidth: (size.width * scale).round(),
      minHeight: (size.height * scale).round(),
      quality: quality,
      keepExif: false,
    );
    if (result == null) throw const AlbumAddException(AlbumAddFailure.unsupported);
    // 位置・機種・撮影時刻などのメタデータを持ち越さない。エンコーダが書き足すExifなども除く
    await output.writeAsBytes(stripJpegMetadata(await output.readAsBytes()), flush: true);
  }

  // ---- 変換 ----

  /// [source]を[workDir]の中に変換する。ファイル名には[fileId]を使う
  /// 変換できなければ[AlbumAddException]を投げる。[onProgress]には変換の進み具合（0〜1）を渡す
  Future<PreparedAlbumMedia> prepare(
    File source, {
    required Directory workDir,
    required String fileId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      return isVideoFile(source.path)
          ? await _prepareVideo(source, workDir, fileId, onProgress)
          : await _prepareImage(source, workDir, fileId);
    } on VideoProcessingException catch (e) {
      throw AlbumAddException(
        e.error == VideoProcessingError.failed ? AlbumAddFailure.failed : AlbumAddFailure.unsupported,
      );
    }
  }

  Future<PreparedAlbumMedia> _prepareImage(File source, Directory workDir, String fileId) async {
    final file = File('${workDir.path}/$fileId.jpg');
    final thumbnail = File('${workDir.path}/${fileId}_thumb.jpg');
    await _compressImage(source, file, maxSide: AlbumLimits.imageMaxSide, quality: AlbumLimits.imageQuality);
    if (await file.length() >= AlbumLimits.imageMaxBytes) throw const AlbumAddException(AlbumAddFailure.tooLarge);
    await _compressImage(
      file,
      thumbnail,
      maxSide: AlbumLimits.thumbnailMaxSide,
      quality: AlbumLimits.thumbnailQuality,
    );
    final size = await readImageSize(file);
    return PreparedAlbumMedia(
      type: AlbumItemType.image,
      file: file,
      thumbnail: thumbnail,
      width: size.width,
      height: size.height,
    );
  }

  Future<PreparedAlbumMedia> _prepareVideo(
    File source,
    Directory workDir,
    String fileId,
    void Function(double progress)? onProgress,
  ) async {
    final info = await _videoProcessing.probe(source);
    if (info.durationMs > AlbumLimits.videoMaxDuration.inMilliseconds) {
      throw const AlbumAddException(AlbumAddFailure.videoTooLong);
    }
    final file = File('${workDir.path}/$fileId.mp4');
    final thumbnail = File('${workDir.path}/${fileId}_thumb.jpg');
    final compressed = await _videoProcessing.compress(source, file, onProgress: onProgress);
    if ((compressed.sizeBytes ?? 0) >= AlbumLimits.videoMaxBytes) {
      throw const AlbumAddException(AlbumAddFailure.tooLarge);
    }
    await _videoProcessing.thumbnail(file, thumbnail);
    return PreparedAlbumMedia(
      type: AlbumItemType.video,
      file: file,
      thumbnail: thumbnail,
      width: compressed.width,
      height: compressed.height,
      durationMs: compressed.durationMs,
    );
  }
}
