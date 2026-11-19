import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 入力欄の外をタップしたらキーボードを閉じる（アプリ全体）
///
/// Flutterの標準では、スマホのタッチ操作で入力欄の外を押してもフォーカスが外れない。[child]以下の全ての入力欄について、
/// 標準の動作を置き換える。押した時点ではスクロールかタップか分からないため、タップとして指が離れた時点で閉じる。
/// スクロールと長押しではキーボードを閉じない
///
/// 周りのボタンを押しても入力を続ける欄は、そのボタンを`TextFieldTapRegion`で囲むと入力欄の内側として扱われる
class KeyboardDismissOnTap extends StatefulWidget {
  const KeyboardDismissOnTap({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardDismissOnTap> createState() => _KeyboardDismissOnTapState();
}

class _KeyboardDismissOnTapState extends State<KeyboardDismissOnTap> {
  PointerDownEvent? _down;

  late final Map<Type, Action<Intent>> _actions = {
    EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
      onInvoke: (intent) => _down = intent.pointerDownEvent,
    ),
    EditableTextTapUpOutsideIntent: _DismissAction(isTap: _isTap),
  };

  bool _isTap(PointerUpEvent up) {
    final down = _down;
    return down != null &&
        down.pointer == up.pointer &&
        (up.position - down.position).distance <= kTouchSlop &&
        up.timeStamp - down.timeStamp < kLongPressTimeout;
  }

  @override
  Widget build(BuildContext context) => Actions(actions: _actions, child: widget.child);
}

class _DismissAction extends ContextAction<EditableTextTapUpOutsideIntent> {
  _DismissAction({required this.isTap});

  final bool Function(PointerUpEvent) isTap;

  @override
  void invoke(EditableTextTapUpOutsideIntent intent, [BuildContext? context]) {
    if (!isTap(intent.pointerUpEvent)) return;
    // 読み取り専用の欄（部分コピー中の本文等）にはキーボードが無く、フォーカスを外すと選択だけが消える。
    if (context?.findAncestorStateOfType<EditableTextState>()?.widget.readOnly ?? false) return;
    intent.focusNode.unfocus();
  }
}
