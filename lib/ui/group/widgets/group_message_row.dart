import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/account.dart';
import '../../../domain/models/message.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat_list/view_models/chat_list_viewmodel.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import 'group_system_text.dart';

/// [accountId]の表示名（ニックネーム優先、退会済みは「退会済みアカウント」）
String groupMemberName(WidgetRef ref, AppLocalizations l10n, String accountId) {
  final peer = ref.watch(chatListPeerProvider(accountId));
  return resolveDisplayName(
    peer.account.value,
    nickname: peer.nickname,
    unknownAccountLabel: l10n.commonUnknownAccount,
    deletedAccountLabel: l10n.commonDeletedAccount,
  );
}

/// グループの、自分以外の吹き出しの行（機能仕様書4.7.3.2）
/// 送信者のアイコンと表示名を付ける。アイコンのタップで[onOpenProfile]を呼ぶ（退会済みのアカウントでは呼ばない）
class GroupMessageRow extends ConsumerWidget {
  const GroupMessageRow({super.key, required this.senderId, required this.onOpenProfile, required this.child});

  final String senderId;
  final ValueChanged<String> onOpenProfile;

  /// 吹き出し
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sender = ref.watch(chatListPeerProvider(senderId)).account.value;
    final name = groupMemberName(ref, l10n, senderId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: sender == null || sender.isDeleted ? null : () => onOpenProfile(senderId),
          child: AppAvatar(displayName: name, photoURL: sender?.visiblePhotoURL, size: 32),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: context.textStyles.captionRegular, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// グループのシステムメッセージ（中央寄せの小さな文字。機能仕様書4.7）
/// [onReport]があれば、長押しで「通報」を出す（名前・画像の変更だけ。機能仕様書4.7.3.4）
class GroupSystemMessage extends ConsumerWidget {
  const GroupSystemMessage({super.key, required this.message, this.onReport});

  final Message message;
  final VoidCallback? onReport;

  Future<void> _openMenu(BuildContext context, Offset position) async {
    final l10n = AppLocalizations.of(context)!;
    final report = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [PopupMenuItem(value: true, child: Text(l10n.repTitle))],
    );
    if (report == true) onReport?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final targetId = message.targetAccountIds.firstOrNull;
    final actorName = groupMemberName(ref, l10n, message.senderId);
    final text = groupSystemText(
      l10n,
      systemType: message.systemType,
      actorName: actorName,
      targetName: targetId == null ? actorName : groupMemberName(ref, l10n, targetId),
      groupName: message.groupName,
      hoursLeft: message.hoursLeft,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: onReport == null ? null : (details) => _openMenu(context, details.globalPosition),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: context.textStyles.captionRegular.copyWith(color: context.colors.secondaryText),
          ),
        ),
      ),
    );
  }
}
