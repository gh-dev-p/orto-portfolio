import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_metrics.dart';
import '../../core/themes/app_text_styles.dart';
import '../../../utils/date_format_utils.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/unread_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/chat_room.dart';
import '../../../domain/models/message.dart';
import '../../chat/widgets/chat_screen.dart';
import '../../group/widgets/meetup_badge.dart';
import '../../group/widgets/meetup_status_bar.dart';

// ============================================================
// 画面の部品
// ============================================================

/// トークの1行の見た目
/// 相手のアバター・名前・最後のメッセージ・日時・未読数を出し、タップでCHA-02を開く（未読があれば背景色で強調する）
class ChatRoomTile extends StatelessWidget {
  const ChatRoomTile({
    super.key,
    required this.room,
    required this.peer,
    required this.myAccountId,
    this.nickname,
    this.senderName,
    this.systemPreview,
  });

  /// 表示するトーク
  final ChatListEntry room;

  /// 相手のアカウント
  /// 見つからなければnull（「不明なアカウント」と表示する）
  final Account? peer;

  /// 使用中のアカウントID
  final String myAccountId;

  /// 相手に付けたニックネーム
  /// 付けていれば、名前の代わりに表示する
  final String? nickname;

  /// グループの最新メッセージの送信者の表示名
  /// あればプレビューの先頭に付ける（機能仕様書4.7.3.1）
  final String? senderName;

  /// グループの最新メッセージがシステムメッセージのときのプレビュー
  final String? systemPreview;

  /// 最新メッセージのプレビュー
  String _preview(AppLocalizations l10n) {
    if (room.showsReactionPreview) return l10n.chaListReactionPreview;
    final system = systemPreview;
    if (system != null) return system;
    final text = switch (room.lastMessage?.type) {
      MessageType.image => l10n.chaImagePreviewLabel,
      MessageType.unknown => l10n.chaUnsupportedMessage,
      MessageType.sticker => l10n.chaStickerPreviewLabel,
      MessageType.album => l10n.albPreviewLabel,
      MessageType.meetupStatus => switch (room.lastMessage?.meetupStatus) {
        final status? => meetupStatusLabel(l10n, status),
        null => l10n.chaUnsupportedMessage,
      },
      _ => room.lastMessage?.text ?? '',
    };
    final sender = senderName;
    return sender == null ? text : l10n.grpPreviewWithSender(sender, text);
  }

  /// 1行を描く
  @override
  Widget build(BuildContext context) {
    final unread = room.unreadCount;
    final l10n = AppLocalizations.of(context)!;
    final name = room.isGroup
        ? l10n.grpTitleWithCount(room.name ?? '', room.memberCount)
        : resolveDisplayName(
            peer,
            nickname: nickname,
            unknownAccountLabel: l10n.commonUnknownAccount,
            deletedAccountLabel: l10n.commonDeletedAccount,
          );

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(chatRoomId: room.chatRoomId, myAccountId: myAccountId, peerAccountId: room.peerAccountId),
        ),
      ),
      child: Container(
        padding: AppMetrics.tilePadding,
        constraints: const BoxConstraints(minHeight: AppMetrics.tileHeight),
        color: unread > 0 ? context.colors.accent.withValues(alpha: 0.1) : Colors.transparent,
        child: Row(
          children: [
            AppAvatar(
              displayName: room.name ?? name,
              photoURL: room.isGroup ? room.photoURL : peer?.visiblePhotoURL,
              size: AppMetrics.avatarSize,
            ),
            const SizedBox(width: AppMetrics.avatarGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // オフ会グループは名前の横に印「オフ会」と残り日数（機能仕様書4.7.8.1）
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: context.textStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room.isMeetup) ...[const SizedBox(width: 6), MeetupBadge.forEntry(room)],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 最新メッセージより後に未読のリアクションが付いていれば、それを知らせる。
                  Text(
                    _preview(l10n),
                    style: context.textStyles.bodyRegular,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatChatTimestamp(
                    room.lastMessageAt,
                    localeName: AppLocalizations.of(context)!.localeName,
                    yesterdayLabel: AppLocalizations.of(context)!.chaListYesterday,
                  ),
                  style: context.textStyles.captionRegular,
                ),
                const SizedBox(height: 6),
                UnreadCountBadge(count: unread),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
