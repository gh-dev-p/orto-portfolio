import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';

/// マイQRコードの下に置くボタン（共有・IDのコピー）
/// アイコンの下にラベルを置く（[onTap]がnullなら押せない）
class ActionButton extends StatelessWidget {
  const ActionButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.colors.primaryText),
            const SizedBox(height: 4),
            Text(label, style: context.textStyles.captionRegular),
          ],
        ),
      ),
    );
  }
}
