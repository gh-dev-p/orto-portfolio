import 'package:flutter/material.dart';

import '../../../domain/models/chat_room.dart';
import '../../../domain/models/meetup_lifecycle.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';

// ============================================================
// 部品
// ============================================================

/// 小さな印（「オフ会」「主催」など）。背景はアクセント色を薄くしたもの
class GroupLabelChip extends StatelessWidget {
  const GroupLabelChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: context.colors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: context.textStyles.captionRegular.copyWith(color: context.colors.accent, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// オフ会グループの印「オフ会」と、閉じるまでの残り日数（機能仕様書4.7.8.1）
/// CHA-01の行・CHA-02のヘッダー・GRP-03の名前の横に出す。
/// [daysLeft]は閉じるまでの残り日数で、会の日時が決まるまではnull（「日時未定」）。閉じたあと（[isClosed]）は「終了」
class MeetupBadge extends StatelessWidget {
  const MeetupBadge({super.key, this.daysLeft, this.isClosed = false});

  /// トーク一覧の行（[entry]）の閉じる日時から、今の残り日数を出す（機能仕様書4.7.8.6）
  factory MeetupBadge.forEntry(ChatListEntry entry, {Key? key, DateTime? now}) {
    final at = now ?? DateTime.now();
    return MeetupBadge(
      key: key,
      daysLeft: meetupDaysLeft(closesAt: entry.closesAt, closedAt: entry.closedAt, now: at),
      isClosed: entry.isClosedAt(at),
    );
  }

  final int? daysLeft;
  final bool isClosed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final days = daysLeft;
    final label = isClosed
        ? l10n.grpMeetupClosed
        : (days == null ? l10n.grpMeetupDateUndecided : l10n.grpMeetupDaysLeft(days));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GroupLabelChip(label: l10n.grpMeetupBadge),
        const SizedBox(width: 6),
        Text(label, style: context.textStyles.captionRegular.copyWith(color: context.colors.secondaryText)),
      ],
    );
  }
}
