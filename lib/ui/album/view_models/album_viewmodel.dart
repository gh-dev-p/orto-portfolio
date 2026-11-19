import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../../../config/service_providers.dart';
import '../../../data/services/chat/photo_library_service.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/image_save_result.dart';
import 'album_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// ALB-02（アルバムの中身）の状態
class AlbumDetailState {
  const AlbumDetailState({this.limit = AlbumViewModel.pageSize, this.selecting = false, this.selectedIds = const {}});

  /// 監視する項目の件数（スクロールで増やす）
  final int limit;

  /// 複数選択中か
  final bool selecting;

  /// 選択中の項目のID
  final Set<String> selectedIds;

  AlbumDetailState copyWith({int? limit, bool? selecting, Set<String>? selectedIds}) {
    return AlbumDetailState(
      limit: limit ?? this.limit,
      selecting: selecting ?? this.selecting,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

// ============================================================
// ViewModel
// ============================================================

/// ALB-02（アルバムの中身）・ALB-03（全画面表示）のViewModel
/// 名前の変更、削除、項目の選択・保存・削除を扱う
///
/// 機能仕様書：4.4.9
class AlbumViewModel extends Notifier<AlbumDetailState> {
  AlbumViewModel(this.key);

  /// 一度に増やす項目の件数
  static const pageSize = 60;

  // ---- 状態・初期化 ----

  final AlbumKey key;

  @override
  AlbumDetailState build() => const AlbumDetailState();

  // ---- 表示 ----

  /// 監視する項目の件数を増やす
  /// [loaded]件まで読み終わっているときだけ増やす
  void loadMore(int loaded) {
    if (loaded >= state.limit) state = state.copyWith(limit: state.limit + pageSize);
  }

  // ---- 選択 ----

  void startSelecting() => state = state.copyWith(selecting: true);

  void stopSelecting() => state = state.copyWith(selecting: false, selectedIds: const {});

  /// 項目の選択を切り替える
  void toggle(String itemId) {
    final selected = {...state.selectedIds};
    if (!selected.remove(itemId)) selected.add(itemId);
    state = state.copyWith(selectedIds: selected);
  }

  // ---- 操作 ----

  Future<void> rename({required String name, required String accountId}) {
    return ref
        .read(albumRepositoryProvider)
        .renameAlbum(chatRoomId: key.chatRoomId, albumId: key.albumId, name: name, accountId: accountId);
  }

  Future<void> deleteAlbum() {
    return ref.read(albumRepositoryProvider).deleteAlbum(chatRoomId: key.chatRoomId, albumId: key.albumId);
  }

  /// 項目を消す
  /// 自分が追加した項目だけを渡す（他の人の項目はルールで拒否される）
  Future<void> deleteItems(Iterable<AlbumItem> items) async {
    final repository = ref.read(albumRepositoryProvider);
    await Future.wait(
      items.map((item) => repository.deleteItem(chatRoomId: key.chatRoomId, albumId: key.albumId, itemId: item.itemId)),
    );
  }

  /// 端末のアルバムへの保存が許可されているか
  /// まだ許可を求めていなければ、ここで求める（許可されなければfalse）
  Future<bool> ensureAccess() => const PhotoLibraryService().ensureAccess();

  /// 項目を順に端末のアルバムに保存する
  /// すべて保存できれば[ImageSaveResult.saved]。途中で失敗したら、そこで止めて結果を返す
  Future<ImageSaveResult> saveItems(Iterable<AlbumItem> items) async {
    final repository = ref.read(albumRepositoryProvider);
    final workDir = await getTemporaryDirectory();
    for (final item in items) {
      final file = File('${workDir.path}/${item.itemId}.${item.isVideo ? 'mp4' : 'jpg'}');
      try {
        await repository.downloadFile(item.path, file);
        final library = const PhotoLibraryService();
        await (item.isVideo ? library.saveVideo(file.path) : library.saveImageFile(file.path));
      } on GalException catch (e) {
        return e.type == GalExceptionType.accessDenied ? ImageSaveResult.denied : ImageSaveResult.failed;
      } catch (_) {
        return ImageSaveResult.failed;
      } finally {
        if (await file.exists()) await file.delete();
      }
    }
    return ImageSaveResult.saved;
  }
}

// ============================================================
// Provider
// ============================================================

/// [AlbumViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final albumViewModelProvider = NotifierProvider.autoDispose.family<AlbumViewModel, AlbumDetailState, AlbumKey>(
  AlbumViewModel.new,
);
