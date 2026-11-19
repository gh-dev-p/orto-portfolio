import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/album_limits.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/image_save_result.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/album_media_pick.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/ui/empty_state_view.dart';
import '../../core/ui/error_retry_view.dart';
import '../../core/ui/text_edit_sheet.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../group/view_models/group_providers.dart';
import '../../group/widgets/meetup_closed_bar.dart';
import '../view_models/album_providers.dart';
import '../view_models/album_upload_viewmodel.dart';
import '../view_models/album_viewmodel.dart';
import 'album_thumbnail.dart';
import 'album_viewer_screen.dart';

/// [result]の保存の結果を伝える文言
String albumSaveResultMessage(AppLocalizations l10n, ImageSaveResult result) => switch (result) {
  ImageSaveResult.saved => l10n.albSaved,
  ImageSaveResult.denied => l10n.chaImageSaveDenied,
  ImageSaveResult.failed => l10n.albSaveFailed,
};

/// 画面ALB-02：アルバムの中身
/// 画像と動画のグリッドを表示し、追加・複数選択での保存と削除・名前の変更・アルバムの削除を行う
///
/// 機能仕様書：4.4.9 / 画面設計書：5.3.5
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({
    super.key,
    required this.chatRoomId,
    required this.albumId,
    required this.myAccountId,
    required this.peerAccountId,
  });

  final String chatRoomId;
  final String albumId;
  final String myAccountId;

  /// 相手のアカウントID（グループはnull）
  final String? peerAccountId;

  AlbumKey get _key => (chatRoomId: chatRoomId, albumId: albumId);

  AlbumViewModel _viewModel(WidgetRef ref) => ref.read(albumViewModelProvider(_key).notifier);

  // ---- 操作 ----

  Future<void> _add(BuildContext context, WidgetRef ref, Album album) async {
    final l10n = AppLocalizations.of(context)!;
    final remaining = AlbumLimits.itemsPerAlbum - album.itemCount;
    if (remaining <= 0) {
      showAppSnackBar(context, l10n.albTooManyItems);
      return;
    }
    final files = await pickAlbumMediaSafely(context);
    if (files.isEmpty) return;
    unawaited(
      ref
          .read(albumUploadViewModelProvider(_key).notifier)
          .add(
            files: files.take(remaining).toList(),
            accountId: myAccountId,
            peerAccountId: peerAccountId,
            albumName: album.name,
            event: AlbumEvent.added,
          ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Album album) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showTextEditSheet(
      context,
      title: l10n.albRenameTitle,
      initialValue: album.name,
      minLength: 1,
      maxLength: AlbumLimits.nameMaxLength,
      hintText: l10n.albNameHint,
    );
    if (name == null || name == album.name) return;
    try {
      await _viewModel(ref).rename(name: name, accountId: myAccountId);
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, l10n.albUpdateFailed);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.albDeleteTitle,
      message: l10n.albDeleteMessage,
      confirmLabel: l10n.albDeleteConfirm,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(loadingOverlayProvider.notifier).run(_viewModel(ref).deleteAlbum);
      navigator.pop();
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, l10n.albUpdateFailed);
    }
  }

  /// 右上のメニューを開く
  Future<void> _openMenu(
    BuildContext context,
    WidgetRef ref,
    Album album, {
    required bool canEdit,
    required bool closed,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final members = peerAccountId == null ? await ref.read(groupMembersProvider(chatRoomId).future) : null;
    if (!context.mounted) return;
    final canDelete = !closed && album.canBeDeletedBy(
      myAccountId,
      memberAccountIds: members?.map((member) => member.accountId).toList(),
    );
    final actions = <CupertinoActionSheetAction>[
      CupertinoActionSheetAction(
        onPressed: () {
          Navigator.of(context).pop();
          _viewModel(ref).startSelecting();
        },
        child: Text(l10n.albSelect),
      ),
      if (canEdit)
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(context).pop();
            _rename(context, ref, album);
          },
          child: Text(l10n.albRenameTitle),
        ),
      if (canDelete)
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.of(context).pop();
            _delete(context, ref);
          },
          child: Text(l10n.albDeleteTitle),
        ),
    ];
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ),
    );
  }

  Future<void> _saveSelected(BuildContext context, WidgetRef ref, List<AlbumItem> items) async {
    final l10n = AppLocalizations.of(context)!;
    if (!await _viewModel(ref).ensureAccess()) {
      if (context.mounted) showAppSnackBar(context, l10n.chaImageSaveDenied);
      return;
    }
    final result = await ref.read(loadingOverlayProvider.notifier).run(() => _viewModel(ref).saveItems(items));
    if (!context.mounted) return;
    showAppSnackBar(context, albumSaveResultMessage(l10n, result));
    if (result == ImageSaveResult.saved) _viewModel(ref).stopSelecting();
  }

  Future<void> _deleteSelected(BuildContext context, WidgetRef ref, List<AlbumItem> items) async {
    final l10n = AppLocalizations.of(context)!;
    final mine = items.where((item) => item.uploaderAccountId == myAccountId).toList();
    if (mine.isEmpty) {
      showAppSnackBar(context, l10n.albDeleteOnlyMine);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.albDeleteItemsTitle,
      message: mine.length == items.length ? l10n.albDeleteItemsMessage(mine.length) : l10n.albDeleteMineMessage(mine.length),
      confirmLabel: l10n.albDeleteConfirm,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(loadingOverlayProvider.notifier).run(() => _viewModel(ref).deleteItems(mine));
      _viewModel(ref).stopSelecting();
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, l10n.albUpdateFailed);
    }
  }

  void _openViewer(BuildContext context, List<AlbumItem> items, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AlbumViewerScreen(
          chatRoomId: chatRoomId,
          albumId: albumId,
          myAccountId: myAccountId,
          peerAccountId: peerAccountId,
          items: items,
          initialIndex: index,
        ),
      ),
    );
  }

  // ---- 画面 ----

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final albumValue = ref.watch(albumProvider(_key));
    final state = ref.watch(albumViewModelProvider(_key));
    final items = ref.watch(albumItemsProvider((chatRoomId: chatRoomId, albumId: albumId, limit: state.limit)));
    final canEdit = ref.watch(
      canEditAlbumsProvider((chatRoomId: chatRoomId, myAccountId: myAccountId, peerAccountId: peerAccountId)),
    );
    // 閉じたオフ会グループは読むだけ（削除もしない。機能仕様書4.4.9.5）
    final closedRoom = ref.watch(albumClosedRoomProvider(chatRoomId));
    final album = albumValue.value;
    final loaded = items.value ?? const <AlbumItem>[];
    final selected = loaded.where((item) => state.selectedIds.contains(item.itemId)).toList();

    if (albumValue.hasValue && album == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        appBar: const AppScreenAppBar(),
        body: EmptyStateView(message: l10n.albDeleted),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(
        title: state.selecting ? l10n.albSelectedCount(selected.length) : album?.name ?? '',
        actions: [
          if (state.selecting)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: _viewModel(ref).stopSelecting,
              child: Text(l10n.commonCancel, style: TextStyle(color: context.colors.primaryText, fontSize: 15)),
            )
          else if (album != null) ...[
            if (canEdit)
              CupertinoButton(
                key: const Key('album-add'),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: () => _add(context, ref, album),
                child: Icon(CupertinoIcons.add, color: context.colors.primaryText),
              ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: () => _openMenu(context, ref, album, canEdit: canEdit, closed: closedRoom != null),
              child: Icon(CupertinoIcons.ellipsis, color: context.colors.primaryText),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _UploadBar(albumKey: _key, myAccountId: myAccountId, peerAccountId: peerAccountId, albumName: album?.name ?? ''),
          Expanded(
            child: items.when(
              data: (list) => list.isEmpty
                  ? EmptyStateView(message: l10n.albNoItems)
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.extentAfter < 300) _viewModel(ref).loadMore(list.length);
                        return false;
                      },
                      child: GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final item = list[index];
                          return AlbumItemTile(
                            item: item,
                            selected: state.selecting ? state.selectedIds.contains(item.itemId) : null,
                            onTap: () => state.selecting
                                ? _viewModel(ref).toggle(item.itemId)
                                : _openViewer(context, list, index),
                          );
                        },
                      ),
                    ),
              loading: () => const AppLoadingIndicator(),
              error: (error, _) => ErrorRetryView(
                message: l10n.albLoadError,
                onRetry: () => ref.invalidate(
                  albumItemsProvider((chatRoomId: chatRoomId, albumId: albumId, limit: state.limit)),
                ),
              ),
            ),
          ),
          if (state.selecting)
            SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  CupertinoButton(
                    onPressed: selected.isEmpty ? null : () => _saveSelected(context, ref, selected),
                    child: Text(l10n.commonSave),
                  ),
                  if (closedRoom == null)
                    CupertinoButton(
                      onPressed: selected.isEmpty ? null : () => _deleteSelected(context, ref, selected),
                      child: Text(
                        l10n.albDeleteConfirm,
                        style: TextStyle(color: selected.isEmpty ? null : context.colors.error),
                      ),
                    ),
                ],
              ),
            )
          else if (closedRoom != null)
            MeetupClosedBar(closesAt: closedRoom.closesAt),
        ],
      ),
    );
  }
}

/// グリッドの1件
/// 動画には長さを重ねる。[selected]がnullでなければ、選択の印を重ねる
class AlbumItemTile extends StatelessWidget {
  const AlbumItemTile({super.key, required this.item, required this.onTap, this.selected});

  final AlbumItem item;
  final VoidCallback onTap;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AlbumThumbnail(path: item.thumbnailPath),
          if (item.isVideo)
            Positioned(
              right: 4,
              bottom: 4,
              child: Row(
                children: [
                  const Icon(CupertinoIcons.play_fill, size: 12, color: Colors.white),
                  const SizedBox(width: 2),
                  Text(
                    formatAlbumDuration(item.durationMs ?? 0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                    ),
                  ),
                ],
              ),
            ),
          if (selected != null) ...[
            if (selected) const ColoredBox(color: Colors.black26),
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                color: selected ? context.colors.accent : Colors.white,
                size: 22,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 動画の長さの表示（例：1:05）
String formatAlbumDuration(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// 追加の進み具合と、失敗の案内
class _UploadBar extends ConsumerWidget {
  const _UploadBar({
    required this.albumKey,
    required this.myAccountId,
    required this.peerAccountId,
    required this.albumName,
  });

  final AlbumKey albumKey;
  final String myAccountId;
  final String? peerAccountId;
  final String albumName;

  String _failureMessage(AppLocalizations l10n, AlbumAddFailure? failure) => switch (failure) {
    AlbumAddFailure.videoTooLong => l10n.albVideoTooLong,
    AlbumAddFailure.tooLarge => l10n.albFileTooLarge,
    AlbumAddFailure.unsupported => l10n.albUnsupported,
    AlbumAddFailure.rejected => l10n.albRejected,
    AlbumAddFailure.failed || null => l10n.albAddFailed,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(albumUploadViewModelProvider(albumKey));
    final viewModel = ref.read(albumUploadViewModelProvider(albumKey).notifier);
    if (state.running) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.albUploading(state.finished + 1, state.total), style: context.textStyles.captionRegular),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              key: const Key('album-upload-progress'),
              value: state.overallProgress,
              color: context.colors.accent,
            ),
          ],
        ),
      );
    }
    if (state.failedFiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${l10n.albFailedCount(state.failedFiles.length)} ${_failureMessage(l10n, state.failure)}',
              style: TextStyle(color: context.colors.error, fontSize: 12),
            ),
          ),
          if (state.canRetry)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: () =>
                  viewModel.retry(accountId: myAccountId, peerAccountId: peerAccountId, albumName: albumName),
              child: Text(l10n.albRetry, style: const TextStyle(fontSize: 13)),
            ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: viewModel.clear,
            child: Icon(CupertinoIcons.xmark, size: 16, color: context.colors.secondaryText),
          ),
        ],
      ),
    );
  }
}
