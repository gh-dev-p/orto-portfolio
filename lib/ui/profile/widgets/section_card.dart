import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';

/// PRO-03・SET-01の行をまとめるカード
/// iOSの設定画面風の、白い背景のセクション
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // ColoredBoxで塗ると、行のInkWellの波紋がこの面の下に描かれて見えなくなるため、Materialで塗る
    return Material(
      color: context.colors.surface,
      child: Column(children: children),
    );
  }
}
