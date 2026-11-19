import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/date_format_utils.dart';
import '../../chat_list/view_models/chat_list_viewmodel.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/ui/error_retry_view.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../profile/widgets/friend_profile_screen.dart';
import '../view_models/group_providers.dart';
import 'group_failure_message.dart';
import 'group_message_row.dart';
import 'group_system_text.dart';

// ============================================================
// 画面
// ============================================================

/// 画面GRP-09：参加の申請（機能仕様書4.7.8.5 / 画面設計書5.10.9）
/// オフ会グループの主催チームの人が、答えを待っている申請を見て、承認・断るを選ぶ。
/// 申請は監視し、ほかの主催チームの人が答えた申請はその場で消える
class JoinRequestsScreen extends ConsumerWidget {
  const JoinRequestsScreen({super.key, required this.chatRoomId, required this.myAccountId});

  final String chatRoomId;

  /// 操作する主催チームのアカウントID
  final String myAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final requests = ref.watch(groupJoinRequestsProvider(chatRoomId));
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.grpJoinRequestsTitle),
      body: SafeArea(
        child: requests.when(
          data: (list) => _list(context, list),
          loading: () => const AppLoadingIndicator(),
          error: (_, _) => ErrorRetryView(
            message: l10n.grpJoinRequestsLoadError,
            onRetry: () => ref.invalidate(groupJoinRequestsProvider(chatRoomId)),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<GroupJoinRequest> requests) {
    final l10n = AppLocalizations.of(context)!;
    final sections = joinRequestSections(requests);
    if (sections.pending.isEmpty && sections.waitlisted.isEmpty) {
      return Center(child: Text(l10n.grpJoinRequestsEmpty, style: context.textStyles.bodyRegular));
    }
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: context.textStyles.sectionHeader),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (sections.pending.isNotEmpty) ...[
          heading(l10n.grpJoinRequestsPendingHeading(sections.pending.length)),
          for (final request in sections.pending)
            _JoinRequestCard(request: request, chatRoomId: chatRoomId, myAccountId: myAccountId),
        ],
        if (sections.waitlisted.isNotEmpty) ...[
          heading(l10n.grpJoinRequestsWaitlistHeading(sections.waitlisted.length)),
          for (final (index, request) in sections.waitlisted.indexed)
            _JoinRequestCard(
              request: request,
              chatRoomId: chatRoomId,
              myAccountId: myAccountId,
              waitlistOrder: index + 1,
            ),
        ],
      ],
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// 承認待ちの申請があるときに、主催チームの人のCHA-02の上に出す帯（機能仕様書4.7.8.5 / 画面設計書5.10.11）
/// 「参加の申請 {件数}件」。押すとGRP-09を開く。主催チームでなければ何も出さない（申請を読まない）
class JoinRequestBanner extends ConsumerWidget {
  const JoinRequestBanner({super.key, required this.chatRoomId, required this.myAccountId});

  final String chatRoomId;
  final String myAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOrganizer = ref.watch(groupRoomProvider(chatRoomId)).value?.isOrganizer(myAccountId) ?? false;
    if (!isOrganizer) return const SizedBox.shrink();
    final requests = ref.watch(groupJoinRequestsProvider(chatRoomId)).value ?? const [];
    final count = requests.where((request) => request.status == JoinStatus.pending).length;
    if (count == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Material(
      key: const Key('join-request-banner'),
      color: context.colors.accent.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JoinRequestsScreen(chatRoomId: chatRoomId, myAccountId: myAccountId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.how_to_reg_outlined, color: context.colors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.grpJoinRequestBanner(count), style: context.textStyles.bodyRegular)),
              Icon(Icons.chevron_right, color: context.colors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

/// 申請1件のカード
/// 申請した人のアイコン・表示名・申請日時、質問と答え、「断る」「承認」を出す
class _JoinRequestCard extends ConsumerWidget {
  const _JoinRequestCard({
    required this.request,
    required this.chatRoomId,
    required this.myAccountId,
    this.waitlistOrder,
  });

  final GroupJoinRequest request;
  final String chatRoomId;
  final String myAccountId;

  /// キャンセル待ちの順番（1から。承認待ちはnull）
  final int? waitlistOrder;

  Future<void> _respond(BuildContext context, WidgetRef ref, {required bool accept, required String name}) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (!accept) {
      final groupName = ref.read(groupEntryProvider((myAccountId, chatRoomId))).value?.name ?? '';
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.grpJoinRequestDeclineTitle(groupPersonName(l10n, name)),
        message: l10n.grpJoinRequestDeclineMessage(groupName),
        confirmLabel: l10n.grpJoinRequestDecline,
      );
      if (!confirmed) return;
    }
    try {
      final result = await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .respondToJoinRequest(
                  accountId: myAccountId,
                  chatRoomId: chatRoomId,
                  applicantAccountId: request.accountId,
                  accept: accept,
                ),
          );
      final message = switch (result) {
        JoinResponseResult.approved => l10n.grpJoinRequestApproved,
        JoinResponseResult.waitlisted => l10n.grpJoinRequestWaitlisted,
        JoinResponseResult.declined => null,
      };
      if (message != null) messenger.showSnackBar(buildAppSnackBar(message));
    } on GroupException catch (error) {
      // 申請が無くなっていれば、監視で一覧から消えるので知らせない
      if (error.failure == GroupFailure.joinRequestNotFound) return;
      messenger.showSnackBar(
        buildAppSnackBar(groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed)),
      );
    } catch (_) {
      messenger.showSnackBar(buildAppSnackBar(l10n.grpRequestFailed));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(chatListPeerProvider(request.accountId)).account.value;
    final name = groupMemberName(ref, l10n, request.accountId);
    final appliedAt = formatChatTimestamp(
      request.createdAt,
      localeName: l10n.localeName,
      yesterdayLabel: l10n.chaListYesterday,
    );
    final order = waitlistOrder;
    return Container(
      key: Key('join-request-${request.accountId}'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: account == null || account.isDeleted
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FriendProfileScreen(accountId: request.accountId, myAccountId: myAccountId),
                    ),
                  ),
            child: Row(
              children: [
                AppAvatar(displayName: name, photoURL: account?.visiblePhotoURL, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: context.textStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (order != null) ...[
                  Text(l10n.grpJoinRequestsWaitlistOrder(order), style: context.textStyles.captionRegular),
                  const SizedBox(width: 8),
                ],
                // キャンセル待ちから繰り上がった承認待ち（機能仕様書4.7.8.10）
                if (request.isPromoted) ...[
                  Text(
                    l10n.grpJoinRequestPromoted,
                    key: Key('join-request-promoted-${request.accountId}'),
                    style: context.textStyles.captionRegular.copyWith(color: context.colors.accent),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(appliedAt, style: context.textStyles.captionRegular),
                const SizedBox(width: 8),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (request.answers.isEmpty)
            Text(l10n.grpJoinRequestsNoQuestions, style: context.textStyles.captionRegular)
          else
            for (final answer in request.answers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(answer.question, style: context.textStyles.captionRegular),
                    const SizedBox(height: 2),
                    SelectableText(answer.answer, style: context.textStyles.bodyRegular),
                  ],
                ),
              ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _respond(context, ref, accept: false, name: name),
                child: Text(l10n.grpJoinRequestDecline, style: TextStyle(color: context.colors.secondaryText)),
              ),
              TextButton(
                onPressed: () => _respond(context, ref, accept: true, name: name),
                child: Text(l10n.grpJoinRequestApprove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// メンバーの申請の答えのシート（主催チームだけ。機能仕様書4.7.8.5 / 画面設計書5.10.3）
/// 見出しは名前、質問と答えの組、「プロフィールを見る」（[onOpenProfile]がnullなら出さない）
Future<void> showMemberJoinAnswersSheet(
  BuildContext context, {
  required String name,
  required List<JoinAnswer> answers,
  VoidCallback? onOpenProfile,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        key: const Key('member-join-answers'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: sheetContext.textStyles.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.grpMemberJoinAnswersNote, style: sheetContext.textStyles.captionRegular),
            const SizedBox(height: 12),
            for (final answer in answers)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(answer.question, style: sheetContext.textStyles.captionRegular),
                    const SizedBox(height: 2),
                    SelectableText(answer.answer, style: sheetContext.textStyles.bodyRegular),
                  ],
                ),
              ),
            if (onOpenProfile != null)
              TextButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  onOpenProfile();
                },
                child: Text(l10n.grpMemberJoinAnswersProfile),
              ),
          ],
        ),
      ),
    ),
  );
}
