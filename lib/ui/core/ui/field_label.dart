import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

/// 入力欄の上に置く見出し（iOS風）
/// 見出しは欄の外に固定で出し、欄の中には薄いグレーの見本（hintText）だけを出す
/// （Materialの`labelText`は欄の中で本文と同じように見え、入力済みの文字と区別しにくいため使わない）
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    // 中央寄せの画面（ACC-02等）でも欄の左端にそろえる
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.secondaryText),
        ),
      ),
    );
  }
}
