import 'package:flutter/material.dart';

import '../themes/app_text_styles.dart';

/// 一覧が0件のときに中央表示する共通の空状態文言（トーク一覧・友だち一覧・
/// ブロックリスト・アカウント一覧など）。[actionLabel]と[onAction]を渡すと、文言の下に
/// 次の操作を促すボタンを表示する（例：友だち一覧の「友だち追加」）。
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key, required this.message, this.actionLabel, this.actionIcon, this.onAction});

  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: context.textStyles.description),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
