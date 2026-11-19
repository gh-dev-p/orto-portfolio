import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/press_opacity.dart';

/// 読み取り・マイQRコードの切り替えの、片方のボタン
class SegmentButton extends StatelessWidget {
  const SegmentButton({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressOpacity(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: context.textStyles.captionRegular.copyWith(
            // 暗い半透明の地に白いピルを置く固定デザインのため、モードに関わらずライトの文字色で固定する。
            color: selected ? AppColors.light.primaryText : Colors.white,
          ),
        ),
      ),
    );
  }
}
