import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_metrics.dart';
import '../../../l10n/app_localizations.dart';

/// PRO-01の画面下部の「ブロック」ボタン
/// 実行中（[busy]）は押せない
class BlockButton extends StatelessWidget {
  const BlockButton({super.key, required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: busy ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: context.colors.error,
        minimumSize: const Size(0, AppMetrics.blockButtonHeight),
      ),
      icon: const Icon(Icons.block, size: 18),
      label: Text(AppLocalizations.of(context)!.commonBlockButton),
    );
  }
}
