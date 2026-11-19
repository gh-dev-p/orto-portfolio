import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/album.dart';
import 'album_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// アルバムへの追加の状態
class AlbumUploadState {
  const AlbumUploadState({
    this.total = 0,
    this.finished = 0,
    this.progress = 0,
    this.running = false,
    this.failedFiles = const [],
    this.failure,
  });

  /// 今回の追加の件数
  final int total;

  /// 処理が終わった件数（失敗を含む）
  final int finished;

  /// 処理中の項目の進み具合（0〜1）
  final double progress;

  final bool running;

  /// 追加できなかったファイル（再試行の対象）
  final List<File> failedFiles;

  /// 最後の失敗の理由
  final AlbumAddFailure? failure;

  /// 全体の進み具合（0〜1）
  double get overallProgress => total == 0 ? 0 : ((finished + progress) / total).clamp(0, 1);

  /// 再試行で直る見込みがあるか
  /// 動画の長さ・大きさ・形式は、やり直しても変わらない
  bool get canRetry => !running && failedFiles.isNotEmpty && failure == AlbumAddFailure.failed;

  AlbumUploadState copyWith({int? finished, double? progress}) {
    return AlbumUploadState(
      total: total,
      finished: finished ?? this.finished,
      progress: progress ?? this.progress,
      running: running,
      failedFiles: failedFiles,
      failure: failure,
    );
  }
}

// ============================================================
// ViewModel
// ============================================================

/// アルバムへの画像・動画の追加のViewModel
/// 画面を閉じても追加を続けられるよう、Providerは破棄しない（アプリを閉じると中断する）
///
/// 機能仕様書：4.4.9
class AlbumUploadViewModel extends Notifier<AlbumUploadState> {
  AlbumUploadViewModel(this.key);

  // ---- 状態・初期化 ----

  /// 追加先のアルバム
  final AlbumKey key;

  /// 動画の進み具合のうち、変換が占める割合
  static const _prepareShare = 0.5;

  @override
  AlbumUploadState build() => const AlbumUploadState();

  // ---- 操作 ----

  /// [files]を順に追加する
  /// 1件でも追加できたら、最後にトークへ案内を1件送る（[event]はその種類）
  /// 上限やブロックで拒否されたら、残りは試さない
  Future<void> add({
    required List<File> files,
    required String accountId,
    required String? peerAccountId,
    required String albumName,
    required AlbumEvent event,
  }) async {
    if (state.running || files.isEmpty) return;
    state = AlbumUploadState(total: files.length, running: true);
    final repository = ref.read(albumRepositoryProvider);
    final mediaService = ref.read(albumMediaServiceProvider);
    final workDir = await (await getTemporaryDirectory()).createTemp('album');
    final failed = <File>[];
    AlbumAddFailure? failure;
    var added = 0;

    for (final (index, file) in files.indexed) {
      if (failure == AlbumAddFailure.rejected) {
        failed.addAll(files.skip(index));
        break;
      }
      try {
        final media = await mediaService.prepare(
          file,
          workDir: workDir,
          fileId: '$index',
          onProgress: (progress) => state = state.copyWith(progress: progress * _prepareShare),
        );
        final isVideo = media.type == AlbumItemType.video;
        await repository.addItem(
          chatRoomId: key.chatRoomId,
          albumId: key.albumId,
          accountId: accountId,
          media: media,
          onProgress: (progress) => state = state.copyWith(
            progress: isVideo ? _prepareShare + progress * (1 - _prepareShare) : progress,
          ),
        );
        added++;
      } on AlbumAddException catch (e) {
        failed.add(file);
        failure = e.failure;
      } catch (_) {
        failed.add(file);
        failure = AlbumAddFailure.failed;
      }
      state = state.copyWith(finished: index + 1, progress: 0);
    }

    if (added > 0) {
      try {
        await repository.sendNotice(
          chatRoomId: key.chatRoomId,
          senderAccountId: accountId,
          peerAccountId: peerAccountId,
          albumId: key.albumId,
          albumName: albumName,
          event: event,
          itemCount: added,
        );
      } catch (_) {
        // 項目は追加できているので、案内を送れなくても失敗として扱わない。
      }
    }
    try {
      await workDir.delete(recursive: true);
    } on FileSystemException catch (_) {
      // 一時フォルダなので、消せなくても処理は続ける。
    }
    state = AlbumUploadState(total: files.length, finished: files.length, failedFiles: failed, failure: failure);
  }

  /// 追加できなかったファイルをもう一度追加する
  Future<void> retry({required String accountId, required String? peerAccountId, required String albumName}) {
    return add(
      files: state.failedFiles,
      accountId: accountId,
      peerAccountId: peerAccountId,
      albumName: albumName,
      event: AlbumEvent.added,
    );
  }

  /// 結果の表示を消す
  void clear() {
    if (!state.running) state = const AlbumUploadState();
  }
}

// ============================================================
// Provider
// ============================================================

/// [AlbumUploadViewModel]のProvider
final albumUploadViewModelProvider = NotifierProvider.family<AlbumUploadViewModel, AlbumUploadState, AlbumKey>(
  AlbumUploadViewModel.new,
);
