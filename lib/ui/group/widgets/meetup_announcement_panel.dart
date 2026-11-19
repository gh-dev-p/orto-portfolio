import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/announcement.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/date_format_utils.dart';
import '../../account/view_models/account_providers.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../view_models/announcement_providers.dart';
import '../view_models/group_providers.dart';
import 'announcement_edit_screen.dart';
import 'attendance_screen.dart';
import 'group_failure_message.dart';
import 'meetup_event_screen.dart';
import 'place_link.dart';
import 'settlement_screen.dart';

// ============================================================
// 部品
// ============================================================

/// 画面を開く処理（CHA-02は、上に開いている間に届いた分を戻ってから既読にするため、自分の処理を渡す）
typedef PushRoute = Future<void> Function(Route<Object?> route);

/// オフ会グループのお知らせの枠（CHA-02の上。機能仕様書4.7.8.4 / 画面設計書5.10.11）
/// 会の日時と場所をいつも出し、ほかのお知らせはたたんで件数を出す。押すと広がる（開閉は画面を開き直すとたたむ）
class MeetupAnnouncementPanel extends ConsumerStatefulWidget {
  const MeetupAnnouncementPanel({super.key, required this.chatRoomId, required this.myAccountId, required this.push});

  final String chatRoomId;
  final String myAccountId;
  final PushRoute push;

  @override
  ConsumerState<MeetupAnnouncementPanel> createState() => _MeetupAnnouncementPanelState();
}

class _MeetupAnnouncementPanelState extends ConsumerState<MeetupAnnouncementPanel> {
  bool _expanded = false;

  /// 読み取り専用の間は、主催チームの人でも出せない（機能仕様書4.7.8.4）
  bool _blockedByReadOnly() {
    if (!ref.read(isReadOnlyProvider(widget.myAccountId))) return false;
    showAppSnackBar(context, AppLocalizations.of(context)!.planReadOnlyNotice);
    return true;
  }

  void _openEvent(GroupRoom room) {
    if (_blockedByReadOnly()) return;
    widget.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MeetupEventScreen(
          chatRoomId: widget.chatRoomId,
          myAccountId: widget.myAccountId,
          eventAt: room.eventAt,
          eventPlace: room.eventPlace,
          closeAfterDays: room.closeAfterDays,
        ),
      ),
    );
  }

  void _openEditor([Announcement? announcement]) {
    if (_blockedByReadOnly()) return;
    widget.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AnnouncementEditScreen(
          chatRoomId: widget.chatRoomId,
          myAccountId: widget.myAccountId,
          announcement: announcement,
        ),
      ),
    );
  }

  Future<void> _delete(Announcement announcement) async {
    if (_blockedByReadOnly()) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.annDeleteConfirm,
      message: l10n.annDeleteConfirmMessage,
      confirmLabel: l10n.chaMessageActionDelete,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .deleteAnnouncement(
                  accountId: widget.myAccountId,
                  chatRoomId: widget.chatRoomId,
                  announcementId: announcement.announcementId,
                ),
          );
    } on GroupException catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(groupRoomProvider(widget.chatRoomId)).value;
    if (room == null || !room.isMeetup) return const SizedBox.shrink();
    final announcements = ref.watch(meetupAnnouncementsProvider(widget.chatRoomId)).value ?? const <Announcement>[];
    // 閉じたあとは読むだけ（出す・直す・消す・日時の変更をさせない。機能仕様書4.7.8.4・4.7.8.6）
    final isOrganizer = room.isOrganizer(widget.myAccountId) && !room.isClosedAt(DateTime.now());

    return Material(
      key: const Key('meetup-announcement-panel'),
      color: context.colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MeetupEventSummary(
            eventAt: room.eventAt,
            eventPlace: room.eventPlace,
            onEdit: isOrganizer ? () => _openEvent(room) : null,
          ),
          // 出欠の行（機能仕様書4.7.8.9）。押すとGRP-11
          AttendanceRow(
            chatRoomId: widget.chatRoomId,
            myAccountId: widget.myAccountId,
            onOpen: () => widget.push(
              MaterialPageRoute(
                builder: (_) => AttendanceScreen(chatRoomId: widget.chatRoomId, myAccountId: widget.myAccountId),
              ),
            ),
          ),
          // 精算の行（機能仕様書4.7.8.12）。押すとGRP-12
          SettlementRow(
            chatRoomId: widget.chatRoomId,
            myAccountId: widget.myAccountId,
            onOpen: () => widget.push(
              MaterialPageRoute(
                builder: (_) => SettlementScreen(chatRoomId: widget.chatRoomId, myAccountId: widget.myAccountId),
              ),
            ),
          ),
          if (announcements.isNotEmpty)
            _CollapsedRow(
              count: announcements.length,
              expanded: _expanded,
              onTap: () => setState(() => _expanded = !_expanded),
            )
          else if (isOrganizer)
            _AddButton(onTap: () => _openEditor()),
          if (_expanded && announcements.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
              child: ListView(
                key: const Key('meetup-announcement-list'),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final announcement in announcements)
                    AnnouncementTile(
                      announcement: announcement,
                      onEdit: isOrganizer ? () => _openEditor(announcement) : null,
                      onDelete: isOrganizer ? () => _delete(announcement) : null,
                    ),
                  if (isOrganizer && announcements.length < announcementMaxCount)
                    _AddButton(onTap: () => _openEditor()),
                ],
              ),
            ),
          Divider(height: 1, color: context.colors.secondaryText.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}

/// 会の日時と場所（いつも出す）。[onEdit]があれば（主催チーム）右に編集のボタン
class MeetupEventSummary extends StatelessWidget {
  const MeetupEventSummary({super.key, required this.eventAt, required this.eventPlace, this.onEdit});

  final DateTime? eventAt;
  final String? eventPlace;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeName = Localizations.localeOf(context).languageCode;
    final date = eventAt;
    final place = eventPlace;
    final muted = context.textStyles.bodyRegular.copyWith(color: context.colors.secondaryText);
    final iconColor = context.colors.secondaryText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_outlined, size: 18, color: iconColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        date == null ? l10n.grpMeetupDateUndecided : formatEventDateTime(date, localeName),
                        key: const Key('meetup-event-date-text'),
                        style: date == null
                            ? muted
                            : context.textStyles.bodyRegular.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 18, color: iconColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: place == null
                          ? Text(l10n.annPlaceUndecided, style: muted)
                          : PlaceLink(place: place, maxLines: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              key: const Key('meetup-event-edit'),
              onPressed: onEdit,
              tooltip: l10n.annEventEdit,
              icon: Icon(Icons.edit_outlined, color: context.colors.primaryText),
            ),
        ],
      ),
    );
  }
}

/// たたんだお知らせの行「お知らせ {件数}件」
class _CollapsedRow extends StatelessWidget {
  const _CollapsedRow({required this.count, required this.expanded, required this.onTap});

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('meetup-announcement-toggle'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Icon(Icons.campaign_outlined, size: 18, color: context.colors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.annCollapsed(count),
                style: context.textStyles.bodyRegular.copyWith(color: context.colors.accent),
              ),
            ),
            Icon(expanded ? Icons.expand_less : Icons.expand_more, color: context.colors.secondaryText),
          ],
        ),
      ),
    );
  }
}

/// 「お知らせを追加」（主催チームだけ）
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('meetup-announcement-add'),
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: Text(AppLocalizations.of(context)!.annAdd),
      ),
    );
  }
}

/// お知らせ1件（本文・場所・最後に直した日時）。[onEdit]・[onDelete]があれば（主催チーム）「…」のメニュー
class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({super.key, required this.announcement, this.onEdit, this.onDelete});

  final Announcement announcement;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final place = announcement.place;
    final updatedAt = announcement.updatedAt ?? announcement.createdAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(announcement.text, style: context.textStyles.bodyRegular),
                if (place != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 16, color: context.colors.secondaryText),
                      const SizedBox(width: 4),
                      Flexible(child: PlaceLink(place: place)),
                    ],
                  ),
                ],
                if (updatedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.annUpdatedAt(
                      formatChatTimestamp(
                        updatedAt,
                        localeName: Localizations.localeOf(context).languageCode,
                        yesterdayLabel: l10n.chaListYesterday,
                      ),
                    ),
                    style: context.textStyles.captionRegular,
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null && onDelete != null)
            PopupMenuButton<bool>(
              key: Key('announcement-menu-${announcement.announcementId}'),
              icon: Icon(Icons.more_horiz, color: context.colors.secondaryText),
              onSelected: (isEdit) => isEdit ? onEdit!() : onDelete!(),
              itemBuilder: (context) => [
                PopupMenuItem(value: true, child: Text(l10n.annEdit)),
                PopupMenuItem(
                  value: false,
                  child: Text(l10n.chaMessageActionDelete, style: TextStyle(color: context.colors.error)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
