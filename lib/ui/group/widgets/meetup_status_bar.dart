import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/group.dart';
import '../../../domain/models/message.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../view_models/group_providers.dart';

/// 当日の定型連絡の文言（機能仕様書4.7.8.11）。ボタン・吹き出し・トーク一覧のプレビューで同じものを出す
String meetupStatusLabel(AppLocalizations l10n, MeetupStatus status) => switch (status) {
  MeetupStatus.late => l10n.grpMeetupStatusLate,
  MeetupStatus.arrived => l10n.grpMeetupStatusArrived,
  MeetupStatus.notFound => l10n.grpMeetupStatusNotFound,
};

/// 当日の定型連絡のアイコン（遅れます：時計、着きました：ピン、見つかりません：虫眼鏡。画面設計書5.10.11）
IconData meetupStatusIcon(MeetupStatus status) => switch (status) {
  MeetupStatus.late => Icons.schedule,
  MeetupStatus.arrived => Icons.place_outlined,
  MeetupStatus.notFound => Icons.search,
};

/// オフ会グループの会の日に、入力欄の上に出す定型連絡のボタンの行（機能仕様書4.7.8.11）
/// オフ会グループでない・会の日時が未定・会の日でない・閉じたあとは何も出さない。開いている間に会の日が始まる・終わると出し入れする
class MeetupStatusBar extends ConsumerStatefulWidget {
  const MeetupStatusBar({super.key, required this.chatRoomId, required this.sending, required this.onSend, this.clock});

  final String chatRoomId;

  /// 送信中か。送信中は3つとも押せない
  final bool sending;

  /// ボタンを押したときに呼ぶ（確認なしでその場で送る）
  final ValueChanged<MeetupStatus> onSend;

  /// 今の時刻（テスト用。省略すると端末の時計）
  final DateTime Function()? clock;

  @override
  ConsumerState<MeetupStatusBar> createState() => _MeetupStatusBarState();
}

class _MeetupStatusBarState extends ConsumerState<MeetupStatusBar> {
  Timer? _timer;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 次に出し入れが変わる時刻に、もう一度描き直す
  void _scheduleNextChange(MeetupDay? day, DateTime now) {
    _timer?.cancel();
    _timer = null;
    if (day == null) return;
    final next = now.isBefore(day.start) ? day.start : (now.isBefore(day.end) ? day.end : null);
    if (next == null) return;
    _timer = Timer(next.difference(now) + const Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(groupRoomProvider(widget.chatRoomId)).value;
    final day = room?.meetupDay;
    final now = _now();
    _scheduleNextChange(day, now);
    if (day == null || now.isBefore(day.start) || !now.isBefore(day.end)) return const SizedBox.shrink();
    // 閉じたあとは出さない（CHA-02は入力欄ごと閉じた案内に替えるが、ここでも確かめる。機能仕様書4.7.8.6）
    if (room!.isClosedAt(now)) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const Key('meetup-status-bar'),
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final status in MeetupStatus.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  key: Key('meetup-status-${status.value}'),
                  avatar: Icon(meetupStatusIcon(status), size: 18, color: context.colors.accent),
                  label: Text(meetupStatusLabel(l10n, status)),
                  onPressed: widget.sending ? null : () => widget.onSend(status),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
