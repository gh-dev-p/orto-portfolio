import 'package:flutter/material.dart';

import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';

/// 未読メッセージ数バッジ（機能仕様書4.4.1、データ設計書3.2.4）。
/// CHA-01のチャット行・トークリクエストの未読合計、ACC-01の各Account行で共通利用する。アイコンに重ねる
/// 赤いバッジ（ボトムナビ・AppHomeHeaderのアバター）は[CountBadge]。
/// [attention]がtrueなら、件数に関わらず「!」を表示する（グループへの招待など、未読数として数えられないもの）。
class UnreadCountBadge extends StatelessWidget {
  const UnreadCountBadge({super.key, required this.count, this.attention = false});

  final int count;

  /// 件数より優先して「!」を表示するか
  final bool attention;

  @override
  Widget build(BuildContext context) {
    if (!attention && count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.accent,
        // 3桁以上の実数でも文字がはみ出さないよう、円ではなく角丸（1桁時は最小20pxの円に見える）
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      constraints: const BoxConstraints(minWidth: 20),
      child: Text(attention ? '!' : '$count', textAlign: TextAlign.center, style: context.textStyles.captionBold),
    );
  }
}
