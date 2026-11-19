import 'package:flutter/cupertino.dart' show cupertinoTextSelectionControls;
import 'package:flutter/material.dart';

/// 部分コピー中の本文
/// 開いた時点で本文全体を選択した状態にする
///
/// `SelectableText`は外から最初の選択範囲を指定できないため、`EditableText`を直接制御する
/// 選択のハンドル・ツールバーは、OSに関わらずiOS風（`cupertinoTextSelectionControls`）にそろえる
class SelectionModeText extends StatefulWidget {
  const SelectionModeText({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  State<SelectionModeText> createState() => _SelectionModeTextState();
}

class _SelectionModeTextState extends State<SelectionModeText> {
  late final _controller = TextEditingController(text: widget.text)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.text.length);
  final _focusNode = FocusNode();
  final _editableTextKey = GlobalKey<EditableTextState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _editableTextKey.currentState?.showToolbar();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EditableText(
      key: _editableTextKey,
      controller: _controller,
      focusNode: _focusNode,
      style: TextStyle(color: widget.color, fontSize: 14),
      cursorColor: widget.color,
      backgroundCursorColor: Colors.grey,
      selectionColor: widget.color.withValues(alpha: 0.3),
      readOnly: true,
      maxLines: null,
      forceLine: false,
      showSelectionHandles: true,
      selectionControls: cupertinoTextSelectionControls,
    );
  }
}
