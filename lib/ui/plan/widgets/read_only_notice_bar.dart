import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import 'plan_screen.dart';

/// 読み取り専用（機能仕様書4.2.1.3）のあいだ、CHA-02の入力欄の代わりに出す案内
/// プランの確認（SET-07）への導線を持つ
class ReadOnlyNoticeBar extends StatelessWidget {
  const ReadOnlyNoticeBar({super.key});

  /// 案内文とボタンを描く
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        color: context.colors.surface,
        child: Row(
          children: [
            Expanded(child: Text(l10n.planReadOnlyNotice, style: context.textStyles.bodyRegular)),
            TextButton(onPressed: () => openPlanScreen(context), child: Text(l10n.planSeePlansButton)),
          ],
        ),
      ),
    );
  }
}
