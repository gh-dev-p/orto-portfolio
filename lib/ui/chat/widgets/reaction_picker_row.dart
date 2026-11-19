import 'package:flutter/material.dart';

import '../../../config/reaction_emojis.dart';

/// リアクションの絵文字の選択（相手のメッセージのみ）
/// 白カードの中に収めず、ポップアップの上部に背景を透過して独立して表示する（LINE準拠。`MessageActionsMenu`とは別に、呼び出し側がPositionedで重ねる）
class ReactionPickerRow extends StatelessWidget {
  const ReactionPickerRow({super.key, required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // `InkWell`は`Material`の祖先を必須とする。この行は白カード（`MessageActionsMenu`の
    // `Material`）の外に独立して配置しているため、自前で`MaterialType.transparency`の
    // `Material`を持たせる（背景は透過のまま、インク効果だけを有効にする）。
    // 幅は外部から固定せず内容に応じて収縮させる（絵文字の実幅はフォント・端末で変動する）。
    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactionEmojis
            .map(
              (emoji) => InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onSelect(emoji),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    emoji,
                    style: const TextStyle(
                      fontSize: 26,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
