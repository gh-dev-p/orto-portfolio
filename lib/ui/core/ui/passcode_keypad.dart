import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';

/// パスコード入力のドット表示（入力済みの桁数だけ塗りつぶす）。AUT-04・SET-03で共用する。
/// システム標準のキーボードは使わず、[PasscodeKeypad]と組み合わせる（画面設計書5.1.4）。
///
/// [errorMessage]がある間は、ドットの代わりにその文言を警告色で表示する（誤入力・不一致の直後。次の入力で消えてドットに戻る）。
/// 文言の有無で高さを変えず、下のテンキーが動かないようにする。
class PasscodeDots extends StatelessWidget {
  const PasscodeDots({super.key, required this.filled, this.length = 4, this.errorMessage});

  final int filled;
  final int length;

  /// 誤入力・不一致の文言。無ければnull
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.accent;
    return SizedBox(
      height: 20,
      child: errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < length; i++)
                  Container(
                    key: Key('passcode-dot-$i'),
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < filled ? color : Colors.transparent,
                      border: Border.all(color: color, width: 1.5),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 数字0〜9と削除のアプリ内テンキー（LINE風、画面設計書5.1.4）。
class PasscodeKeypad extends StatelessWidget {
  const PasscodeKeypad({super.key, required this.onDigit, required this.onDelete, this.enabled = true});

  final ValueChanged<int> onDigit;
  final VoidCallback onDelete;

  /// falseの間は入力を受け付けない（検証中の二重入力の防止）。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          _row([for (final d in row) _digit(context, d)]),
        _row([const SizedBox(width: _keySize, height: _keySize), _digit(context, 0), _deleteKey(context)]),
      ],
    );
  }

  static const _keySize = 72.0;

  Widget _row(List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final child in children) Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: child),
      ],
    ),
  );

  Widget _digit(BuildContext context, int digit) => _Key(
    key: Key('passcode-key-$digit'),
    onTap: enabled ? () => onDigit(digit) : null,
    child: Text('$digit', style: context.textStyles.h1),
  );

  Widget _deleteKey(BuildContext context) => _Key(
    key: const Key('passcode-key-delete'),
    onTap: enabled ? onDelete : null,
    child: Icon(
      Icons.backspace_outlined,
      color: context.colors.primaryText,
      semanticLabel: AppLocalizations.of(context)!.passcodeKeypadDelete,
    ),
  );
}

class _Key extends StatelessWidget {
  const _Key({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: PasscodeKeypad._keySize,
      height: PasscodeKeypad._keySize,
      child: Material(
        color: context.colors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// パスコード画面（AUT-04・SET-03）の配置
/// [header]（見出し・ドット等）と[keypad]を固定の間隔（24pt）で縦に並べ、与えられた領域の縦中央（[verticalAlignment]）に置く
/// 領域に収まらない低い端末では、全体をスクロールできる
class PasscodeCenteredLayout extends StatelessWidget {
  const PasscodeCenteredLayout({super.key, required this.header, required this.keypad, this.verticalAlignment = 0});

  final Widget header;
  final Widget keypad;

  /// 縦の位置（-1で上端、0で中央、1で下端）
  /// 領域の空きをどう上下に分けるかだけを決めるため、どの値でも低い端末ではみ出すことはない
  final double verticalAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Align(
            alignment: Alignment(0, verticalAlignment),
            child: Column(mainAxisSize: MainAxisSize.min, children: [header, const SizedBox(height: 24), keypad]),
          ),
        ),
      ),
    );
  }
}
