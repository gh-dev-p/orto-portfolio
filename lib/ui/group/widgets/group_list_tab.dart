import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../chat_list/widgets/room_tile_loader.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/empty_state_view.dart';
import '../../core/ui/error_retry_view.dart';
import '../../chat/view_models/chat_providers.dart';
import '../view_models/group_providers.dart';
import 'group_friend_picker_screen.dart';

/// FRI-01の「グループ」タブの本文（機能仕様書4.7.3.1）
/// 参加中のグループと「グループ作成」を並べる
class GroupListTab extends ConsumerWidget {
  const GroupListTab({super.key, required this.myAccountId});

  final String myAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ref
        .watch(joinedGroupsProvider)
        .when(
          data: (groups) {
            if (groups.isEmpty) {
              return EmptyStateView(
                message: l10n.grpListEmpty,
                actionLabel: l10n.addMenuCreateGroup,
                actionIcon: Icons.group_add_outlined,
                onAction: () => openGroupCreation(context, myAccountId: myAccountId),
              );
            }
            return ListView.builder(
              itemCount: groups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.group_add_outlined),
                    title: Text(l10n.addMenuCreateGroup),
                    onTap: () => openGroupCreation(context, myAccountId: myAccountId),
                  );
                }
                return RoomTileLoader(room: groups[index - 1], myAccountId: myAccountId);
              },
            );
          },
          loading: () => const AppLoadingIndicator(),
          error: (_, _) =>
              ErrorRetryView(message: l10n.chaListLoadError, onRetry: () => ref.invalidate(chatRoomsProvider)),
        );
  }
}
