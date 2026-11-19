import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/ui/press_opacity.dart';

/// メモのカードの見た目。背景・枠・文字色はここだけで決める
/// 写真の上に置くため、ライトとダークで変えない
abstract final class _MemoCardStyle {
  static const double radius = 18;
  static const double blurSigma = 16;

  /// 白い写真でも白い文字が読める濃さのグレー（プロフィールの下側のグラデーションと重なる位置で、コントラスト4.5以上）。
  static const Color fill = Color(0x992E2E2E);
  static const Color border = Color(0x4DFFFFFF);
  static const Color pressed = Color(0x14FFFFFF);

  static const Color text = Color(0xF2FFFFFF);
  static const Color mutedText = Color(0xE0FFFFFF);

  static const Color unpinnedChipFill = Color(0x24FFFFFF);
  static const Color pinnedChipFill = Color(0xF2FFFFFF);
  static const Color pinnedChipText = Color(0xFF2E2E2E);
}

/// 背景をぼかすガラスの面
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(_MemoCardStyle.radius);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _MemoCardStyle.blurSigma, sigmaY: _MemoCardStyle.blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _MemoCardStyle.fill,
            borderRadius: borderRadius,
            border: Border.all(color: _MemoCardStyle.border, width: 0.5),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

/// PRO-01の、友だちのメモのカード（機能仕様書4.3.7）
/// カードをタップで編集し、メモがあればチップでトークへのピン留めを切り替える
class FriendMemoTile extends StatelessWidget {
  const FriendMemoTile({
    super.key,
    required this.memo,
    required this.pinned,
    required this.onEdit,
    required this.onTogglePin,
  });

  /// 自分だけに見えるメモ
  /// 書いていなければnull
  final String? memo;
  final bool pinned;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final memo = this.memo;
    return memo == null
        ? _AddMemoChip(onTap: onEdit)
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: _MemoCard(memo: memo, pinned: pinned, onEdit: onEdit, onTogglePin: onTogglePin),
          );
  }
}

/// メモが無いときの控えめな入口
class _AddMemoChip extends StatelessWidget {
  const _AddMemoChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      child: InkWell(
        onTap: onTap,
        highlightColor: _MemoCardStyle.pressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 16, color: _MemoCardStyle.text),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.proMemoAdd,
                style: const TextStyle(color: _MemoCardStyle.text, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({required this.memo, required this.pinned, required this.onEdit, required this.onTogglePin});

  final String memo;
  final bool pinned;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _GlassSurface(
      child: Semantics(
        button: true,
        hint: l10n.proMemoEdit,
        child: InkWell(
          onTap: onEdit,
          highlightColor: _MemoCardStyle.pressed,
          child: Padding(
            // チップはタップ領域が見た目より大きいため、右と下の余白はその分だけ小さくする。
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.proMemoSheetTitle,
                  style: const TextStyle(color: _MemoCardStyle.mutedText, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 4, bottom: 2),
                  child: Text(
                    memo,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _MemoCardStyle.text, fontSize: 15, height: 1.45),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.proMemoPrivate,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _MemoCardStyle.mutedText, fontSize: 12),
                      ),
                    ),
                    _PinChip(pinned: pinned, onTap: onTogglePin),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// トークへのピン留めを切り替えるチップ
class _PinChip extends StatelessWidget {
  const _PinChip({required this.pinned, required this.onTap});

  /// 押しやすいよう、見た目より大きく取るタップ領域の高さ。
  static const double _tapHeight = 44;

  final bool pinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final foreground = pinned ? _MemoCardStyle.pinnedChipText : _MemoCardStyle.text;
    return Semantics(
      container: true,
      button: true,
      toggled: pinned,
      label: l10n.proMemoPin,
      excludeSemantics: true,
      onTap: onTap,
      child: PressOpacity(
        onTap: onTap,
        child: SizedBox(
          height: _tapHeight,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: ShapeDecoration(
                color: pinned ? _MemoCardStyle.pinnedChipFill : _MemoCardStyle.unpinnedChipFill,
                shape: StadiumBorder(
                  side: pinned ? BorderSide.none : const BorderSide(color: _MemoCardStyle.border, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 14, color: foreground),
                  const SizedBox(width: 4),
                  Text(
                    pinned ? l10n.proMemoPinned : l10n.proMemoPin,
                    style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
