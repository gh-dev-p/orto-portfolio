import 'package:flutter/material.dart';

import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';

/// チャット一覧／友達一覧のフィルタタブに使う共通のピル型チップ（Figmaデザイン準拠）。
class AppTabChip extends StatelessWidget {
  const AppTabChip({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.primaryText, width: 0.1),
        color: selected ? context.colors.primaryText : context.colors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: selected
            ? null
            : [BoxShadow(color: context.colors.shadow, blurRadius: 32, offset: Offset(0, 4))],
      ),
      child: Text(
        label,
        style: context.textStyles.tabLabel.copyWith(
          color: selected ? context.colors.surface : context.colors.primaryText.withValues(alpha: 0.5),
        ),
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: chip);
  }
}
