import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/passcode_keypad.dart';
import '../../../l10n/app_localizations.dart';
import '../view_models/passcode_setup_viewmodel.dart';

// ============================================================
// 画面
// ============================================================

/// 画面SET-03：パスコード設定
/// SET-01でパスコードをONにしたときに開く。新しいパスコード（4桁）を2回入力させ、一致したら端末に保存して`true`を結果として閉じる
///
/// 不一致ならエラーを出して1回目からやり直す。戻る（キャンセル）はパスコードを設定せずに閉じる
///
/// 機能仕様書：4.2.4 / 画面設計書：5.6.3
class PasscodeSetupScreen extends ConsumerStatefulWidget {
  const PasscodeSetupScreen({super.key, required this.accountId});

  /// 対象のアカウントID
  final String accountId;

  @override
  ConsumerState<PasscodeSetupScreen> createState() => _PasscodeSetupScreenState();
}

class _PasscodeSetupScreenState extends ConsumerState<PasscodeSetupScreen> {
  // ---- 操作 ----

  /// この画面のViewModel
  PasscodeSetupViewModel get _viewModel => ref.read(passcodeSetupViewModelProvider(widget.accountId).notifier);

  /// 数字を1つ入力する
  /// 設定できたら`true`を結果として閉じ、保存に失敗したらSnackBarで知らせる
  Future<void> _onDigit(int digit) async {
    final result = await _viewModel.inputDigit(digit);
    if (!mounted) return;
    switch (result) {
      case PasscodeSetupResult.pending:
        break;
      case PasscodeSetupResult.saved:
        Navigator.of(context).pop(true);
      case PasscodeSetupResult.failed:
        showAppSnackBar(context, AppLocalizations.of(context)!.passcodeSaveFailed);
    }
  }

  // ---- 画面 ----

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(passcodeSetupViewModelProvider(widget.accountId));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.passcodeSetupTitle),
      body: SafeArea(
        child: Column(
          children: [
            // 上側（見出し・ドット）とテンキーを1つのまとまりにして縦中央に置く（AUT-04と同じ）。
            Expanded(
              child: PasscodeCenteredLayout(
                header: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.confirming ? l10n.passcodeSetupConfirmTitle : l10n.passcodeSetupNewTitle,
                      style: context.textStyles.h1,
                    ),
                    const SizedBox(height: 20),
                    PasscodeDots(
                      filled: state.digits.length,
                      errorMessage: state.mismatch ? l10n.passcodeMismatch : null,
                    ),
                  ],
                ),
                keypad: PasscodeKeypad(onDigit: _onDigit, onDelete: _viewModel.deleteDigit, enabled: !state.busy),
              ),
            ),
            // 下端の余白をAUT-04（下に「パスコードを忘れた場合」の欄56pt）とそろえる
            const SizedBox(height: 56),
          ],
        ),
      ),
    );
  }
}
