import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/services/chat/album_media_service.dart';
import 'package:multi_id_msg/domain/models/album.dart';
import 'package:multi_id_msg/ui/album/view_models/album_upload_viewmodel.dart';

import '../support/fake_album_repository.dart';

class _FakeMediaService implements AlbumMediaService {
  /// ファイルのパスごとの変換の失敗
  final failures = <String, Object>{};
  final prepared = <String>[];

  @override
  Future<PreparedAlbumMedia> prepare(
    File source, {
    required Directory workDir,
    required String fileId,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    final failure = failures[source.path];
    if (failure != null) throw failure;
    prepared.add(source.path);
    return PreparedAlbumMedia(type: AlbumItemType.image, file: source, thumbnail: source, width: 1, height: 1);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = (chatRoomId: 'room', albumId: 'a1');
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory dir;
  late FakeAlbumRepository albums;
  late _FakeMediaService media;
  late ProviderContainer container;

  AlbumUploadViewModel viewModel() => container.read(albumUploadViewModelProvider(key).notifier);
  AlbumUploadState state() => container.read(albumUploadViewModelProvider(key));

  Future<void> add(List<String> paths, {AlbumEvent event = AlbumEvent.created}) => viewModel().add(
    files: [for (final path in paths) File(path)],
    accountId: 'alice',
    peerAccountId: null,
    albumName: '旅行',
    event: event,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('album_upload_test');
    messenger.setMockMethodCallHandler(pathProvider, (_) async => dir.path);
    albums = FakeAlbumRepository();
    albums.albums['a1'] = const Album(
      albumId: 'a1',
      name: '旅行',
      createdByAccountId: 'alice',
      createdAt: null,
      updatedAt: null,
    );
    media = _FakeMediaService();
    container = ProviderContainer(
      overrides: [albumRepositoryProvider.overrideWithValue(albums), albumMediaServiceProvider.overrideWithValue(media)],
    );
  });

  tearDown(() async {
    container.dispose();
    messenger.setMockMethodCallHandler(pathProvider, null);
    await dir.delete(recursive: true);
  });

  test('まとめて追加しても案内は1件で、件数は追加できた数', () async {
    await add(['/a.jpg', '/b.jpg', '/c.mov']);
    expect(albums.items['a1'], hasLength(3));
    expect(albums.notices, [(event: AlbumEvent.created, itemCount: 3)]);
    expect(state().running, isFalse);
    expect(state().failedFiles, isEmpty);
  });

  test('一部が失敗しても続け、失敗した分を残す', () async {
    media.failures['/b.mov'] = const AlbumAddException(AlbumAddFailure.videoTooLong);
    await add(['/a.jpg', '/b.mov', '/c.jpg']);
    expect(media.prepared, ['/a.jpg', '/c.jpg']);
    expect(albums.notices.single.itemCount, 2);
    expect(state().failedFiles.map((file) => file.path), ['/b.mov']);
    expect(state().failure, AlbumAddFailure.videoTooLong);
    expect(state().canRetry, isFalse);
  });

  test('1件も追加できなければ案内を送らない', () async {
    albums.addFailures.add(const AlbumAddException(AlbumAddFailure.failed));
    await add(['/a.jpg']);
    expect(albums.notices, isEmpty);
    expect(state().failure, AlbumAddFailure.failed);
    expect(state().canRetry, isTrue);
  });

  test('拒否されたら残りは試さない', () async {
    albums.addFailures.add(const AlbumAddException(AlbumAddFailure.rejected));
    await add(['/a.jpg', '/b.jpg', '/c.jpg']);
    expect(media.prepared, ['/a.jpg']);
    expect(state().failedFiles, hasLength(3));
    expect(state().canRetry, isFalse);
  });

  test('再試行は失敗した分だけを追加し、案内は追加になる', () async {
    albums.addFailures.addAll([null, const AlbumAddException(AlbumAddFailure.failed)]);
    await add(['/a.jpg', '/b.jpg']);
    await viewModel().retry(accountId: 'alice', peerAccountId: null, albumName: '旅行');
    expect(media.prepared, ['/a.jpg', '/b.jpg', '/b.jpg']);
    expect(albums.items['a1'], hasLength(2));
    expect(albums.notices.last, (event: AlbumEvent.added, itemCount: 1));
    expect(state().failedFiles, isEmpty);
  });

  test('案内を送れなくても追加は失敗にしない', () async {
    albums.noticeFails = true;
    await add(['/a.jpg']);
    expect(state().failedFiles, isEmpty);
  });

  test('全体の進み具合', () {
    const running = AlbumUploadState(total: 4, finished: 1, progress: 0.5, running: true);
    expect(running.overallProgress, closeTo(0.375, 0.001));
  });
}
