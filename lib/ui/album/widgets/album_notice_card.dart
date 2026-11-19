import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/message.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../view_models/album_providers.dart';
import 'album_thumbnail.dart';

/// トークに表示するアルバムの案内（機能仕様書4.4.9）
/// カバーと名前を表示し、タップでアルバムを開く。アルバムが消されていれば、その旨を表示してタップできなくする
class AlbumNoticeCard extends ConsumerWidget {
  const AlbumNoticeCard({
    super.key,
    required this.chatRoomId,
    required this.message,
    required this.onOpen,
    required this.onLongPress,
  });

  final String chatRoomId;
  final Message message;
  final ValueChanged<Message> onOpen;
  final void Function(Message message, Offset globalPosition) onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final albumId = message.albumId ?? '';
    final album = ref.watch(albumProvider((chatRoomId: chatRoomId, albumId: albumId)));
    final deleted = album.hasValue && album.value == null;
    final count = message.albumItemCount ?? 0;
    final description = message.albumEvent == AlbumEvent.created ? l10n.albNoticeCreated(count) : l10n.albNoticeAdded(count);
    return GestureDetector(
      onTap: deleted ? null : () => onOpen(message),
      onLongPressStart: (details) => onLongPress(message, details.globalPosition),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: context.colors.shadow, blurRadius: 16, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!deleted)
              AspectRatio(aspectRatio: 16 / 9, child: AlbumThumbnail(path: album.value?.coverThumbnailPath)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deleted ? l10n.albDeleted : album.value?.name ?? message.albumName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.titleMedium,
                  ),
                  if (!deleted) Text(description, style: context.textStyles.captionRegular),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
