import 'package:flutter/material.dart';

import '../../core/ui/press_opacity.dart';

/// 背景画像・アバターの右下に置くアップロードのアイコン
/// Figmaのインスタンス`image_upload`に合わせる
class ImageUploadBadge extends StatelessWidget {
  const ImageUploadBadge({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressOpacity(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 14),
      ),
    );
  }
}
