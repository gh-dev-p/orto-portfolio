import 'package:flutter/material.dart';

import '../../core/ui/app_avatar.dart';
import '../../core/ui/background_image.dart';
import '../../../domain/models/account.dart';
import 'image_upload_badge.dart';

/// PRO-03の背景画像とアバターの部分（画面設計書5.7.3 構成要素2）
/// 各画像の右下のアップロードアイコンのタップでだけ、背景画像・プロフィール画像をそれぞれ変更する
class BannerAndAvatar extends StatelessWidget {
  const BannerAndAvatar({
    super.key,
    required this.account,
    required this.uploadingBackground,
    required this.uploadingPhoto,
    required this.avatarSize,
    required this.onTapBackground,
    required this.onTapAvatar,
  });

  final Account account;
  final bool uploadingBackground;
  final bool uploadingPhoto;
  final double avatarSize;
  final VoidCallback onTapBackground;
  final VoidCallback onTapAvatar;

  // Figma実測値：バナー可視高さ150px、アバターは下端から36px上（＝バナー内に完全に収まる）。
  static const _bannerHeight = 150.0;
  static const _avatarBottomInset = 36.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _bannerHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Stack(
            fit: StackFit.expand,
            children: [
              BackgroundImage(url: account.backgroundURL),
              if (uploadingBackground)
                const ColoredBox(
                  color: Colors.black38,
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: ImageUploadBadge(onTap: uploadingBackground ? null : onTapBackground),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: _avatarBottomInset,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: uploadingPhoto
                        ? SizedBox(
                            width: avatarSize,
                            height: avatarSize,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : AppAvatar(displayName: account.displayName, photoURL: account.photoURL, size: avatarSize),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: ImageUploadBadge(onTap: uploadingPhoto ? null : onTapAvatar),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
