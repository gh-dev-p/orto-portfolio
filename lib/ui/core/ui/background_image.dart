import 'package:flutter/material.dart';

import '../../../utils/storage_image_url.dart';
import '../themes/app_colors.dart';

/// プロフィール画面の背景画像（自分／友だち共通）。URL未設定・読み込み失敗時は
/// アクセントカラーのグラデーションにフォールバックする。
/// このアプリのStorageの画像でないURLも未設定として扱う（読み込むと端末のIPが相手に分かるため）。
class BackgroundImage extends StatelessWidget {
  const BackgroundImage({super.key, this.url});

  final String? url;

  /// Figma の対角のグラデーションは、枠の縦横比に沿って傾く（等しい色の線が右上と左下の角を結ぶ線と平行になる）。
  /// Flutter の begin・end は線と直交する向きに色が変わるので、その向きになる終点を求める。
  Alignment _gradientEnd(Size size) {
    final w2 = size.width * size.width;
    final h2 = size.height * size.height;
    return Alignment(4 * h2 / (w2 + h2) - 1, 4 * w2 / (w2 + h2) - 1);
  }

  @override
  Widget build(BuildContext context) {
    if (url == null || !isStorageImageUrl(url!)) {
      return LayoutBuilder(
        builder: (context, constraints) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: _gradientEnd(constraints.biggest),
              stops: const [0, 0.7071],
              // 画像の代わりの地なので、モードに関わらずブランド色（ライトの色）で固定する。
              colors: [AppColors.light.accent, AppColors.light.primaryText],
            ),
          ),
        ),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => ColoredBox(color: AppColors.light.primaryText),
    );
  }
}
