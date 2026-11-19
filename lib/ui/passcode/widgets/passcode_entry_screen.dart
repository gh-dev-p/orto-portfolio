import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../auth/widgets/auth_error_localization.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/passcode_keypad.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../../domain/models/verification_start.dart';
import '../view_models/passcode_entry_viewmodel.dart';
import '../../auth/widgets/verification_code_screen.dart';

// ============================================================
// enum
// ============================================================

/// [PasscodeEntryScreen]の使われ方
/// 見た目・テンキーは共通で、成功した後の動きだけが違う
enum PasscodeEntryMode {
  /// 起動時・アカウント切り替え時のガード（[PasscodeGuard]が画面全体を覆って表示する）
  /// 成功したらそのアカウントを解除済みにする。「パスコードを忘れた場合」と、解除せずにアカウント一覧へ移る閉じるボタンを表示する
  guard,

  /// SET-01でパスコードをOFFにするときの本人確認（通常の画面遷移で開く）
  /// 成功したら`true`を結果として閉じる（OFFの確定は呼び出し元が行う）
  confirm,
}

// ============================================================
// 画面
// ============================================================

/// 画面AUT-04：パスコード入力
/// 対象のアカウントのアバター・名前と、アプリ内のテンキーを表示する
///
/// 4桁そろった時点で照合し、誤りなら入力を消して再入力を促す
/// 誤りが続くと待ち時間が入り、上限に達すると「パスコードを忘れた場合」でしか復帰できない（機能仕様書4.2.4.5）
///
/// 機能仕様書：4.2.4 / 画面設計書：5.1.4
class PasscodeEntryScreen extends ConsumerStatefulWidget {
  const PasscodeEntryScreen({super.key, required this.accountId, required this.mode});

  final String accountId;
  final PasscodeEntryMode mode;

  @override
  ConsumerState<PasscodeEntryScreen> createState() => _PasscodeEntryScreenState();
}

class _PasscodeEntryScreenState extends ConsumerState<PasscodeEntryScreen> {
  bool get _isGuard => widget.mode == PasscodeEntryMode.guard;

  /// この画面のViewModel
  PasscodeEntryViewModel get _viewModel => ref.read(passcodeEntryViewModelProvider(widget.accountId).notifier);

  /// 数字を1つ入力する
  /// 4桁そろって正しければ、ガードなら解除済みにし（ガードの覆いはこの画面ごと消える）、本人確認なら`true`を結果として閉じる
  Future<void> _onDigit(int digit) async {
    final ok = await _viewModel.inputDigit(digit);
    if (ok != true || !mounted) return;
    if (_isGuard) {
      _viewModel.unlock();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  /// 「パスコードを忘れた場合」：電話番号のSMS再認証に成功したら、パスコードを削除して先へ進める
  /// SMSを送れたらAUT-03を開き、その結果を待つ（送れなかったら、エラーをSnackBarで知らせる）
  Future<void> _forgot() async {
    final viewModel = _viewModel;
    final start = await ref.read(loadingOverlayProvider.notifier).run(viewModel.startRecovery);
    if (!mounted) return;

    var verified = start == VerificationStart.verified;
    if (start == VerificationStart.codeSent) {
      final result = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const VerificationCodeScreen()));
      if (!mounted) return;
      verified = result == true;
    } else if (start == VerificationStart.failed) {
      final code = ref.read(passcodeEntryViewModelProvider(widget.accountId)).errorCode;
      if (code != null) showAppSnackBar(context, localizedAuthError(context, code));
      return;
    }

    final reset = await viewModel.finishRecovery(verified: verified);
    if (!reset && mounted) showAppSnackBar(context, AppLocalizations.of(context)!.passcodeResetFailed);
  }

  /// 入力の制限の案内（制限が無ければnull）
  /// 確認モードには「パスコードを忘れた場合」が無いため、ガードから解除するよう案内する
  String? _lockoutMessage(AppLocalizations l10n, PasscodeEntryState state) {
    if (state.exhausted) return _isGuard ? l10n.passcodeExhausted : l10n.passcodeExhaustedConfirm;
    final seconds = state.waitSeconds;
    if (seconds <= 0) return null;
    return seconds < 60 ? l10n.passcodeWaitSeconds(seconds) : l10n.passcodeWaitMinutes((seconds / 60).ceil());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(passcodeEntryViewModelProvider(widget.accountId));
    final account = state.account;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _isGuard ? null : const AppScreenAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 上側（アカウント表示・見出し・ドット）とテンキーを1つのまとまりにし、間隔を固定して画面の縦中央に置く
                // （テンキーだけを下端に固定すると、背の高い端末ほどドットとテンキーの間が空き、テンキーが下に寄って見えるため）。
                // 画面が低い端末でも、はみ出さずにスクロールできる。アバターが上に寄って見えないよう、中央より少し下に置く。
                Expanded(
                  child: PasscodeCenteredLayout(
                    verticalAlignment: 0.6,
                    header: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppAvatar(displayName: account?.displayName ?? '?', photoURL: account?.photoURL, size: 72),
                        const SizedBox(height: 12),
                        Text(account?.displayName ?? widget.accountId, style: context.textStyles.titleMedium),
                        const SizedBox(height: 24),
                        Text(
                          _isGuard ? l10n.passcodeEnterTitle : l10n.passcodeConfirmCurrentTitle,
                          style: context.textStyles.h1,
                        ),
                        const SizedBox(height: 20),
                        PasscodeDots(
                          filled: state.digits.length,
                          errorMessage: _lockoutMessage(l10n, state) ?? (state.wrong ? l10n.passcodeWrong : null),
                        ),
                      ],
                    ),
                    keypad: PasscodeKeypad(onDigit: _onDigit, onDelete: _viewModel.deleteDigit),
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: _isGuard
                      ? Center(
                          child: TextButton(onPressed: _forgot, child: Text(l10n.passcodeForgot)),
                        )
                      : null,
                ),
              ],
            ),
            // ガードでは閉じるボタンを右上に重ねて置き、解除せずにアカウント一覧（ACC-01）へ移れるようにする
            // （パスコードが分からなくても操作を続けられるようにするため）。AppBarにすると、その分テンキー等が下へ押し出される。
            if (_isGuard)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: _viewModel.leave,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
