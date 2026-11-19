import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/meetup_lifecycle.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/date_format_utils.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import 'announcement_edit_screen.dart';
import 'group_failure_message.dart';

// ============================================================
// 画面
// ============================================================

/// 画面GRP-08：会の日時と場所、グループを閉じる日（機能仕様書4.7.8.4・4.7.8.6 / 画面設計書5.10.8）
/// 会の日時は一度決めたら未定に戻せない（期限が会の日時から数えるため）
class MeetupEventScreen extends ConsumerStatefulWidget {
  const MeetupEventScreen({
    super.key,
    required this.chatRoomId,
    required this.myAccountId,
    this.eventAt,
    this.eventPlace,
    this.closeAfterDays = meetupDefaultCloseAfterDays,
  });

  final String chatRoomId;
  final String myAccountId;

  /// 今の会の日時と場所（未定ならnull）
  final DateTime? eventAt;
  final String? eventPlace;

  /// 今のグループを閉じる日（会の何日後か）
  final int closeAfterDays;

  /// 日時の選択の刻み（分）
  static const minuteInterval = 5;

  /// 選べる日時の範囲（今より後の刻みから1年後まで）
  static ({DateTime min, DateTime max}) selectableRange(DateTime now) {
    final base = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final min = base.add(Duration(minutes: minuteInterval - base.minute % minuteInterval));
    return (min: min, max: min.add(const Duration(days: 365)));
  }

  @override
  ConsumerState<MeetupEventScreen> createState() => _MeetupEventScreenState();
}

class _MeetupEventScreenState extends ConsumerState<MeetupEventScreen> {
  late DateTime? _eventAt = widget.eventAt;
  late int _closeAfterDays = widget.closeAfterDays;
  late final _placeController = TextEditingController(text: widget.eventPlace ?? '');

  /// 会の日時・場所を決めるときは既定で通知する
  bool _notify = true;

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  /// 日時を選ぶ（iOS風の日付と時刻の選択）
  Future<void> _pickDateTime() async {
    final range = MeetupEventScreen.selectableRange(DateTime.now());
    final current = _eventAt;
    var selected = current == null || current.isBefore(range.min) || current.isAfter(range.max)
        ? range.min
        : DateTime(
            current.year,
            current.month,
            current.day,
            current.hour,
            current.minute - current.minute % MeetupEventScreen.minuteInterval,
          );
    if (selected.isBefore(range.min)) selected = range.min;
    final l10n = AppLocalizations.of(context)!;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        var value = selected;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('meetup-event-date-done'),
                  onPressed: () => Navigator.of(context).pop(value),
                  child: Text(l10n.commonSave),
                ),
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  initialDateTime: selected,
                  minimumDate: range.min,
                  maximumDate: range.max,
                  minuteInterval: MeetupEventScreen.minuteInterval,
                  use24hFormat: Localizations.localeOf(context).languageCode == 'ja',
                  onDateTimeChanged: (dateTime) => value = dateTime,
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _eventAt = picked);
  }

  /// グループを閉じる日を選ぶ（機能仕様書4.7.8.6）。会の前は翌日・3日後・1週間後、会のあとは14日後まで
  Future<void> _pickCloseDays() async {
    final eventAt = _eventAt;
    final now = DateTime.now();
    final options = eventAt == null
        ? {...meetupCloseDayChoices, _closeAfterDays}.toList()
        : meetupCloseDayOptions(eventAt: eventAt, current: _closeAfterDays, now: now);
    options.sort();
    final l10n = AppLocalizations.of(context)!;
    final localeName = Localizations.localeOf(context).languageCode;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final days in options)
                ListTile(
                  key: Key('meetup-close-days-$days'),
                  title: Text(meetupCloseDayLabel(l10n, days)),
                  subtitle: eventAt == null
                      ? null
                      : Text(formatEventDateTime(meetupClosesAt(eventAt, days), localeName)),
                  trailing: days == _closeAfterDays ? Icon(Icons.check, color: context.colors.accent) : null,
                  onTap: () => Navigator.of(sheetContext).pop(days),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _closeAfterDays = picked);
  }

  Future<void> _save() async {
    final eventAt = _eventAt;
    if (eventAt == null) return;
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .updateMeetupEvent(
                  accountId: widget.myAccountId,
                  chatRoomId: widget.chatRoomId,
                  eventAt: eventAt,
                  place: _placeController.text.trim(),
                  closeAfterDays: _closeAfterDays,
                  notify: _notify,
                ),
          );
      navigator.pop(true);
    } on GroupException catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eventAt = _eventAt;
    final localeName = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppScreenAppBar(
        title: l10n.annEventTitle,
        actions: [
          TextButton(
            key: const Key('meetup-event-save'),
            onPressed: eventAt == null ? null : _save,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              key: const Key('meetup-event-date'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event_outlined, color: context.colors.primaryText),
              title: Text(l10n.annEventDate, style: context.textStyles.bodyRegular),
              trailing: Text(
                eventAt == null ? l10n.annEventDateUnset : formatEventDateTime(eventAt, localeName),
                style: context.textStyles.bodyRegular.copyWith(
                  color: eventAt == null ? context.colors.secondaryText : context.colors.accent,
                ),
              ),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 8),
            MeetupPlaceField(controller: _placeController),
            const SizedBox(height: 8),
            Text(l10n.annEventNote, style: context.textStyles.captionRegular),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('meetup-close-days'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.timer_outlined, color: context.colors.primaryText),
              title: Text(l10n.grpCloseDayTitle, style: context.textStyles.bodyRegular),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    meetupCloseDayLabel(l10n, _closeAfterDays),
                    style: context.textStyles.bodyRegular.copyWith(color: context.colors.accent),
                  ),
                  if (eventAt != null)
                    Text(
                      formatEventDateTime(meetupClosesAt(eventAt, _closeAfterDays), localeName),
                      style: context.textStyles.captionRegular,
                    ),
                ],
              ),
              onTap: _pickCloseDays,
            ),
            Text(l10n.grpCloseDayNote, style: context.textStyles.captionRegular),
            const SizedBox(height: 8),
            NotifyMembersSwitch(value: _notify, onChanged: (value) => setState(() => _notify = value)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// enum・関数
// ============================================================

/// グループを閉じる日の言い方（機能仕様書4.7.8.6）。1・3・7日は「翌日」「3日後」「1週間後」、ほかは「会の{N}日後」
String meetupCloseDayLabel(AppLocalizations l10n, int days) => switch (days) {
  1 => l10n.grpCloseDayNextDay,
  3 => l10n.grpCloseDay3Days,
  7 => l10n.grpCloseDayWeek,
  _ => l10n.grpCloseDayN(days),
};
