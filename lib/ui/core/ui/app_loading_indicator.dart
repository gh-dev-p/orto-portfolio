import 'package:flutter/cupertino.dart';

import '../themes/app_colors.dart';

/// 一覧系画面の読み込み中表示（`AsyncValue.when`の`loading`ケース等）で共通利用するスピナー
/// 。ブランドカラー（[AppColors.accent]）で統一する。
///
/// 画面全体を占める読み込み表示用に中央寄せで描画する。ボタン内の小さなスピナーには使わない。
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: CupertinoActivityIndicator(radius: 14, color: context.colors.accent));
  }
}
