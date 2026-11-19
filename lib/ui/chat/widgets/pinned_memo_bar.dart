import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';

/// CHA-02の上部に出す、ピン留めしたメモ（機能仕様書4.3.7）
/// 自分だけに見える。タップで相手のプロフィール（PRO-01）を開く
class PinnedMemoBar extends StatelessWidget {
  const PinnedMemoBar({super.key, required this.memo, required this.onTap});

  final String memo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.push_pin, size: 16, color: context.colors.secondaryText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(memo, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.textStyles.bodyRegular),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
