import 'package:flutter/material.dart';

import '../../core/themes/app_metrics.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';

/// PRO-03のラベルと値の1行（例：表示名・ひとこと・ID）
/// [label]を省略すると値だけの1行になる（マイQRコードの行）
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    this.label,
    this.leadingIcon,
    required this.value,
    required this.onTap,
    this.onLongPress,
    this.showChevron = true,
  });

  final String? label;
  final IconData? leadingIcon;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: label == null ? 14 : AppMetrics.profileLabeledRowVerticalPadding,
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 20, color: context.colors.primaryText),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: label == null
                  ? Text(value, style: context.textStyles.titleMedium)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label!, style: context.textStyles.listItemLabel),
                        const SizedBox(height: 4),
                        Text(value, style: context.textStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
            ),
            if (showChevron) Icon(Icons.chevron_right, color: context.colors.secondaryText),
          ],
        ),
      ),
    );
  }
}
