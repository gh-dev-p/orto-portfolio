import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'action_menu_item.dart';
import 'message_action.dart';

/// メッセージの長押しメニューの白カード部分（画面設計書5.3.2）
/// アイコン上・ラベル下の項目を横に並べる（コピー・部分コピー・削除・送信取消（自分のメッセージのみ）・通報（相手のメッセージのみ））
///
/// ホーム画面の共通ヘッダーの＋メニュー（`AppHomeHeader`の`_AddMenuCard`・`_AddMenuItem`）と同じレイアウトにそろえている
/// リアクションの行はこのカードに含めず、[ReactionPickerRow]として別に表示する（LINE準拠）
class MessageActionsMenu extends StatelessWidget {
  const MessageActionsMenu({
    super.key,
    required this.isMine,
    required this.isImage,
    required this.l10n,
    required this.onSelect,
    this.canAnnounce = false,
    this.canUnsend = true,
  });

  final bool isMine;

  /// 「お知らせにする」を出すか（オフ会グループの主催チームで、テキストのメッセージ。機能仕様書4.7.8.4）
  final bool canAnnounce;

  /// 自分のメッセージに「送信取消」を出すか（閉じたオフ会グループでは出さない。機能仕様書4.7.8.6）
  final bool canUnsend;

  /// 画像メッセージか、このバージョンのアプリが知らない種類のメッセージか
  /// trueなら、本文が無いため「コピー」「部分コピー」を出さない
  final bool isImage;
  final AppLocalizations l10n;
  final ValueChanged<MessageAction> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // 幅は呼び出し側（showMessageActionsPopup）で項目数から決めているため、英語など長いラベルで収まらないときは縮小して収める
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canAnnounce)
                ActionMenuItem(
                  icon: Icons.campaign_outlined,
                  label: l10n.annMakeFromMessage,
                  onTap: () => onSelect(const MessageAction.announce()),
                ),
              if (!isImage) ...[
                ActionMenuItem(
                  icon: Icons.copy_outlined,
                  label: l10n.chaMessageActionCopy,
                  onTap: () => onSelect(const MessageAction.copy()),
                ),
                ActionMenuItem(
                  icon: Icons.content_cut,
                  label: l10n.chaMessageActionPartialCopy,
                  onTap: () => onSelect(const MessageAction.partialCopy()),
                ),
              ],
              ActionMenuItem(
                icon: Icons.delete_outline,
                label: l10n.chaMessageActionDelete,
                color: context.colors.error,
                onTap: () => onSelect(const MessageAction.delete()),
              ),
              if (isMine && canUnsend)
                ActionMenuItem(
                  icon: Icons.undo,
                  label: l10n.chaMessageActionUnsend,
                  color: context.colors.error,
                  onTap: () => onSelect(const MessageAction.unsend()),
                )
              else if (!isMine)
                ActionMenuItem(
                  icon: Icons.flag_outlined,
                  label: l10n.commonReportButton,
                  color: context.colors.error,
                  onTap: () => onSelect(const MessageAction.report()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
