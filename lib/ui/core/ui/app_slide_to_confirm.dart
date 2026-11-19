import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';

/// 取り消せない操作を確定するスライド（iPhoneの電源オフのスライドと同じ操作）。
///
/// つまみを右端まで動かして離したときだけ[onConfirmed]を呼ぶ。途中で離すと左端へ戻り、素早く弾いただけでは
/// 確定しない。[onConfirmed]の実行中はつまみを右端に留めて二度目の操作を受け付けず、終わったら左端へ戻す
/// （失敗の表示は呼び出し元が担う）。
///
/// スライドしにくい操作手段（VoiceOverなど）では、[semanticLabel]のボタンとして読み上げられ、
/// ダブルタップなどの実行操作でそのまま確定できる。
class AppSlideToConfirm extends StatefulWidget {
  const AppSlideToConfirm({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.enabled,
    required this.onConfirmed,
  });

  /// トラックに表示する案内（例：「スライドして退会」）
  final String label;

  /// 読み上げ用のボタン名（例：「退会する」）
  final String semanticLabel;

  /// falseの間はグレーの見た目にし、つまみを動かせない
  final bool enabled;

  /// 確定したときの処理
  final Future<void> Function() onConfirmed;

  @override
  State<AppSlideToConfirm> createState() => _AppSlideToConfirmState();
}

class _AppSlideToConfirmState extends State<AppSlideToConfirm> with SingleTickerProviderStateMixin {
  static const double _height = 56;
  static const double _thumbInset = 4;
  static const double _thumbSize = _height - _thumbInset * 2;

  /// 右端とみなす位置（0〜1）。指の細かいぶれで右端から外れても確定できるよう、わずかに余裕を持たせる
  static const double _confirmThreshold = 0.98;

  /// つまみの位置（0＝左端、1＝右端）
  late final AnimationController _position = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  bool _running = false;

  @override
  void didUpdateWidget(AppSlideToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ドラッグ中に無効になると、つまみの操作が打ち切られて途中の位置に残るため、左端へ戻す。
    if (!widget.enabled && !_running) _returnToStart();
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  // ---- 操作 ----

  void _onDragStart(DragStartDetails details) => _position.stop();

  void _onDragUpdate(DragUpdateDetails details, double travel) {
    _position.value += details.primaryDelta! / travel;
  }

  void _onDragEnd(DragEndDetails details) {
    if (_position.value >= _confirmThreshold) {
      _confirm();
    } else {
      _returnToStart();
    }
  }

  void _returnToStart() {
    if (_position.value > 0) _position.animateBack(0, curve: Curves.easeOut);
  }

  /// 確定する。実行中なら何もしない
  Future<void> _confirm() async {
    if (_running) return;
    setState(() => _running = true);
    HapticFeedback.heavyImpact();
    _position.animateTo(1, curve: Curves.easeOut);
    try {
      await widget.onConfirmed();
    } finally {
      if (mounted) {
        setState(() => _running = false);
        _returnToStart();
      }
    }
  }

  // ---- 描画 ----

  @override
  Widget build(BuildContext context) {
    final canSlide = widget.enabled && !_running;
    final colors = context.colors;
    final activeColor = widget.enabled || _running ? colors.error : colors.offline;

    return Semantics(
      container: true,
      button: true,
      enabled: canSlide,
      label: widget.semanticLabel,
      onTap: canSlide ? _confirm : null,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: _height,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(_height / 2)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final travel = constraints.maxWidth - _thumbSize - _thumbInset * 2;
              return AnimatedBuilder(
                animation: _position,
                builder: (context, _) {
                  final offset = travel * _position.value;
                  return Stack(
                    children: [
                      // つまみが通った部分の塗り
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: offset + _height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(_height / 2),
                          ),
                        ),
                      ),
                      // 案内。つまみが進むと薄れて消える
                      Positioned.fill(
                        left: _height,
                        right: _thumbInset * 2 + 8,
                        child: Opacity(
                          opacity: (1 - _position.value * 2).clamp(0, 1),
                          child: Center(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyles.captionBold.copyWith(
                                fontSize: 14,
                                color: widget.enabled ? colors.primaryText : colors.textMutedNeutral,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // つまみ。ここから動かし始めたときだけ反応する
                      Positioned(
                        left: _thumbInset + offset,
                        top: _thumbInset,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: canSlide ? _onDragStart : null,
                          onHorizontalDragUpdate: canSlide ? (details) => _onDragUpdate(details, travel) : null,
                          onHorizontalDragEnd: canSlide ? _onDragEnd : null,
                          onHorizontalDragCancel: canSlide ? _returnToStart : null,
                          child: Container(
                            width: _thumbSize,
                            height: _thumbSize,
                            decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle),
                            child: Icon(
                              _running ? Icons.check : Icons.chevron_right,
                              color: colors.onAccent,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
