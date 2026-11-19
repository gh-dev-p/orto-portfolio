import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/view_models/loading_overlay_provider.dart';

// ============================================================
// 関数
// ============================================================

/// ブロックの確認ダイアログを出し、確定されたら[block]を実行する
/// CHA-02のリクエストモードとPRO-01の両方から使う共通の流れ。ブロックの実処理は、それぞれの画面のViewModelが[block]として渡す
///
/// ブロックできたら`true`を返す。キャンセル・失敗なら`false`（失敗したらこの関数がSnackBarで知らせる）。ブロック後の画面遷移は呼び出し側で行う
Future<bool> confirmAndBlockAccount({
  required BuildContext context,
  required WidgetRef ref,
  required Future<void> Function() block,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.commonBlockConfirmTitle,
    message: l10n.commonBlockConfirmMessage,
    confirmLabel: l10n.commonBlockButton,
  );
  if (!confirmed || !context.mounted) return false;

  try {
    await ref.read(loadingOverlayProvider.notifier).run(block);
    return true;
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, l10n.commonBlockFailed);
    }
    return false;
  }
}
