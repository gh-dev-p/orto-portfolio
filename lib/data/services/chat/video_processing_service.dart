import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../../config/album_limits.dart';

// ============================================================
// 状態クラス
// ============================================================

/// 動画の情報（回転を反映した表示の大きさ）
class VideoInfo {
  const VideoInfo({required this.durationMs, required this.width, required this.height, this.sizeBytes});

  final int durationMs;
  final int width;
  final int height;

  /// ファイルの大きさ（圧縮後のみ）
  final int? sizeBytes;
}

// ============================================================
// 例外
// ============================================================

/// 動画の処理の失敗の種類（ネイティブのエラーコードと対応する）
enum VideoProcessingError {
  /// 読めないファイル
  invalidInput,

  /// 端末が扱えない形式
  unsupported,

  /// それ以外
  failed,
}

/// 動画の処理に失敗した
class VideoProcessingException implements Exception {
  const VideoProcessingException(this.error, [this.message]);

  final VideoProcessingError error;
  final String? message;

  @override
  String toString() => 'VideoProcessingException($error, $message)';
}

// ============================================================
// サービス
// ============================================================

/// 動画の圧縮とサムネイルの生成（機能仕様書4.4.9）を行う、ネイティブコードへの入口
/// iOSの`VideoProcessingChannel.swift`とAndroidの`VideoProcessingChannel.kt`が、同じメソッドを同じ形で実装する
class VideoProcessingService {
  VideoProcessingService([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('com.example.orto/video_processing') {
    _channel.setMethodCallHandler(_handleCall);
  }

  // ---- 状態・初期化 ----

  final MethodChannel _channel;

  /// 圧縮中の処理の進み具合の受け取り先（キーは処理のID）
  final _progressListeners = <String, void Function(double progress)>{};

  var _nextTaskId = 0;

  Future<void> _handleCall(MethodCall call) async {
    if (call.method != 'progress') return;
    final args = call.arguments as Map;
    _progressListeners[args['taskId']]?.call((args['progress'] as num).toDouble());
  }

  // ---- 動画 ----

  /// 動画の長さと大きさを読む
  Future<VideoInfo> probe(File input) async {
    return _toInfo(await _invoke('probe', {'inputPath': input.path}));
  }

  /// [input]をアルバムの形式（短辺720px・約2Mbps・30fps以下のH.264とAACのmp4）にして[output]へ書く
  /// [onProgress]には、処理済みの割合（0〜1）を渡す
  Future<VideoInfo> compress(File input, File output, {void Function(double progress)? onProgress}) async {
    final taskId = 'task-${_nextTaskId++}';
    if (onProgress != null) _progressListeners[taskId] = onProgress;
    try {
      return _toInfo(
        await _invoke('compress', {
          'inputPath': input.path,
          'outputPath': output.path,
          'taskId': taskId,
          'maxShortSide': AlbumLimits.videoMaxShortSide,
          'videoBitrate': AlbumLimits.videoBitrate,
          'audioBitrate': AlbumLimits.audioBitrate,
          'maxFrameRate': AlbumLimits.videoMaxFrameRate,
        }),
      );
    } finally {
      _progressListeners.remove(taskId);
    }
  }

  /// 動画の先頭付近のフレームを、JPEGのサムネイルとして[output]へ書く
  Future<void> thumbnail(File input, File output) async {
    await _invoke('thumbnail', {
      'inputPath': input.path,
      'outputPath': output.path,
      'maxSide': AlbumLimits.thumbnailMaxSide,
      'quality': AlbumLimits.thumbnailQuality,
    });
  }

  Future<Map<Object?, Object?>> _invoke(String method, Map<String, Object> args) async {
    try {
      return (await _channel.invokeMapMethod<Object?, Object?>(method, args))!;
    } on PlatformException catch (e) {
      throw VideoProcessingException(switch (e.code) {
        'invalid_input' => VideoProcessingError.invalidInput,
        'unsupported' => VideoProcessingError.unsupported,
        _ => VideoProcessingError.failed,
      }, e.message);
    } on MissingPluginException catch (e) {
      throw VideoProcessingException(VideoProcessingError.unsupported, e.message);
    }
  }

  static VideoInfo _toInfo(Map<Object?, Object?> value) {
    return VideoInfo(
      durationMs: (value['durationMs'] as num).toInt(),
      width: (value['width'] as num).toInt(),
      height: (value['height'] as num).toInt(),
      sizeBytes: (value['sizeBytes'] as num?)?.toInt(),
    );
  }
}
