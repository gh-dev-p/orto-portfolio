import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_metrics.dart';
import '../../../domain/models/chat_room.dart';
import '../view_models/chat_list_viewmodel.dart';
import '../../group/widgets/group_room_tile_loader.dart';
import 'chat_room_tile.dart';

// ============================================================
// 画面の部品
// ============================================================

/// トークの1行
/// 相手の表示内容（アカウント・ニックネーム）を[chatListPeerProvider]から受け取り、[ChatRoomTile]を描く
class RoomTileLoader extends ConsumerWidget {
  const RoomTileLoader({super.key, required this.room, required this.myAccountId});

  /// 表示するトーク
  final ChatListEntry room;

  /// 使用中のアカウントID
  final String myAccountId;

  /// 相手の読み込み中は行の高さの空白、読み込みに失敗したら何も出さない
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peerAccountId = room.peerAccountId;
    if (peerAccountId == null) return GroupRoomTileLoader(room: room, myAccountId: myAccountId);
    final peer = ref.watch(chatListPeerProvider(peerAccountId));

    return peer.account.when(
      data: (account) => ChatRoomTile(room: room, peer: account, myAccountId: myAccountId, nickname: peer.nickname),
      loading: () => const SizedBox(height: AppMetrics.tileHeight),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
