import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// PRO-01の画面下部の「通報」ボタン
/// 「ブロック」ボタン（[BlockButton]）の左に並べる。実行中（[busy]）は押せない
class ReportButton extends StatelessWidget {
  const ReportButton({super.key, required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // プロフィールの背景（画像の上に暗いグラデーション）の上に置くため、白で表示する。
    return TextButton.icon(
      onPressed: busy ? null : onTap,
      style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.9)),
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: Text(AppLocalizations.of(context)!.commonReportButton),
    );
  }
}
