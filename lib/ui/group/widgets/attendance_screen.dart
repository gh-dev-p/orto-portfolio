import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/date_format_utils.dart';
import '../../account/view_models/account_providers.dart';
import '../../chat_list/view_models/chat_list_viewmodel.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../profile/widgets/friend_profile_screen.dart';
import '../view_models/group_providers.dart';
import 'group_failure_message.dart';
import 'group_message_row.dart';
import 'meetup_event_screen.dart';

// ============================================================
// 画面
// ============================================================

/// 画面GRP-11：出欠（機能仕様書4.7.8.9 / 画面設計書5.10.12）
/// 自分の答え・締切・全員の答えを出す。主催チームの人は締切を決め、未回答の人に催促する
class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key, required this.chatRoomId, required this.myAccountId});

  final String chatRoomId;
  final String myAccountId;

  /// 締切を選ぶ（日時の選択と「締切なしにする」）。選んだ締切（なしならnull）を返し、閉じたらnull（[changed]がfalse）
  Future<({bool changed, DateTime? deadline})> _pickDeadline(BuildContext context, GroupRoom room) async {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final min = MeetupEventScreen.selectableRange(now).min;
    final latest = attendanceDeadlineLatest(room.eventAt, now);
    final max = latest.isBefore(min) ? min : latest;
    final current = room.attendanceDeadline;
    final initial = current == null || current.isBefore(min) || current.isAfter(max) ? max : current;
    var value = initial;
    final result = await showModalBottomSheet<({DateTime? deadline})>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TextButton(
                  key: const Key('attendance-deadline-clear'),
                  onPressed: () => Navigator.of(sheetContext).pop((deadline: null)),
                  child: Text(l10n.attDeadlineClear),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('attendance-deadline-done'),
                  onPressed: () => Navigator.of(sheetContext).pop((deadline: value)),
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                initialDateTime: initial,
                minimumDate: min,
                maximumDate: max,
                minuteInterval: MeetupEventScreen.minuteInterval,
                use24hFormat: Localizations.localeOf(sheetContext).languageCode == 'ja',
                onDateTimeChanged: (dateTime) => value = dateTime,
              ),
            ),
          ],
        ),
      ),
    );
    return (changed: result != null, deadline: result?.deadline);
  }

  Future<void> _editDeadline(BuildContext context, WidgetRef ref, GroupRoom room) async {
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(isReadOnlyProvider(myAccountId))) {
      showAppSnackBar(context, l10n.planReadOnlyNotice);
      return;
    }
    final picked = await _pickDeadline(context, room);
    if (!picked.changed || !context.mounted) return;
    if (picked.deadline == room.attendanceDeadline) return;
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .updateAttendanceDeadline(accountId: myAccountId, chatRoomId: chatRoomId, deadline: picked.deadline),
          );
      if (context.mounted) showAppSnackBar(context, l10n.attDeadlineUpdated);
    } on GroupException catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(context, groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed));
    }
  }

  Future<void> _remind(BuildContext context, WidgetRef ref, int unanswered) async {
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(isReadOnlyProvider(myAccountId))) {
      showAppSnackBar(context, l10n.planReadOnlyNotice);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.attRemindConfirm(unanswered),
      message: l10n.attRemindConfirmMessage,
      confirmLabel: l10n.attRemindSend,
    );
    if (!confirmed || !context.mounted) return;
    try {
      final count = await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref.read(groupRepositoryProvider).remindAttendance(accountId: myAccountId, chatRoomId: chatRoomId),
          );
      if (context.mounted) showAppSnackBar(context, l10n.attReminded(count));
    } on GroupException catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(context, groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final room = ref.watch(groupRoomProvider(chatRoomId)).value;
    final summary = ref.watch(attendanceSummaryProvider((myAccountId, chatRoomId)));
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.attTitle),
      body: SafeArea(
        child: room == null || summary == null ? const AppLoadingIndicator() : _body(context, ref, room, summary),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, GroupRoom room, AttendanceSummary summary) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    // 閉じたあと（機能仕様書4.7.8.6）は読むだけ。答える・締切・催促のボタンを出さない
    final closed = room.isClosedAt(now);
    final isOrganizer = room.isOrganizer(myAccountId) && !closed;
    final deadline = room.attendanceDeadline;
    final localeName = Localizations.localeOf(context).languageCode;
    final passed = isAttendanceDeadlinePassed(deadline, now);
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: context.textStyles.sectionHeader),
    );
    return ListView(
      key: const Key('attendance-screen'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        heading(l10n.attMyResponse),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AttendanceButtons(
            chatRoomId: chatRoomId,
            myAccountId: myAccountId,
            current: summary.responseOf(myAccountId),
            expanded: true,
            enabled: !closed,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          key: const Key('attendance-deadline'),
          leading: Icon(Icons.alarm_outlined, color: context.colors.primaryText),
          title: Text(l10n.attDeadlineLabel, style: context.textStyles.bodyRegular),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                deadline == null
                    ? l10n.attDeadlineNone
                    : [formatEventDateTime(deadline, localeName), if (passed) l10n.attDeadlinePassed].join(' '),
                style: context.textStyles.bodyRegular.copyWith(
                  color: deadline == null ? context.colors.secondaryText : context.colors.primaryText,
                ),
              ),
              if (isOrganizer) Icon(Icons.chevron_right, color: context.colors.secondaryText),
            ],
          ),
          onTap: isOrganizer ? () => _editDeadline(context, ref, room) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            [l10n.attNote, if (deadline != null && !passed && !closed) l10n.attNoteAuto].join(''),
            style: context.textStyles.captionRegular,
          ),
        ),
        if (isOrganizer)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: OutlinedButton.icon(
              key: const Key('attendance-remind'),
              onPressed: summary.unanswered.isEmpty ? null : () => _remind(context, ref, summary.unanswered.length),
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(l10n.attRemind),
            ),
          ),
        heading(l10n.attSectionYes(summary.yes.length)),
        for (final id in summary.yes) _MemberRow(accountId: id, myAccountId: myAccountId, chatRoomId: chatRoomId),
        heading(l10n.attSectionNo(summary.no.length)),
        for (final id in summary.no) _MemberRow(accountId: id, myAccountId: myAccountId, chatRoomId: chatRoomId),
        heading(l10n.attSectionUnanswered(summary.unanswered.length)),
        for (final id in summary.unanswered)
          _MemberRow(accountId: id, myAccountId: myAccountId, chatRoomId: chatRoomId),
      ],
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// 出欠の行（CHA-02のお知らせの枠の中。機能仕様書4.7.8.9）
/// 集計と締切、自分の答えのボタン。ボタン以外を押すとGRP-11
class AttendanceRow extends ConsumerWidget {
  const AttendanceRow({super.key, required this.chatRoomId, required this.myAccountId, required this.onOpen});

  final String chatRoomId;
  final String myAccountId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final room = ref.watch(groupRoomProvider(chatRoomId)).value;
    final summary = ref.watch(attendanceSummaryProvider((myAccountId, chatRoomId)));
    if (room == null || summary == null) return const SizedBox.shrink();
    final deadline = room.attendanceDeadline;
    final localeName = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();
    final passed = isAttendanceDeadlinePassed(deadline, now);
    return InkWell(
      key: const Key('attendance-row'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
        child: Row(
          children: [
            Icon(Icons.how_to_reg_outlined, size: 18, color: context.colors.secondaryText),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.attSummary(summary.yes.length, summary.no.length, summary.unanswered.length),
                    key: const Key('attendance-summary'),
                    style: context.textStyles.bodyRegular,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (deadline != null)
                    Text(
                      [
                        l10n.attDeadlineAt(formatEventDateTime(deadline, localeName)),
                        if (passed) l10n.attDeadlinePassed,
                      ].join(' '),
                      style: context.textStyles.captionRegular,
                    ),
                ],
              ),
            ),
            AttendanceButtons(
              chatRoomId: chatRoomId,
              myAccountId: myAccountId,
              current: summary.responseOf(myAccountId),
              // 閉じたあと（機能仕様書4.7.8.6）は答えを見せるだけ
              enabled: !room.isClosedAt(now),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自分の答えのボタン［参加］［不参加］。答えたほうを塗りつぶす。押すとすぐ保存する（確認は出さない）
class AttendanceButtons extends ConsumerStatefulWidget {
  const AttendanceButtons({
    super.key,
    required this.chatRoomId,
    required this.myAccountId,
    required this.current,
    this.expanded = false,
    this.enabled = true,
  });

  final String chatRoomId;
  final String myAccountId;

  /// 今の答え（未回答ならnull）
  final AttendanceResponse? current;

  /// 横いっぱいに広げるか（GRP-11）
  final bool expanded;

  /// 押せるか（閉じたオフ会グループでは押せない。答えは塗って見せる）
  final bool enabled;

  @override
  ConsumerState<AttendanceButtons> createState() => _AttendanceButtonsState();
}

class _AttendanceButtonsState extends ConsumerState<AttendanceButtons> {
  /// 保存中の答え（監視で反映されるまでの間、押した答えを塗る）
  AttendanceResponse? _saving;

  Future<void> _answer(AttendanceResponse response) async {
    if (_saving != null || response == widget.current) return;
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(isReadOnlyProvider(widget.myAccountId))) {
      showAppSnackBar(context, l10n.grpErrorReadOnly);
      return;
    }
    setState(() => _saving = response);
    try {
      await ref
          .read(groupRepositoryProvider)
          .setAttendance(accountId: widget.myAccountId, chatRoomId: widget.chatRoomId, response: response);
    } on GroupException catch (error) {
      if (mounted) {
        showAppSnackBar(context, groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed));
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = _saving ?? widget.current;
    Widget button(AttendanceResponse response, String label) {
      final isSelected = selected == response;
      final onPressed = widget.enabled ? () => _answer(response) : null;
      final child = Text(label);
      final style = ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
      );
      final buttonWidget = isSelected
          ? FilledButton(key: Key('attendance-${response.value}'), onPressed: onPressed, style: style, child: child)
          : OutlinedButton(key: Key('attendance-${response.value}'), onPressed: onPressed, style: style, child: child);
      return widget.expanded ? Expanded(child: buttonWidget) : buttonWidget;
    }

    return Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        button(AttendanceResponse.yes, l10n.attYes),
        const SizedBox(width: 8),
        button(AttendanceResponse.no, l10n.attNo),
      ],
    );
  }
}

/// GRP-11の一覧の1人（アイコンと表示名。タップでPRO-01）
class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.accountId, required this.myAccountId, required this.chatRoomId});

  final String accountId;
  final String myAccountId;

  /// 出欠を取っているグループ。友だちでないメンバーには、友だち追加ではなく友だち申請を出す
  final String chatRoomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(chatListPeerProvider(accountId)).account.value;
    final name = groupMemberName(ref, l10n, accountId);
    final canOpen = accountId != myAccountId && account != null && !account.isDeleted;
    return ListTile(
      key: Key('attendance-member-$accountId'),
      leading: AppAvatar(displayName: name, photoURL: account?.visiblePhotoURL, size: 36),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodyRegular),
      onTap: canOpen
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    FriendProfileScreen(accountId: accountId, myAccountId: myAccountId, groupChatRoomId: chatRoomId),
              ),
            )
          : null,
    );
  }
}
