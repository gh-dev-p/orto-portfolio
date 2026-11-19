import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 全画面共通のローディングオーバーレイ。MaterialAppの`builder`から
/// Navigatorの外側に常駐させ、[visible]の間（呼び出し元がloadingOverlayProviderの実行中を渡す）、
/// ダイアログを含むすべての画面の上に、薄暗い背景とスピナーを重ねてタップをブロックする。
///
/// 表示を始めるときにフォーカスを外してキーボードを閉じる。処理の完了で入力欄の画面ごと差し替わる場合に、
/// 差し替えと同時に閉じるのではなく、画面が安定している間に閉じておくため。
class LoadingOverlayHost extends StatefulWidget {
  const LoadingOverlayHost({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  State<LoadingOverlayHost> createState() => _LoadingOverlayHostState();
}

class _LoadingOverlayHostState extends State<LoadingOverlayHost> {
  /// 処理が一瞬で終わる場合に暗転がちらつかないよう、表示を遅らせてフェードインする時間。
  /// タップのブロックは、この間も含めて表示開始と同時に効く。
  static const _fadeDuration = Duration(milliseconds: 400);

  /// 非表示から表示に変わったら、フォーカスを外してキーボードを閉じる
  @override
  void didUpdateWidget(LoadingOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.visible)
          Positioned.fill(
            child: Stack(
              children: [
                const ModalBarrier(dismissible: false, color: Colors.transparent),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: _fadeDuration,
                  curve: const Interval(0.5, 1),
                  builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black38,
                      // 暗い背景の上ではアクセント色が沈むため、白にする
                      child: const Center(child: CupertinoActivityIndicator(radius: 14, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
