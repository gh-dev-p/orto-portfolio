import 'package:flutter/material.dart';

import '../../../domain/models/meetup_lifecycle.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/date_format_utils.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';

// ============================================================
// 部品
// ============================================================

/// 閉じたオフ会グループのCHA-02で、入力欄の代わりに出す案内（機能仕様書4.7.8.6・4.7.8.8）
/// 「このグループは閉じました。{日付}に記録が消えます」。閉じる日時が分からなければ前半だけ。
/// 次の回を作れる主催チームの人には、その下に［次の回を作る］（機能仕様書4.7.8.13）
class MeetupClosedBar extends StatelessWidget {
  const MeetupClosedBar({super.key, required this.closesAt, this.onCreateNextRound});

  /// 閉じた日時（記録はこの30日後に消える）
  final DateTime? closesAt;

  /// 次の回を作る（作れないときはnullで、ボタンを出さない）
  final VoidCallback? onCreateNextRound;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeName = Localizations.localeOf(context).languageCode;
    final closes = closesAt;
    final text = closes == null
        ? l10n.grpMeetupClosedNotice
        : l10n.grpMeetupClosedNoticeWithDate(formatDateDividerLabel(meetupPurgeAt(closes), localeName));
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('meetup-closed-bar'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: context.colors.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.textStyles.captionRegular.copyWith(color: context.colors.secondaryText),
            ),
            if (onCreateNextRound != null)
              TextButton.icon(
                key: const Key('meetup-closed-next-round'),
                onPressed: onCreateNextRound,
                icon: const Icon(Icons.event_repeat_outlined, size: 18),
                label: Text(l10n.nxtMenu),
              ),
          ],
        ),
      ),
    );
  }
}
