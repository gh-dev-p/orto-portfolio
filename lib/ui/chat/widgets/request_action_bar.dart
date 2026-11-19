import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// リクエストモードの「友だち追加」「ブロック」「通報」ボタン（画面設計書5.3.2、LINE準拠。通報も可能）
/// 入力欄・送信ボタンの代わりに常に出す
class RequestActionBar extends StatelessWidget {
  const RequestActionBar({
    super.key,
    required this.busy,
    required this.canAddFriend,
    required this.onAddFriend,
    required this.onBlock,
    required this.onReport,
  });

  final bool busy;
  final bool canAddFriend;
  final VoidCallback onAddFriend;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  /// ボタンの左右の余白
  /// 3つ並べると既定（24）では「友だち追加」が1行に収まらないため狭める
  static const _buttonPadding = EdgeInsets.symmetric(horizontal: 8);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          boxShadow: [BoxShadow(color: context.colors.shadow, blurRadius: 16, offset: Offset(0, -2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: busy || !canAddFriend ? null : onAddFriend,
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: context.colors.onAccent,
                  minimumSize: const Size.fromHeight(44),
                  padding: _buttonPadding,
                ),
                child: Text(l10n.addMenuAddFriend),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onBlock,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.error,
                  side: BorderSide(color: context.colors.error),
                  minimumSize: const Size.fromHeight(44),
                  padding: _buttonPadding,
                ),
                child: Text(l10n.commonBlockButton),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onReport,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.error,
                  side: BorderSide(color: context.colors.error),
                  minimumSize: const Size.fromHeight(44),
                  padding: _buttonPadding,
                ),
                child: Text(l10n.commonReportButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
