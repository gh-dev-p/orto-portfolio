import 'package:flutter/material.dart';

import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';
import 'press_opacity.dart';

/// 画面下部の全幅のボタン（AUT-02・AUT-03・AUT-05・ACC-02・SET-05の確定ボタン、ACC-03の赤い削除ボタン）。
/// 処理中の表示は画面全体のローディングオーバーレイ（[LoadingOverlayHost]）が担うため、ボタン自体は持たない。
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  /// 削除・退会などの取り消せない操作のボタン。赤い背景にする。
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? context.colors.offline
        : destructive
        ? context.colors.error
        : context.colors.accent;
    return SizedBox(
      width: double.infinity,
      child: PressOpacity(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
          child: Text(label, style: context.textStyles.captionBold.copyWith(fontSize: 14)),
        ),
      ),
    );
  }
}
