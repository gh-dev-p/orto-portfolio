import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../view_models/group_providers.dart';
import 'group_failure_message.dart';

// ============================================================
// 画面の部品
// ============================================================

/// CHA-01の「参加の申請」のまとまり（機能仕様書4.7.8.5 / 画面設計書5.10.11）
/// オフ会グループに出した申請と、その状態をまとめる（「グループへの招待」と同じ開閉式）
class JoinApplicationSection extends ConsumerWidget {
  const JoinApplicationSection({super.key, required this.applications, required this.myAccountId});

  /// 出している申請（結果が出て、まだ閉じていないものを含む）
  final List<JoinApplication> applications;

  /// 使用中のアカウントID
  final String myAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final expanded = ref.watch(joinApplicationsExpandedProvider);
    return Column(
      children: [
        InkWell(
          key: const Key('join-application-section'),
          onTap: ref.read(joinApplicationsExpandedProvider.notifier).toggle,
          child: Container(
            color: context.colors.accent.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.how_to_reg_outlined, color: context.colors.accent),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.grpApplicationSectionTitle(applications.length),
                    style: context.textStyles.titleMedium,
                  ),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: context.colors.secondaryText),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final application in applications)
            _JoinApplicationTile(application: application, myAccountId: myAccountId),
        const Divider(height: 1),
      ],
    );
  }
}

/// 申請1件の行
/// グループの画像・名前と状態、右に「取り消す」（答えを待っている申請）か「閉じる」（結果が出た申請）
class _JoinApplicationTile extends ConsumerWidget {
  const _JoinApplicationTile({required this.application, required this.myAccountId});

  final JoinApplication application;
  final String myAccountId;

  String _statusLabel(AppLocalizations l10n) => switch (application.status) {
    JoinStatus.pending || JoinStatus.approved => l10n.grpApplicationPending,
    JoinStatus.waitlisted => l10n.grpApplicationWaitlisted,
    JoinStatus.declined => l10n.grpApplicationDeclined,
    JoinStatus.closed => l10n.grpApplicationClosed,
  };

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (application.status.isOpen) {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.grpApplyCancelConfirmTitle,
        message: l10n.grpApplyCancelConfirmMessage,
        confirmLabel: l10n.grpApplyCancelConfirm,
      );
      if (!confirmed) return;
    }
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .cancelApplication(accountId: myAccountId, chatRoomId: application.chatRoomId),
          );
    } on GroupException catch (error) {
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
    final isOpen = application.status.isOpen;
    return Padding(
      key: Key('join-application-${application.chatRoomId}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AppAvatar(displayName: application.name, photoURL: application.photoURL, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.name,
                  style: context.textStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _statusLabel(l10n),
                  style: context.textStyles.captionRegular,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _cancel(context, ref),
            child: Text(
              isOpen ? l10n.grpApplyCancelConfirm : l10n.commonClose,
              style: TextStyle(color: context.colors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}
