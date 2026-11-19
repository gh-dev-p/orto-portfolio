import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/album_limits.dart';
import 'package:multi_id_msg/data/services/chat/video_processing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.orto/video_processing');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late VideoProcessingService service;

  Future<void> handle(Future<Object?> Function(MethodCall call) handler) async {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  /// ネイティブからの進み具合の呼び出し
  Future<void> sendProgress(String taskId, double progress) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('progress', {'taskId': taskId, 'progress': progress})),
      (_) {},
    );
  }

  setUp(() {
    calls.clear();
    service = VideoProcessingService();
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('圧縮の設定をネイティブへ渡し、結果を読む', () async {
    await handle((call) async => {'durationMs': 2000, 'width': 720, 'height': 1280, 'sizeBytes': 10});
    final info = await service.compress(File('/in.mov'), File('/out.mp4'));
    expect(info.width, 720);
    expect(info.sizeBytes, 10);
    final args = calls.single.arguments as Map;
    expect(args['inputPath'], '/in.mov');
    expect(args['outputPath'], '/out.mp4');
    expect(args['maxShortSide'], AlbumLimits.videoMaxShortSide);
    expect(args['videoBitrate'], AlbumLimits.videoBitrate);
    expect(args['audioBitrate'], AlbumLimits.audioBitrate);
    expect(args['maxFrameRate'], AlbumLimits.videoMaxFrameRate);
  });

  test('進み具合は、その処理の受け取り先にだけ届く', () async {
    await handle((call) async {
      await sendProgress((call.arguments as Map)['taskId'] as String, 0.5);
      await sendProgress('other', 0.9);
      return {'durationMs': 1, 'width': 1, 'height': 1, 'sizeBytes': 1};
    });
    final progress = <double>[];
    await service.compress(File('/in.mov'), File('/out.mp4'), onProgress: progress.add);
    expect(progress, [0.5]);
  });

  test('エラーコードを種類に変換する', () async {
    for (final (code, error) in [
      ('invalid_input', VideoProcessingError.invalidInput),
      ('unsupported', VideoProcessingError.unsupported),
      ('failed', VideoProcessingError.failed),
      ('other', VideoProcessingError.failed),
    ]) {
      await handle((call) async => throw PlatformException(code: code));
      await expectLater(
        service.probe(File('/in.mov')),
        throwsA(isA<VideoProcessingException>().having((e) => e.error, 'error', error)),
      );
    }
  });

  test('ネイティブの実装が無い環境ではunsupportedになる', () async {
    await expectLater(
      service.probe(File('/in.mov')),
      throwsA(isA<VideoProcessingException>().having((e) => e.error, 'error', VideoProcessingError.unsupported)),
    );
  });
}
