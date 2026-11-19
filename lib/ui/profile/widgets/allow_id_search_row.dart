import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';

/// PRO-03の「IDによる友だち追加を許可」の行（画面設計書5.7.3 構成要素9）
/// スイッチでallowIdSearchを切り替える
class AllowIdSearchRow extends StatelessWidget {
  const AllowIdSearchRow({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.proEditAllowIdSearchTitle, style: context.textStyles.titleMedium),
                const SizedBox(height: 4),
                Text(l10n.proEditAllowIdSearchSubtitle, style: context.textStyles.bodyRegular),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(value: value, activeTrackColor: context.colors.accent, onChanged: onChanged),
        ],
      ),
    );
  }
}
