import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/account.dart';
import '../../../domain/models/chat_room.dart';
import '../../../domain/models/message.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat_list/view_models/chat_list_viewmodel.dart';
import '../../chat_list/widgets/chat_room_tile.dart';
import 'group_system_text.dart';

/// グループの1行
/// 最新メッセージの送信者（システムメッセージなら対象の人も）の表示名を読み、プレビューを作る（機能仕様書4.7.3.1）
class GroupRoomTileLoader extends ConsumerWidget {
  const GroupRoomTileLoader({super.key, required this.room, required this.myAccountId});

  final ChatListEntry room;
  final String myAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final last = room.lastMessage;
    String nameOf(String accountId) {
      final peer = ref.watch(chatListPeerProvider(accountId));
      return resolveDisplayName(
        peer.account.value,
        nickname: peer.nickname,
        unknownAccountLabel: l10n.commonUnknownAccount,
        deletedAccountLabel: l10n.commonDeletedAccount,
      );
    }

    if (last == null) return ChatRoomTile(room: room, peer: null, myAccountId: myAccountId);
    final senderName = nameOf(last.senderId);
    if (last.type != MessageType.system) {
      return ChatRoomTile(room: room, peer: null, myAccountId: myAccountId, senderName: senderName);
    }
    final targetId = last.targetAccountIds.firstOrNull;
    return ChatRoomTile(
      room: room,
      peer: null,
      myAccountId: myAccountId,
      systemPreview: groupSystemText(
        l10n,
        systemType: last.systemType,
        actorName: senderName,
        targetName: targetId == null ? senderName : nameOf(targetId),
        groupName: room.name,
        hoursLeft: last.hoursLeft,
      ),
    );
  }
}
