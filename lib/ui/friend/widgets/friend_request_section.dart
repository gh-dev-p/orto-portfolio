import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/friend_request.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/view_models/account_providers.dart';
import '../../block/widgets/block_flow.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/ui/unread_badge.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../group/widgets/group_system_text.dart';
import '../../profile/widgets/friend_profile_screen.dart';
import '../../report/widgets/report_screen.dart';
import '../view_models/friend_request_providers.dart';
import 'friend_request_failure_message.dart';

// ============================================================
// 画面の部品
// ============================================================

/// FRI-01の「友だち申請 {件数}件」のまとまり（機能仕様書4.3.8.2・画面設計書5.4.1）
/// 届いた申請をまとめ、タップで開いて「承認」「断る」を選ぶ（CHA-01の「グループへの招待」と同じ開閉式）
class FriendRequestSection extends ConsumerWidget {
  const FriendRequestSection({super.key, required this.requests, required this.myAccountId});

  /// 届いている申請（期限切れ・退会済み・ブロック関係を除いたもの）
  final List<FriendRequest> requests;

  /// 使用中のアカウントID
  final String myAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final expanded = ref.watch(friendRequestsExpandedProvider);
    return Column(
      children: [
        InkWell(
          key: const Key('friend-request-section'),
          onTap: ref.read(friendRequestsExpandedProvider.notifier).toggle,
          child: Container(
            color: context.colors.accent.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.person_add_alt_1_outlined, color: context.colors.accent),
                const SizedBox(width: 16),
                Expanded(child: Text(l10n.frqSectionTitle(requests.length), style: context.textStyles.titleMedium)),
                // 申請は未読数として数えないため、件数ではなく「!」を出す（グループへの招待と同じ）
                const UnreadCountBadge(count: 0, attention: true),
                const SizedBox(width: 4),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: context.colors.secondaryText),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final request in requests)
            _FriendRequestTile(key: ValueKey(request.senderAccountId), request: request, myAccountId: myAccountId),
        const Divider(height: 1),
      ],
    );
  }
}

/// 申請1件の行
/// 相手のアイコン・表示名・「「{グループ名}」から」と、「断る」「承認」「…」（通報・ブロック）を出す
class _FriendRequestTile extends ConsumerWidget {
  const _FriendRequestTile({super.key, required this.request, required this.myAccountId});

  final FriendRequest request;
  final String myAccountId;

  /// 承認する（[accept]がtrue）・断る
  /// 断るときは確認ダイアログを出す（断ったことは相手に知らせない）
  Future<void> _respond(BuildContext context, WidgetRef ref, {required bool accept, required String name}) async {
    final l10n = AppLocalizations.of(context)!;
    if (accept && ref.read(isReadOnlyProvider(myAccountId))) {
      showAppSnackBar(context, l10n.planReadOnlyNotice);
      return;
    }
    if (!accept) {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.frqDeclineTitle,
        message: l10n.frqDeclineMessage,
        confirmLabel: l10n.frqDecline,
      );
      if (!confirmed || !context.mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(friendRequestRepositoryProvider)
                .respond(accountId: myAccountId, senderAccountId: request.senderAccountId, accept: accept),
          );
      if (accept) messenger.showSnackBar(buildAppSnackBar(l10n.frqAccepted(groupPersonName(l10n, name))));
    } on FriendRequestException catch (error) {
      messenger.showSnackBar(
        buildAppSnackBar(friendRequestFailureMessage(l10n, error.failure, fallback: l10n.frqRespondFailed)),
      );
    }
  }

  /// REP-01で相手を通報する（機能仕様書4.3.6）
  void _report(BuildContext context) {
    openReport(context, (
      myAccountId: myAccountId,
      targetAccountId: request.senderAccountId,
      messageId: null,
      chatRoomId: null,
      albumId: null,
      albumItemId: null,
    ));
  }

  /// 相手をブロックする（機能仕様書4.3.4。届いた申請も同じバッチで消える）
  Future<void> _block(BuildContext context, WidgetRef ref) {
    return confirmAndBlockAccount(
      context: context,
      ref: ref,
      block: () => ref
          .read(blockRepositoryProvider)
          .blockAccount(accountId: myAccountId, targetAccountId: request.senderAccountId),
    );
  }

  /// PRO-01を開く（届いた申請があるので「承認する」を出す）
  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendProfileScreen(
          accountId: request.senderAccountId,
          myAccountId: myAccountId,
          groupChatRoomId: request.chatRoomId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(accountByIdProvider(request.senderAccountId)).value;
    // 友だちではないため、ニックネームは使わない
    final name = resolveDisplayName(
      account,
      unknownAccountLabel: l10n.commonUnknownAccount,
      deletedAccountLabel: l10n.commonDeletedAccount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openProfile(context),
              child: Row(
                children: [
                  AppAvatar(displayName: name, photoURL: account?.visiblePhotoURL, size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: context.textStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          l10n.frqFromGroup(request.groupName),
                          style: context.textStyles.captionRegular,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            key: const Key('friend-request-decline'),
            onPressed: () => _respond(context, ref, accept: false, name: name),
            child: Text(l10n.frqDecline, style: TextStyle(color: context.colors.secondaryText)),
          ),
          TextButton(
            key: const Key('friend-request-accept'),
            onPressed: () => _respond(context, ref, accept: true, name: name),
            child: Text(l10n.frqAccept),
          ),
          PopupMenuButton<VoidCallback>(
            tooltip: l10n.frqMore,
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_vert, color: context.colors.secondaryText),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(value: () => _report(context), child: Text(l10n.commonReportButton)),
              PopupMenuItem(value: () => _block(context, ref), child: Text(l10n.commonBlockButton)),
            ],
          ),
        ],
      ),
    );
  }
}
