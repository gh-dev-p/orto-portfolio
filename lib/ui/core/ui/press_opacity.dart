import 'package:flutter/material.dart';

/// 不透明な塗りの部品のタップ領域。押している間だけ部品全体を薄くする（iOSのボタン風）。
/// [InkWell]のハイライトは子の下に描かれ、塗りに隠れて見えないため、押下の反応をここで出す。
class PressOpacity extends StatefulWidget {
  const PressOpacity({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<PressOpacity> createState() => _PressOpacityState();
}

class _PressOpacityState extends State<PressOpacity> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      highlightColor: Colors.transparent,
      onTap: widget.onTap,
      onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 1,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
