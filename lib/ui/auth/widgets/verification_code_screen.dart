import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import 'auth_error_localization.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/phone_verification_purpose.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../../domain/models/verification_start.dart';
import '../view_models/verification_code_viewmodel.dart';
import '../../core/ui/app_primary_button.dart';

// ============================================================
// 画面
// ============================================================

/// 画面AUT-03：認証コード入力画面（機能仕様書4.1.1 / 画面設計書5.1.3）
/// AUT-02・AUT-04で始めたSMS認証の手続きを引き継ぎ、認証コードを確認する
///
/// 送信先・verificationId・再送の待ち時間等は、手続き中の状態として[AuthRepository]が持つ（AUT-02・AUT-04から遷移した時点で既に存在する）
///
/// 何のための認証か（[VerificationCodeState.purpose]）は手続き中の状態で決まる
/// AUT-04（パスコード入力画面）の「パスコードを忘れた場合」の再認証・電話番号の変更として開かれた場合は、
/// 成功したら`true`を結果として本画面だけを閉じる（呼び出し元が結果を受けて、パスコードの解除・完了の通知を行う）
class VerificationCodeScreen extends ConsumerStatefulWidget {
  const VerificationCodeScreen({super.key});

  @override
  ConsumerState<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

// ============================================================
// State
// ============================================================

/// [VerificationCodeScreen]のState
/// 入力欄のコントローラだけを持つ（入力値・確認中・再送の残り秒数などの状態は[VerificationCodeViewModel]が持つ）
class _VerificationCodeScreenState extends ConsumerState<VerificationCodeScreen> {

  // ---- 状態・初期化 ----

  /// 入力欄のコントローラ
  final _codeController = TextEditingController();

  /// 画面が消えるときに、入力欄のコントローラを破棄する
  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// この画面のViewModel
  VerificationCodeViewModel get _viewModel => ref.read(verificationCodeViewModelProvider.notifier);

  // ---- 操作 ----

  /// 入力された認証コードを確認する
  /// 「確認」のタップ時に呼ぶ（認証できたら[_closeAfterVerified]で閉じる）
  Future<void> _confirm() async {
    // 桁数チェック
    if (!ref.read(verificationCodeViewModelProvider).isValid) return;

    final isSuccess = await ref.read(loadingOverlayProvider.notifier).run(_viewModel.confirm);

    // 当画面が閉じられている、または認証が完了しなかったときはreturn
    if (!mounted || !isSuccess) return;

    // 画面を閉じる
    _closeAfterVerified();
  }

  /// 認証できたら、目的に応じて本画面を閉じる
  /// サインインは一番下の画面まで戻すだけ（AuthGateが次画面へ切り替える）。それ以外は`true`を結果として本画面だけを閉じる
  void _closeAfterVerified() {
    if (ref.read(verificationCodeViewModelProvider).purpose == PhoneVerificationPurpose.signIn) {
      // サインインのとき
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      // 上記以外（再認証（パスコードリセット）・電話番号変更）
      Navigator.of(context).pop(true);
    }
  }

  /// 認証コードを再送する
  /// 「コードを再送する」のタップ時に呼ぶ（再送できたらSnackBarで知らせる）
  Future<void> _resend() async {
    final result = await ref.read(loadingOverlayProvider.notifier).run(_viewModel.resend);

    if (!mounted) return;

    switch (result) {
      case VerificationStart.codeSent:
        // SMS再送のとき
        showAppSnackBar(context, AppLocalizations.of(context)!.authVerificationResentSnackbar);

      case VerificationStart.verified:
        // 再送の時点で端末が自動的に認証まで済ませた（Android）とき
        // 認証成功時と同じ扱い
        _closeAfterVerified();

      case VerificationStart.failed:
        // SMS送信できなかったとき
        // （エラーは状態を通して画面に表示される）
        break;
    }
  }

  // ---- 描画 ----

  /// 見出し・認証コードの入力欄・エラー表示・再送ボタン・「確認」ボタンを描く
  /// ViewModelの状態を監視し、エラーや再送の残り秒数を反映する
  @override
  Widget build(BuildContext context) {

    // ローカル変数
    final state = ref.watch(verificationCodeViewModelProvider);  // VMの状態監視
    final canResend = state.canResend; // 再送可能か
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: const AppScreenAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // メインテキスト
              Text(l10n.authVerificationTitle, style: context.textStyles.h1),
              const SizedBox(height: 8),
              // 電話番号入りメッセージ
              Text(l10n.authVerificationSentTo(state.phoneNumber ?? ''), style: context.textStyles.description),
              const SizedBox(height: 24),
              // 認証コード入力
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                // SMSで届いたコードを、キーボードの上の候補から1回のタップで入れられるようにする
                autofillHints: const [AutofillHints.oneTimeCode],
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],  // 数字のみ入力可能
                style: context.textStyles.h1.copyWith(letterSpacing: 12),
                decoration: const InputDecoration(counterText: '', hintText: '______'),
                onChanged: (code) {
                  _viewModel.updateCode(code);
                  // 6桁そろったら、確認ボタンを待たずに確認する（候補から入れたときも）
                  if (code.length == 6) _confirm();
                },
                onSubmitted: (_) => _confirm(),
              ),

              // エラーメッセージ表示
              if (state.errorCode != null) ...[
                const SizedBox(height: 4),
                Text(
                  localizedAuthError(context, state.errorCode!),
                  style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
                ),
              ],

              // 認証失敗アラート表示
              if (state.failureCount >= 3) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.authVerificationRepeatedFailure,
                  style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
                ),
              ],
              const SizedBox(height: 16),

              // コード再送ボタン（クールタイム付き）
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: canResend ? _resend : null,
                  child: Text(
                    canResend ? l10n.authResendCode : l10n.authResendCodeCooldown(state.cooldownSeconds),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 確認ボタン
              AppPrimaryButton(
                label: l10n.authConfirmButton,
                enabled: state.isValid && !state.confirming,
                onTap: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
