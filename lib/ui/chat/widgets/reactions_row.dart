import 'package:flutter/material.dart';

import '../../core/themes/app_text_styles.dart';

/// メッセージの吹き出しの下のリアクション（画面設計書5.3.2）
/// 絵文字ごとに集計して、2人以上なら人数を付けて表示する
class ReactionsRow extends StatelessWidget {
  const ReactionsRow({super.key, required this.reactions, required this.isMine, this.onTap});

  final Map<String, String> reactions;
  final bool isMine;

  /// タップ時に呼ぶ（タップした位置を渡す）
  /// リアクションを付けられるメッセージ（相手のメッセージ）でだけ渡し、絵文字の選択を開いて変えられるようにする
  final ValueChanged<Offset>? onTap;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    final row = Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
        spacing: 4,
        children: counts.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              entry.value > 1 ? '${entry.key} ${entry.value}' : entry.key,
              style: context.textStyles.captionRegular,
            ),
          );
        }).toList(),
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => onTap(details.globalPosition),
      child: row,
    );
  }
}
