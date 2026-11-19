import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/album_limits.dart';
import 'package:multi_id_msg/data/services/chat/album_media_service.dart';
import 'package:multi_id_msg/data/services/chat/video_processing_service.dart';
import 'package:multi_id_msg/domain/models/album.dart';

class _FakeVideoProcessing implements VideoProcessingService {
  int durationMs = 1000;
  int compressedSize = 1000;
  VideoProcessingException? error;
  var compressed = false;

  @override
  Future<VideoInfo> probe(File input) async {
    if (error case final error?) throw error;
    return VideoInfo(durationMs: durationMs, width: 1080, height: 1920);
  }

  @override
  Future<VideoInfo> compress(File input, File output, {void Function(double progress)? onProgress}) async {
    compressed = true;
    onProgress?.call(0.5);
    return VideoInfo(durationMs: durationMs, width: 720, height: 1280, sizeBytes: compressedSize);
  }

  @override
  Future<void> thumbnail(File input, File output) async => output.writeAsBytes([1]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory dir;
  late _FakeVideoProcessing video;
  late AlbumMediaService service;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('album_media_test');
    video = _FakeVideoProcessing();
    service = AlbumMediaService(video);
  });

  tearDown(() => dir.delete(recursive: true));

  Future<PreparedAlbumMedia> prepareVideo() => service.prepare(File('/in.mov'), workDir: dir, fileId: 'i1');

  Matcher fails(AlbumAddFailure failure) =>
      throwsA(isA<AlbumAddException>().having((e) => e.failure, 'failure', failure));

  test('動画は圧縮してサムネイルを作る', () async {
    final progress = <double>[];
    final prepared = await service.prepare(File('/in.mov'), workDir: dir, fileId: 'i1', onProgress: progress.add);
    expect(prepared.type, AlbumItemType.video);
    expect(prepared.file.path, endsWith('/i1.mp4'));
    expect(prepared.thumbnail.path, endsWith('/i1_thumb.jpg'));
    expect(prepared.width, 720);
    expect(prepared.durationMs, 1000);
    expect(progress, [0.5]);
  });

  test('5分ちょうどの動画は追加でき、超えると圧縮せずに拒否する', () async {
    video.durationMs = AlbumLimits.videoMaxDuration.inMilliseconds;
    await prepareVideo();
    video
      ..compressed = false
      ..durationMs += 1;
    await expectLater(prepareVideo(), fails(AlbumAddFailure.videoTooLong));
    expect(video.compressed, isFalse);
  });

  test('圧縮後に100MB以上なら拒否する', () async {
    video.compressedSize = AlbumLimits.videoMaxBytes;
    await expectLater(prepareVideo(), fails(AlbumAddFailure.tooLarge));
  });

  test('読めない動画は非対応として扱い、それ以外の失敗は再試行できる失敗にする', () async {
    video.error = const VideoProcessingException(VideoProcessingError.invalidInput);
    await expectLater(prepareVideo(), fails(AlbumAddFailure.unsupported));
    video.error = const VideoProcessingException(VideoProcessingError.unsupported);
    await expectLater(prepareVideo(), fails(AlbumAddFailure.unsupported));
    video.error = const VideoProcessingException(VideoProcessingError.failed);
    await expectLater(prepareVideo(), fails(AlbumAddFailure.failed));
  });
}
