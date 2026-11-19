import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';
import '../../../utils/validators.dart';

/// ヘッダーの高さ（iOSのナビゲーションバーと同じ）。
const double _headerHeight = 44;

/// 入力欄の角丸（iOSのグループ化された行と同じ）。
const double _fieldRadius = 12;

/// シートの左右の余白。
const double _horizontalPadding = 16;

/// 表示名・ひとこと・ニックネーム・メモ等のテキストを編集するiOS風のシートを開く。
/// キーボードと一緒に画面下からせり上がる。上部に「キャンセル」「保存」を置き、
/// 保存したら前後の空白を除いた文字列を、キャンセル・シート外タップ・下スワイプの場合はnullを返す。
///
/// 保存ボタンは入力（前後空白を除いた文字数）が[minLength]〜[maxLength]の範囲内で、
/// かつ[initialValue]から変わっているときのみ有効。
/// ニックネームのように空文字を「未設定に戻す」として許可したい場合は[minLength]を0にする。
/// 長めの文章を入れる項目は[maxLines]を増やすと、入力欄がその行数の高さの欄になる。
Future<String?> showTextEditSheet(
  BuildContext context, {
  required String title,
  required String initialValue,
  required int maxLength,
  int minLength = 0,
  required String hintText,
  int maxLines = 1,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // iOSのグループ化されたフォームのように、シートを画面背景色、入力欄を面の色にする。
    backgroundColor: context.colors.background,
    // テーマのつまみは上下の余白が大きいため、シートの中身の側で詰めて描く。
    showDragHandle: false,
    builder: (_) => _TextEditSheet(
      title: title,
      initialValue: initialValue,
      maxLength: maxLength,
      minLength: minLength,
      hintText: hintText,
      maxLines: maxLines,
    ),
  );
}

/// コントローラーの寿命をこの[State]自身に持たせることで、シートの退場アニメーション中に
/// 破棄済みコントローラーが参照される事故を防ぐ（呼び出し側でシートを閉じた直後にdisposeすると、
/// 退場トランジション中のTextFieldがまだ購読しているため"used after being disposed"例外が発生する）。
class _TextEditSheet extends StatefulWidget {
  const _TextEditSheet({
    required this.title,
    required this.initialValue,
    required this.maxLength,
    required this.minLength,
    required this.hintText,
    required this.maxLines,
  });

  final String title;
  final String initialValue;
  final int maxLength;
  final int minLength;
  final String hintText;
  final int maxLines;

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 文字数が範囲内で、最初の値から変わっているときだけ保存できる。
  /// 値のある項目を空にして消す操作は、変更として保存できる。
  bool get _canSave =>
      _controller.text.trim() != widget.initialValue.trim() &&
      isValidTrimmedLength(_controller.text, minLength: widget.minLength, maxLength: widget.maxLength);

  void _save() {
    if (_canSave) Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final sheetTheme = Theme.of(context).bottomSheetTheme;
    final mediaQuery = MediaQuery.of(context);
    final multiline = widget.maxLines > 1;

    return Padding(
      // キーボードの高さ分だけ持ち上げ、シートがキーボードの真上に乗るようにする。
      // 余白タップでキーボードを閉じたときは、ホームインジケーターの上に収める。
      padding: EdgeInsets.only(bottom: math.max(mediaQuery.viewInsets.bottom, mediaQuery.viewPadding.bottom)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // つまみ
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
              child: Container(
                width: sheetTheme.dragHandleSize?.width,
                height: sheetTheme.dragHandleSize?.height,
                decoration: ShapeDecoration(color: sheetTheme.dragHandleColor, shape: const StadiumBorder()),
              ),
            ),
          ),

          // ヘッダー（キャンセル／タイトル／保存）
          // 入力欄が収まらない高さでも、ヘッダーは隠れない。
          SizedBox(
            height: _headerHeight,
            child: NavigationToolbar(
              leading: _HeaderButton(label: l10n.commonCancel, onPressed: () => Navigator.of(context).pop()),
              middle: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.titleBold,
              ),
              trailing: _HeaderButton(label: l10n.commonSave, emphasized: true, onPressed: _canSave ? _save : null),
              middleSpacing: 8,
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(_horizontalPadding, 8, _horizontalPadding, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoTextField(
                    controller: _controller,
                    maxLength: widget.maxLength,
                    minLines: widget.maxLines,
                    maxLines: widget.maxLines,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    onChanged: (_) => setState(() {}),
                    placeholder: widget.hintText,
                    // 文章の欄（iOSのメモ等）には全消去ボタンを置かない。
                    clearButtonMode: multiline ? OverlayVisibilityMode.never : OverlayVisibilityMode.editing,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    cursorColor: colors.accent,
                    style: TextStyle(fontSize: 16, height: 1.4, color: colors.primaryText),
                    placeholderStyle: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: colors.secondaryText.withValues(alpha: 0.6),
                    ),
                    decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(_fieldRadius)),
                  ),

                  // 文字数
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 4),
                    child: Text(
                      '${_controller.text.characters.length}/${widget.maxLength}',
                      textAlign: TextAlign.right,
                      style: context.textStyles.captionRegular,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ヘッダーの文字のボタン（iOSのナビゲーションバーのボタン）。
/// [onPressed]がnullの間は薄い色で無効にする。
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.label, required this.onPressed, this.emphasized = false});

  final String label;
  final VoidCallback? onPressed;

  /// 確定の操作（保存）を太字で示す。
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      minimumSize: const Size(_headerHeight, _headerHeight),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
          color: onPressed == null ? colors.secondaryText.withValues(alpha: 0.4) : colors.accent,
        ),
      ),
    );
  }
}
