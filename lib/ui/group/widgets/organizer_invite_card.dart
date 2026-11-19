import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../view_models/group_providers.dart';
import 'group_failure_message.dart';
import 'group_message_row.dart';
import 'group_system_text.dart';

// ============================================================
// 部品
// ============================================================

/// 主催チームへの誘いのカード（CHA-02の上。機能仕様書4.7.8.2 / 画面設計書5.10.11）
/// 誘われているときだけ「{誘った人}から、主催チームに誘われています」と［入る］［断る］を出す
class OrganizerInviteCard extends ConsumerWidget {
  const OrganizerInviteCard({super.key, required this.chatRoomId, required this.myAccountId});

  final String chatRoomId;
  final String myAccountId;

  Future<void> _respond(BuildContext context, WidgetRef ref, {required bool accept}) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .respondToOrganizerInvite(accountId: myAccountId, chatRoomId: chatRoomId, accept: accept),
          );
    } on GroupException catch (error) {
      // 誘いが無くなっていれば、監視でカードが消えるので知らせない
      if (error.failure == GroupFailure.organizerInviteNotFound) return;
      messenger.showSnackBar(
        buildAppSnackBar(groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed)),
      );
    } catch (_) {
      messenger.showSnackBar(buildAppSnackBar(l10n.grpRequestFailed));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(myGroupMemberProvider((myAccountId, chatRoomId))).value;
    final invitedBy = member?.organizerInvitedBy;
    if (invitedBy == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final inviterName = groupPersonName(l10n, groupMemberName(ref, l10n, invitedBy));
    return Container(
      key: const Key('organizer-invite-card'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.grpOrganizerInviteCard(inviterName), style: context.textStyles.bodyRegular),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _respond(context, ref, accept: false),
                child: Text(l10n.grpOrganizerInviteDecline),
              ),
              TextButton(
                onPressed: () => _respond(context, ref, accept: true),
                child: Text(l10n.grpOrganizerInviteAccept),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
