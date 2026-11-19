import 'package:flutter/material.dart';

import 'press_opacity.dart';

/// 画像・カメラプレビュー等の上に重ねる、半透明の黒丸背景を持つアイコンボタン
/// （プロフィール画面の閉じる／編集、QRスキャン画面の閉じる／アルバム選択で使用）。
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 36,
    this.iconSize = 18,
    this.backgroundAlpha = 0.3,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final double backgroundAlpha;

  @override
  Widget build(BuildContext context) {
    return PressOpacity(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: backgroundAlpha), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
