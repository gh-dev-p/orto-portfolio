import 'package:flutter/material.dart';

import '../../../config/app_flavor.dart';

/// dev flavor時のみ、画面右上にXcodeのDEBUGバナーのような斜めリボンで常時表示する警告バナー
/// （アーキテクチャ設計書6.7）。prodビルドでは[currentFlavor]がprodのため何も描画しない。
/// MaterialAppの`builder`から全画面共通で適用する想定。
class DevEnvBanner extends StatelessWidget {
  const DevEnvBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (currentFlavor != AppFlavor.dev) return child;

    return Banner(
      message: 'DEV',
      location: BannerLocation.topEnd,
      color: Colors.red,
      child: child,
    );
  }
}
