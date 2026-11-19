import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';

/// メッセージの長押しメニューの項目
/// アイコンが上・ラベルが下（`AppHomeHeader`の`_AddMenuItem`と同じレイアウト・文字の体裁）
class ActionMenuItem extends StatelessWidget {
  const ActionMenuItem({super.key, required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 20,
              child: Center(child: Icon(icon, size: 18, color: color ?? context.colors.textMutedNeutral)),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: context.textStyles.addMenuItemLabel.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
