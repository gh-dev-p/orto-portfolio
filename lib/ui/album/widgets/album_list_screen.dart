import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/album_limits.dart';
import '../../../config/service_providers.dart';
import '../../../domain/models/album.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/album_media_pick.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/empty_state_view.dart';
import '../../core/ui/error_retry_view.dart';
import '../../core/ui/text_edit_sheet.dart';
import '../../group/widgets/meetup_closed_bar.dart';
import '../view_models/album_providers.dart';
import '../view_models/album_upload_viewmodel.dart';
import 'album_detail_screen.dart';
import 'album_thumbnail.dart';

/// 画面ALB-01：トークのアルバムの一覧
/// アルバムの作成と、各アルバムへの移動を行う
///
/// 機能仕様書：4.4.9 / 画面設計書：5.3.4
class AlbumListScreen extends ConsumerWidget {
  const AlbumListScreen({super.key, required this.chatRoomId, required this.myAccountId, required this.peerAccountId});

  final String chatRoomId;
  final String myAccountId;

  /// 相手のアカウントID（グループはnull）
  final String? peerAccountId;

  void _openAlbum(BuildContext context, String albumId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AlbumDetailScreen(chatRoomId: chatRoomId, albumId: albumId, myAccountId: myAccountId, peerAccountId: peerAccountId),
      ),
    );
  }

  /// 画像と動画を選び、名前を付けてアルバムを作り、追加を始める
  /// LINEと同じく、中身の無いアルバムは作らない
  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final files = await pickAlbumMediaSafely(context);
    if (files.isEmpty || !context.mounted) return;
    final name = await showTextEditSheet(
      context,
      title: l10n.albCreateTitle,
      initialValue: '',
      minLength: 1,
      maxLength: AlbumLimits.nameMaxLength,
      hintText: l10n.albNameHint,
    );
    if (name == null || !context.mounted) return;
    final String albumId;
    try {
      albumId = await ref
          .read(albumRepositoryProvider)
          .createAlbum(chatRoomId: chatRoomId, name: name, accountId: myAccountId, peerAccountId: peerAccountId);
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, l10n.albCreateFailed);
      return;
    }
    // 追加は画面を閉じても続くため、完了を待たない。
    unawaited(
      ref
          .read(albumUploadViewModelProvider((chatRoomId: chatRoomId, albumId: albumId)).notifier)
          .add(
            files: files,
            accountId: myAccountId,
            peerAccountId: peerAccountId,
            albumName: name,
            event: AlbumEvent.created,
          ),
    );
    if (context.mounted) _openAlbum(context, albumId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final albums = ref.watch(albumsProvider(chatRoomId));
    final canEdit = ref.watch(
      canEditAlbumsProvider((chatRoomId: chatRoomId, myAccountId: myAccountId, peerAccountId: peerAccountId)),
    );
    final closedRoom = ref.watch(albumClosedRoomProvider(chatRoomId));
    final atLimit = (albums.value?.length ?? 0) >= AlbumLimits.albumsPerRoom;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(
        title: l10n.albListTitle,
        actions: [
          if (canEdit)
            CupertinoButton(
              key: const Key('album-create'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: atLimit ? () => showAppSnackBar(context, l10n.albTooManyAlbums) : () => _create(context, ref),
              child: Icon(CupertinoIcons.add, color: context.colors.primaryText),
            ),
        ],
      ),
      bottomNavigationBar: closedRoom == null ? null : MeetupClosedBar(closesAt: closedRoom.closesAt),
      body: albums.when(
        data: (list) => list.isEmpty
            ? EmptyStateView(message: l10n.albEmpty)
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: list.length,
                itemBuilder: (context, index) =>
                    _AlbumTile(album: list[index], onTap: () => _openAlbum(context, list[index].albumId)),
              ),
        loading: () => const AppLoadingIndicator(),
        error: (error, _) =>
            ErrorRetryView(message: l10n.albLoadError, onRetry: () => ref.invalidate(albumsProvider(chatRoomId))),
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AlbumThumbnail(path: album.coverThumbnailPath),
            ),
          ),
          const SizedBox(height: 6),
          Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.titleMedium),
          Text(AppLocalizations.of(context)!.albItemCount(album.itemCount), style: context.textStyles.captionRegular),
        ],
      ),
    );
  }
}
