import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../block/widgets/block_flow.dart';
import '../../chat/widgets/chat_screen.dart';
import '../../chat_list/view_models/chat_list_viewmodel.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/unread_badge.dart';
import '../../report/widgets/report_screen.dart';
import '../view_models/group_providers.dart';
import 'group_failure_message.dart';

// ============================================================
// 画面の部品
// ============================================================

/// 「グループへの招待」のまとまり（機能仕様書4.7.2.2）
/// 届いた招待をまとめ、タップで開いて「参加」「拒否」を選ぶ（トークリクエストと同じ開閉式）
class GroupRequestSection extends ConsumerWidget {
  const GroupRequestSection({super.key, required this.requests, required this.myAccountId});

  /// 届いている招待
  final List<GroupRequest> requests;

  /// 使用中のアカウントID
  final String myAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final expanded = ref.watch(groupRequestsExpandedProvider);
    return Column(
      children: [
        InkWell(
          onTap: ref.read(groupRequestsExpandedProvider.notifier).toggle,
          child: Container(
            color: context.colors.accent.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.group_add_outlined, color: context.colors.accent),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(l10n.grpRequestSectionTitle(requests.length), style: context.textStyles.titleMedium),
                ),
                // 招待は未読数として数えられないため、件数ではなく「!」を出す
                const UnreadCountBadge(count: 0, attention: true),
                const SizedBox(width: 4),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: context.colors.secondaryText),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final request in requests) _GroupRequestTile(request: request, myAccountId: myAccountId),
        const Divider(height: 1),
      ],
    );
  }
}

/// 招待1件の行
/// グループの画像・名前・人数・招待した人と、「参加」「拒否」を出す
class _GroupRequestTile extends ConsumerWidget {
  const _GroupRequestTile({required this.request, required this.myAccountId});

  final GroupRequest request;
  final String myAccountId;

  Future<void> _respond(BuildContext context, WidgetRef ref, {required bool accept}) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .respondToRequest(accountId: myAccountId, chatRoomId: request.chatRoomId, accept: accept),
          );
      if (!accept) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatRoomId: request.chatRoomId, myAccountId: myAccountId, peerAccountId: null),
        ),
      );
    } on GroupException catch (error) {
      messenger.showSnackBar(
        buildAppSnackBar(groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed)),
      );
    }
  }

  /// REP-01でこのグループを通報する（機能仕様書4.7.6）
  void _report(BuildContext context) {
    openReport(context, (
      myAccountId: myAccountId,
      targetAccountId: null,
      messageId: null,
      chatRoomId: request.chatRoomId,
      albumId: null,
      albumItemId: null,
    ));
  }

  /// 招待した人をブロックし、招待を拒否する（機能仕様書4.7.6）
  Future<void> _block(BuildContext context, WidgetRef ref) {
    return confirmAndBlockAccount(
      context: context,
      ref: ref,
      block: () async {
        await ref
            .read(blockRepositoryProvider)
            .blockAccount(accountId: myAccountId, targetAccountId: request.invitedBy);
        await ref
            .read(groupRepositoryProvider)
            .respondToRequest(accountId: myAccountId, chatRoomId: request.chatRoomId, accept: false);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final inviter = ref.watch(chatListPeerProvider(request.invitedBy));
    final inviterName = resolveDisplayName(
      inviter.account.value,
      nickname: inviter.nickname,
      unknownAccountLabel: l10n.commonUnknownAccount,
      deletedAccountLabel: l10n.commonDeletedAccount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AppAvatar(displayName: request.name, photoURL: request.photoURL, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.grpTitleWithCount(request.name, request.memberCount),
                  style: context.textStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  // 次の回の招待は、前の回のグループ名も出す（機能仕様書4.7.8.13）
                  switch (request.previousName) {
                    final previous? => l10n.grpRequestNextRound(previous, inviterName),
                    null => l10n.grpRequestInvitedBy(inviterName),
                  },
                  style: context.textStyles.captionRegular,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _respond(context, ref, accept: false),
            child: Text(l10n.grpRequestDecline, style: TextStyle(color: context.colors.secondaryText)),
          ),
          TextButton(onPressed: () => _respond(context, ref, accept: true), child: Text(l10n.grpRequestJoin)),
          PopupMenuButton<VoidCallback>(
            tooltip: l10n.grpRequestMore,
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_vert, color: context.colors.secondaryText),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(value: () => _report(context), child: Text(l10n.grpReportGroup)),
              PopupMenuItem(value: () => _block(context, ref), child: Text(l10n.grpRequestBlockInviter)),
            ],
          ),
        ],
      ),
    );
  }
}
