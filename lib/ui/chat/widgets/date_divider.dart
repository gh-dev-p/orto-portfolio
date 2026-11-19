import 'package:flutter/material.dart';

import '../../core/themes/app_metrics.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../../utils/date_format_utils.dart';
import '../../../l10n/app_localizations.dart';

/// メッセージ一覧の日付の区切り（画面設計書5.3.2、LINE準拠）
/// 「今日」「昨日」等の相対表記は使わず、日付そのものをグレー背景の角丸ピルで表示する
class DateDivider extends StatelessWidget {
  const DateDivider({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final localeName = AppLocalizations.of(context)!.localeName;
    return Padding(
      padding: AppMetrics.dateDividerPadding,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: context.colors.offline, borderRadius: BorderRadius.circular(999)),
          child: Text(
            formatDateDividerLabel(date, localeName),
            style: context.textStyles.captionRegular.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
