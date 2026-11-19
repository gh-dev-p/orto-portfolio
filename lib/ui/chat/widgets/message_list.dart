import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../../utils/date_format_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/message.dart';
import '../../group/widgets/group_message_row.dart';
import 'date_divider.dart';
import 'message_bubble.dart';

/// メッセージの一覧（画面設計書5.3.2）
/// 新しいメッセージを下に表示し、日付が変わるところに区切りを入れる（先頭に着いたら[onLoadMore]で過去を読み込む）
class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.hasMore,
    required this.onLoadMore,
    required this.myAccountId,
    required this.peerAccountId,
    this.groupMembers = const [],
    this.onOpenProfile,
    this.onReportSystemMessage,
    required this.scrollController,
    required this.selectableMessageId,
    required this.onRetry,
    required this.onLongPress,
    required this.onOpenImage,
    required this.onTapReactions,
    this.chatRoomId = '',
    this.onOpenAlbum,
  });

  final List<Message> messages;

  /// 表示中より過去のメッセージがまだ残っているか
  final bool hasMore;
  final VoidCallback onLoadMore;
  final String myAccountId;

  /// 相手のアカウントID（グループはnull）
  final String? peerAccountId;

  /// グループの参加者（既読の人数に使う）
  final List<GroupMember> groupMembers;

  /// グループの送信者のアイコンのタップ時に呼ぶ
  final ValueChanged<String>? onOpenProfile;

  /// グループのシステムメッセージ（名前・画像の変更）を通報するときに呼ぶ
  final ValueChanged<Message>? onReportSystemMessage;

  final ScrollController scrollController;
  final String? selectableMessageId;
  final ValueChanged<Message> onRetry;
  final void Function(Message message, Offset globalPosition) onLongPress;
  final ValueChanged<Message> onOpenImage;
  final void Function(Message message, Offset globalPosition) onTapReactions;

  /// このトークのID（アルバムの案内で使う）
  final String chatRoomId;

  /// アルバムの案内のタップ時に呼ぶ
  final ValueChanged<Message>? onOpenAlbum;

  /// グループの自分以外の吹き出しに、送信者のアイコンと表示名を付ける
  Widget _wrapGroupSender({required bool isGroup, required String senderId, required Widget child}) {
    if (!isGroup) return child;
    return GroupMessageRow(senderId: senderId, onOpenProfile: (id) => onOpenProfile?.call(id), child: child);
  }

  @override
  Widget build(BuildContext context) {
    // 「削除」済み等で表示できる件数が0でも、過去分が残っていれば読み込み表示を出して取得を続ける。
    if (messages.isEmpty && !hasMore) {
      return Center(child: Text(AppLocalizations.of(context)!.chaEmptyMessages, style: context.textStyles.description));
    }

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 画面上の最上部（reverseのため最後のindex）。ここが組み立てられた＝履歴の先頭に近づいた
        // ので、過去のメッセージを取得する。一覧が画面に収まりきらない場合もここに到達する。
        if (index == messages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.accent),
              ),
            ),
          );
        }
        final messageIndex = messages.length - 1 - index;
        final message = messages[messageIndex];
        final isMine = message.isMine(myAccountId);
        final peerId = peerAccountId;
        final isGroup = peerId == null;
        final isReadByPeer = peerId != null && message.isReadBy(peerId);
        final bubble = message.isSystem
            ? GroupSystemMessage(
                message: message,
                onReport: !isMine && const {'group_renamed', 'group_photo_changed'}.contains(message.systemType)
                    ? () => onReportSystemMessage?.call(message)
                    : null,
              )
            : _wrapGroupSender(
                isGroup: isGroup && !isMine,
                senderId: message.senderId,
                child: MessageBubble(
                  message: message,
                  isMine: isMine,
                  isReadByPeer: isReadByPeer,
                  groupReadCount: isGroup
                      ? groupReadCount(groupMembers, message.createdAt, myAccountId: myAccountId)
                      : null,
                  isSelectable: message.id == selectableMessageId,
                  onRetry: onRetry,
                  onLongPress: onLongPress,
                  onOpenImage: onOpenImage,
                  onTapReactions: onTapReactions,
                  chatRoomId: chatRoomId,
                  onOpenAlbum: onOpenAlbum,
                ),
              );

        // 日付区切りラベル（LINE準拠）：ローカル日付基準で、直前（時系列で1つ前＝
        // 画面上はこのメッセージの真上）のメッセージと日付が変わるタイミング、または
        // 履歴の先頭で表示する。
        final createdAt = message.createdAt;
        if (createdAt == null) return bubble;
        final previousCreatedAt = messageIndex > 0 ? messages[messageIndex - 1].createdAt : null;
        final showDateDivider = previousCreatedAt == null || !isSameLocalDate(createdAt, previousCreatedAt);
        if (!showDateDivider) return bubble;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DateDivider(date: createdAt),
            bubble,
          ],
        );
      },
    );
  }
}
