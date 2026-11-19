import 'dart:io';

import 'package:flutter/material.dart';

import '../../album/widgets/album_notice_card.dart';
import '../../group/widgets/meetup_status_bar.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../../utils/date_format_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/message.dart';
import '../../../domain/models/sticker_pack.dart';
import 'chat_image.dart';
import 'reactions_row.dart';
import 'selection_mode_text.dart';

/// メッセージの吹き出し（画面設計書5.3.2）
/// テキスト・画像と、送信時刻・既読・リアクション・送信失敗の再送アイコンを表示する
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.isReadByPeer,
    this.groupReadCount,
    required this.isSelectable,
    required this.onRetry,
    required this.onLongPress,
    required this.onOpenImage,
    required this.onTapReactions,
    this.chatRoomId = '',
    this.onOpenAlbum,
  });

  final Message message;
  final bool isMine;
  final bool isReadByPeer;

  /// グループの既読の人数（1対1はnull。0人なら表示しない。機能仕様書4.7.3.3）
  final int? groupReadCount;

  /// 部分コピー中か
  /// trueなら、本文を全選択済みの[SelectionModeText]で表示し、長押しメニューは一時的に外す（選択操作の長押し（単語の選択）とぶつからないように）
  final bool isSelectable;
  final ValueChanged<Message> onRetry;
  final void Function(Message message, Offset globalPosition) onLongPress;

  /// 画像メッセージのタップ時に呼ぶ
  /// 全画面表示（CHA-03）を開く
  final ValueChanged<Message> onOpenImage;

  /// 吹き出しの下のリアクションのタップ時に呼ぶ（相手のメッセージのみ）
  /// 絵文字の選択を開き、付けたリアクションを変える・外す
  final void Function(Message message, Offset globalPosition) onTapReactions;

  /// このメッセージのトーク（アルバムの案内で使う）
  final String chatRoomId;

  /// アルバムの案内のタップ時に呼ぶ
  /// nullならアルバムを使えない状態で、案内は非対応のメッセージとして表示する
  final ValueChanged<Message>? onOpenAlbum;

  /// 画像の枠の縦横比
  /// 極端に細長い画像で一覧が崩れないよう、表示上は範囲を制限する
  static double imageAspectRatio(Message message) {
    final width = message.imageWidth;
    final height = message.imageHeight;
    if (width == null || height == null || width <= 0 || height <= 0) return 1;
    return (width / height).clamp(0.5, 2.0);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isMine ? context.colors.onAccent : context.colors.primaryText;
    final meetupStatus = message.isMeetupStatus ? message.meetupStatus : null;
    final bubbleText = meetupStatus != null
        // 当日の定型連絡は、アイコンと太字の文言（機能仕様書4.7.8.11・画面設計書5.10.11）
        ? Row(
            key: const Key('meetup-status-bubble'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(meetupStatusIcon(meetupStatus), size: 18, color: textColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  meetupStatusLabel(AppLocalizations.of(context)!, meetupStatus),
                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          )
        : message.isUnsupported || (message.isAlbum && onOpenAlbum == null) || message.type == MessageType.meetupStatus
        ? Text(
            AppLocalizations.of(context)!.chaUnsupportedMessage,
            style: TextStyle(color: textColor, fontSize: 14, fontStyle: FontStyle.italic),
          )
        : isSelectable
        ? SelectionModeText(text: message.text, color: textColor)
        : Text(message.text, style: TextStyle(color: textColor, fontSize: 14));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              // 送信に失敗した画像（端末上のファイル）。タップで再送する（機能仕様書4.4.4.2）。
              if (message.isImage && message.isFailed && message.localImagePath != null)
                GestureDetector(
                  onTap: () => onRetry(message),
                  child: _ImageFrame(
                    child: AspectRatio(
                      aspectRatio: imageAspectRatio(message),
                      child: Image.file(
                        File(message.localImagePath!),
                        fit: BoxFit.cover,
                        color: context.colors.background.withValues(alpha: 0.4),
                        colorBlendMode: BlendMode.srcATop,
                      ),
                    ),
                  ),
                )
              // アップロード中の画像（端末上のファイル）。進み具合を重ねて表示する（画面設計書5.3.2）。
              else if (message.isUploadingImage)
                _ImageFrame(
                  child: AspectRatio(
                    aspectRatio: imageAspectRatio(message),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(message.localImagePath!), fit: BoxFit.cover),
                        const ColoredBox(color: Colors.black26),
                        Center(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              key: const Key('image-upload-progress'),
                              value: message.uploadProgress,
                              strokeWidth: 3,
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (message.isAlbum && onOpenAlbum != null)
                AlbumNoticeCard(
                  chatRoomId: chatRoomId,
                  message: message,
                  onOpen: (message) => onOpenAlbum?.call(message),
                  onLongPress: onLongPress,
                )
              else if (message.isSticker)
                GestureDetector(
                  onLongPressStart: (details) => onLongPress(message, details.globalPosition),
                  child: _StickerImage(packId: message.stickerPackId ?? '', stickerId: message.stickerId ?? ''),
                )
              else if (message.isImage && message.imagePath != null)
                GestureDetector(
                  onTap: () => onOpenImage(message),
                  onLongPressStart: (details) => onLongPress(message, details.globalPosition),
                  child: _ImageFrame(
                    child: ChatImage(path: message.imagePath!, aspectRatio: imageAspectRatio(message)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  child: GestureDetector(
                    onLongPressStart: isSelectable ? null : (details) => onLongPress(message, details.globalPosition),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMine ? context.colors.accent : context.colors.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMine ? 16 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 16),
                        ),
                        boxShadow: isMine
                            ? null
                            : [BoxShadow(color: context.colors.shadow, blurRadius: 16, offset: Offset(0, 2))],
                      ),
                      child: bubbleText,
                    ),
                  ),
                ),
            ],
          ),
          if (message.reactions.isNotEmpty)
            ReactionsRow(
              reactions: message.reactions,
              isMine: isMine,
              onTap: isMine ? null : (globalPosition) => onTapReactions(message, globalPosition),
            ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (isMine && message.isFailed)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => onRetry(message),
                    child: Tooltip(
                      message: AppLocalizations.of(context)!.chaRetryTooltip,
                      child: Icon(Icons.error_outline, size: 14, color: context.colors.error),
                    ),
                  ),
                )
              else if (isMine && message.isPending)
                Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.access_time, size: 12, color: context.colors.secondaryText),
                )
              else if (isMine && (isReadByPeer || (groupReadCount ?? 0) > 0))
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    groupReadCount == null
                        ? AppLocalizations.of(context)!.chaReadLabel
                        : AppLocalizations.of(context)!.grpReadCount(groupReadCount!),
                    style: TextStyle(color: context.colors.accent, fontSize: 11),
                  ),
                ),
              Text(
                formatMessageTime(message.createdAt, AppLocalizations.of(context)!.localeName),
                style: context.textStyles.captionRegular,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 画像の吹き出しの枠（画面設計書5.3.2.4）
/// 角丸で、幅は画面幅の6割に固定する（高さは中身の縦横比で決まる）
class _ImageFrame extends StatelessWidget {
  const _ImageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: MediaQuery.of(context).size.width * 0.6, child: child),
    );
  }
}

/// スタンプの画像（機能仕様書4.4.8）
/// 吹き出しは付けない。画像を取得できないスタンプは、代替の文言を表示する（タップで読み込み直す）
class _StickerImage extends StatelessWidget {
  const _StickerImage({required this.packId, required this.stickerId});

  final String packId;
  final String stickerId;

  static const _size = 140.0;

  @override
  Widget build(BuildContext context) {
    final unavailable = AppLocalizations.of(context)!.chaStickerUnavailable;
    final path = StickerPack.storagePath(packId, stickerId);
    return SizedBox.square(
      dimension: _size,
      child: path == null
          ? Center(
              child: Text(
                unavailable,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.secondaryText, fontSize: 14),
              ),
            )
          : ChatImage(path: path, aspectRatio: 1, fit: BoxFit.contain, errorText: unavailable),
    );
  }
}
