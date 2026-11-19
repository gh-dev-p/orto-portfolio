import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/domain/models/album.dart';
import 'package:multi_id_msg/domain/models/report_reason.dart';
import 'package:multi_id_msg/ui/album/view_models/album_providers.dart';
import 'package:multi_id_msg/ui/album/view_models/album_viewmodel.dart';
import 'package:multi_id_msg/ui/report/view_models/report_viewmodel.dart';

import '../support/fake_album_repository.dart';

void main() {
  const key = (chatRoomId: 'room', albumId: 'a1');

  test('サーバーの実装ができたので、アルバムの入口は有効', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(albumFeatureEnabledProvider), isTrue);
  });

  group('フェイクの実装で', () {
    late FakeAlbumRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeAlbumRepository();
      container = ProviderContainer(
        overrides: [albumRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    Future<String> create() => repository.createAlbum(
      chatRoomId: 'room',
      name: '旅行',
      accountId: 'alice',
      peerAccountId: null,
    );

    test('作成・名前の変更・削除が一覧に反映される', () async {
      final albumId = await create();
      final albumKey = (chatRoomId: 'room', albumId: albumId);
      final sub = container.listen(albumsProvider('room'), (_, _) {});
      addTearDown(sub.close);
      await container.read(albumsProvider('room').future);
      expect(container.read(albumsProvider('room')).value!.single.name, '旅行');

      final viewModelSub = container.listen(albumViewModelProvider(albumKey), (_, _) {});
      addTearDown(viewModelSub.close);
      final viewModel = container.read(albumViewModelProvider(albumKey).notifier);
      await viewModel.rename(name: '新しい名前', accountId: 'bob');
      await pumpEventQueue();
      expect(container.read(albumsProvider('room')).value!.single.name, '新しい名前');

      await viewModel.deleteAlbum();
      await pumpEventQueue();
      expect(container.read(albumsProvider('room')).value, isEmpty);
    });

    test('項目を消すと件数とカバーが変わる', () async {
      final albumId = await create();
      for (var i = 0; i < 2; i++) {
        await repository.addItem(
          chatRoomId: 'room',
          albumId: albumId,
          accountId: 'alice',
          media: PreparedAlbumMedia(
            type: AlbumItemType.image,
            file: _noFile,
            thumbnail: _noFile,
            width: 1,
            height: 1,
          ),
        );
      }
      final newest = repository.items[albumId]!.first;
      final viewModel = container.read(albumViewModelProvider((chatRoomId: 'room', albumId: albumId)).notifier);
      await viewModel.deleteItems([newest]);
      expect(repository.albums[albumId]!.itemCount, 1);
      expect(repository.albums[albumId]!.coverThumbnailPath, repository.items[albumId]!.first.thumbnailPath);
    });

    test('選択と、読み終えた分に応じた件数の追加', () {
      final viewModel = container.read(albumViewModelProvider(key).notifier);
      viewModel
        ..startSelecting()
        ..toggle('i1')
        ..toggle('i2')
        ..toggle('i1');
      expect(container.read(albumViewModelProvider(key)).selectedIds, {'i2'});
      viewModel.stopSelecting();
      expect(container.read(albumViewModelProvider(key)).selecting, isFalse);

      viewModel.loadMore(10);
      expect(container.read(albumViewModelProvider(key)).limit, AlbumViewModel.pageSize);
      viewModel.loadMore(AlbumViewModel.pageSize);
      expect(container.read(albumViewModelProvider(key)).limit, AlbumViewModel.pageSize * 2);
    });

    test('項目の通報はアルバムの窓口へ送る', () async {
      const args = (
        myAccountId: 'alice',
        targetAccountId: 'bob',
        messageId: null,
        chatRoomId: 'room',
        albumId: 'a1',
        albumItemId: 'i1',
      );
      final sub = container.listen(reportViewModelProvider(args), (_, _) {});
      addTearDown(sub.close);
      final viewModel = container.read(reportViewModelProvider(args).notifier);
      viewModel.selectReason(ReportReason.inappropriate);
      expect(await viewModel.submit(), ReportOutcome.reported);
      expect(repository.reports.single.itemId, 'i1');
      expect(repository.reports.single.targetAccountId, 'bob');
    });
  });
}

final _noFile = File('/none');
