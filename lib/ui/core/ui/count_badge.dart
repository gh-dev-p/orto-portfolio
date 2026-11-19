import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

/// アイコンの右上に重ねる赤い件数バッジ（ボトムナビのトークタブ・AppHomeHeaderのアバター）。
/// 0件以下なら何も表示しない。上限なしの実数で表示する（「99+」に丸めない。機能仕様書4.4.1.2）。
/// [attention]がtrueなら、件数に関わらず「!」を表示する（グループへの招待など、未読数として数えられないもの）。
/// 一覧の行に並べる未読バッジは[UnreadCountBadge]。
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.attention = false});

  final int count;

  /// 件数より優先して「!」を表示するか
  final bool attention;

  @override
  Widget build(BuildContext context) {
    if (!attention && count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: context.colors.error,
        // 3桁以上の実数でも文字がはみ出さないよう、円ではなく角丸（1桁時は最小16pxの円に見える）
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        attention ? '!' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
