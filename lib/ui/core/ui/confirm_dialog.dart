import 'package:flutter/cupertino.dart';

import '../../../l10n/app_localizations.dart';

/// 破壊的な操作（ブロック・送信取消・削除等）の前に表示する共通の確認ダイアログ。
/// 「キャンセル」（共通文言）と、赤字の実行ボタンの2択のみを表示する。実行が選ばれたらtrue、
/// キャンセル・ダイアログ外タップいずれの場合もfalseを返す。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
