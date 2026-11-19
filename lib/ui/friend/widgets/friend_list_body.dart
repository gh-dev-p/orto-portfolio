import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_metrics.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_tab_chip.dart';
import '../../core/ui/empty_state_view.dart';
import '../../core/ui/error_retry_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/friend.dart';
import '../view_models/friend_list_viewmodel.dart';
import '../view_models/friend_request_providers.dart';
import '../../group/widgets/group_list_tab.dart';
import '../../profile/widgets/friend_profile_screen.dart';
import 'add_friend_menu_screen.dart';
import 'friend_request_section.dart';

// ============================================================
// 画面
// ============================================================

/// 画面FRI-01：友だち一覧の本文（機能仕様書4.3.2 / 画面設計書5.4.1）
/// ヘッダー・ボトムナビは[HomeShell]が持つため、本Widgetはタブの本文だけを描く
class FriendListBody extends ConsumerStatefulWidget {
  const FriendListBody({super.key});

  @override
  ConsumerState<FriendListBody> createState() => _FriendListBodyState();
}

class _FriendListBodyState extends ConsumerState<FriendListBody> {
  /// 「グループ」タブを選んでいるか
  bool _showGroups = false;

  /// フィルタのタブと、友だちまたはグループの一覧を描く
  /// 読み込み中・読み込みの失敗（再試行つき）も表示する
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendListViewModelProvider);
    final myAccountId = state.myAccountId;
    final requests = ref.watch(visibleFriendRequestsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 届いた友だち申請（0件なら出さない。機能仕様書4.3.8.2）
        if (myAccountId != null && requests.isNotEmpty) ...[
          FriendRequestSection(requests: requests, myAccountId: myAccountId),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _FriendFilterTabs(
            showGroups: _showGroups,
            onChanged: (showGroups) => setState(() => _showGroups = showGroups),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _showGroups && myAccountId != null
              ? GroupListTab(myAccountId: myAccountId)
              : state.friends.when(
                  data: (friends) => _FriendList(friends: friends, myAccountId: state.myAccountId),
                  loading: () => const AppLoadingIndicator(),
                  error: (error, _) => ErrorRetryView(
                    message: AppLocalizations.of(context)!.friListLoadError,
                    onRetry: ref.read(friendListViewModelProvider.notifier).retry,
                  ),
                ),
        ),
      ],
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// フィルタのタブ（友だち・グループ）
class _FriendFilterTabs extends StatelessWidget {
  const _FriendFilterTabs({required this.showGroups, required this.onChanged});

  /// 「グループ」タブを選んでいるか
  final bool showGroups;

  /// タブを切り替えたとき
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        AppTabChip(label: l10n.friFilterTabLabel, selected: !showGroups, onTap: () => onChanged(false)),
        const SizedBox(width: 8),
        AppTabChip(label: l10n.friFilterGroupsTabLabel, selected: showGroups, onTap: () => onChanged(true)),
      ],
    );
  }
}

/// 友だちの一覧
/// 友だちが0人なら、FRI-02（友だち追加メニュー）を開くボタンつきの空の表示にする
class _FriendList extends ConsumerWidget {
  const _FriendList({required this.friends, required this.myAccountId});

  final List<Friend> friends;
  final String? myAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (myAccountId == null) {
      return const AppLoadingIndicator();
    }
    if (friends.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      // 空状態からは＋メニューを経由せず、直接FRI-02（友だち追加メニュー）を開く（画面設計書5.4.1）。
      return EmptyStateView(
        message: l10n.friListEmpty,
        actionLabel: l10n.addMenuAddFriend,
        actionIcon: Icons.person_add_alt_1_outlined,
        onAction: () => showAddFriendMenu(context, myAccountId: myAccountId!),
      );
    }

    return ListView.builder(
      padding: AppMetrics.friendListPadding,
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        final peerAsync = ref.watch(friendListPeerProvider(friend.friendAccountId));

        return peerAsync.when(
          data: (peer) => _FriendTile(friend: friend, peer: peer, myAccountId: myAccountId!),
          loading: () => const SizedBox(height: AppMetrics.tileHeight),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
    );
  }
}

/// 友だち1人分の行
/// アバター・表示名（ニックネーム優先）・ひとことを表示し、タップでPRO-01（友だちのプロフィール）を開く
class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.peer, required this.myAccountId});

  final Friend friend;
  final Account? peer;
  final String myAccountId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = resolveDisplayName(
      peer,
      nickname: friend.nickname,
      unknownAccountLabel: l10n.commonUnknownAccount,
      deletedAccountLabel: l10n.commonDeletedAccount,
    );
    final bio = peer?.visibleBio;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FriendProfileScreen(accountId: friend.friendAccountId, myAccountId: myAccountId),
        ),
      ),
      child: Container(
        padding: AppMetrics.tilePadding,
        constraints: const BoxConstraints(minHeight: AppMetrics.tileHeight),
        child: Row(
          children: [
            AppAvatar(displayName: name, photoURL: peer?.visiblePhotoURL, size: AppMetrics.avatarSize),
            const SizedBox(width: AppMetrics.avatarGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: context.textStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (bio != null && bio.isNotEmpty)
                    Text(bio, style: context.textStyles.bodyRegular, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
