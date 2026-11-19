import 'package:flutter/material.dart';

import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';

/// ホーム（[AppHomeHeader]）以外の画面共通の`AppBar`。
///
/// 戻る／タイトル／閉じるの3要素を持つが、画面ごとに内容や表示有無が異なる
/// （例：`title`のみの画面、閉じるボタンを持つ画面、タイトルにアバター等を
/// 含めたい画面）ため、`title`（文字列）と`titleWidget`（カスタムWidget）の
/// どちらも受け付ける。プロフィール画像やQR等のフルブリード画面上の閉じる
/// ボタン、モーダルボトムシートのヘッダーは`Scaffold.appBar`の枠組みに乗らない
/// ため対象外（各画面で個別実装のまま）。
class AppScreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppScreenAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.backgroundColor,
    this.centerTitle = true,
    this.showBackButton = true,
    this.onClose,
    this.actions,
    this.titleSpacing,
  }) : assert(title == null || titleWidget == null, 'titleとtitleWidgetは同時に指定できません');

  final String? title;
  final Widget? titleWidget;
  /// 省略時は画面の背景色（[AppColors.background]）。
  final Color? backgroundColor;
  final bool centerTitle;
  final bool showBackButton;
  final VoidCallback? onClose;
  final List<Widget>? actions;
  final double? titleSpacing;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? context.colors.background,
      elevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: showBackButton,
      titleSpacing: titleSpacing,
      title: titleWidget ?? (title != null ? Text(title!, style: context.textStyles.h1) : null),
      actions: [
        ...?actions,
        if (onClose != null) IconButton(icon: const Icon(Icons.close), onPressed: onClose),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
