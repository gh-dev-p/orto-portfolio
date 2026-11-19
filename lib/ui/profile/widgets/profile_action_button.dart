import 'package:flutter/material.dart';

import '../../core/ui/press_opacity.dart';

/// PRO-01のプロフィール画像の下に置く丸いアイコンボタン（トーク）
/// 大きさは44px
class ProfileActionButton extends StatelessWidget {
  const ProfileActionButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressOpacity(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
