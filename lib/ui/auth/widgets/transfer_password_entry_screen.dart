import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/legal_links.dart';
import '../../../utils/external_link.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../settings/widgets/home_notices_listener.dart' show formatResetAt;
import '../../../l10n/app_localizations.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../view_models/transfer_password_entry_viewmodel.dart';
import 'transfer_password_error_localization.dart';
import '../../core/ui/app_primary_button.dart';

// ============================================================
// 画面
// ============================================================

/// 画面AUT-05：引き継ぎパスワード入力画面
/// 新しい端末（パスワードを確認していないセッション）でSMS認証した直後に、AuthGateがアカウントの画面の代わりに表示する
///
/// 引き継ぎパスワードを登録済みの場合だけ表示する。確認できるまでは、firestore.rules・storage.rulesにより何も読み書きできない
/// 確認に成功するとAuthGateが自動的に通常の画面へ切り替える
class TransferPasswordEntryScreen extends ConsumerStatefulWidget {
  const TransferPasswordEntryScreen({super.key});

  @override
  ConsumerState<TransferPasswordEntryScreen> createState() => _TransferPasswordEntryScreenState();
}

// ============================================================
// State
// ============================================================

/// [TransferPasswordEntryScreen]のState
/// 入力中のパスワードを持つ（そのほかの状態はViewModelが持つ）
class _TransferPasswordEntryScreenState extends ConsumerState<TransferPasswordEntryScreen> {

  // ---- 状態・初期化 ----

  /// 入力中のパスワード
  final _controller = TextEditingController();

  /// 再設定の申請の状態を読み込む
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(transferPasswordEntryViewModelProvider.notifier).loadResetStatus());
  }

  /// 画面が消えるときに、入力欄のコントローラを破棄する
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---- 操作 ----

  /// 入力されたパスワードを確認する
  /// 「確認」のタップ時に呼ぶ（間違っていたら入力欄を空にする）
  Future<void> _confirm() async {
    final password = _controller.text;
    if (password.isEmpty) return;
    final isSuccess = await ref
        .read(loadingOverlayProvider.notifier)
        .run(() => ref.read(transferPasswordEntryViewModelProvider.notifier).verify(password));
    if (!isSuccess && mounted) _controller.clear();
  }

  /// パスワードを忘れた場合の案内を出し、了承されたら再設定（前のデータの削除）を申請する（機能仕様書4.1.4.3）
  /// 再発行はできない。削除は申請から7日後で、その間は前の持ち主の確認済みの端末から取り消せる
  /// （電話番号が別の人に渡った場合に、SMS認証だけで前の持ち主のデータをすぐには消せないようにするため）
  Future<void> _forgot() async {
    final l10n = AppLocalizations.of(context)!;
    final start = await showConfirmDialog(
      context,
      title: l10n.transferPasswordForgotTitle,
      message: l10n.transferPasswordForgotMessage,
      confirmLabel: l10n.transferResetStart,
    );
    if (!start || !mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.transferResetConfirmTitle,
      message: l10n.transferResetConfirmMessage,
      confirmLabel: l10n.transferResetConfirmButton,
    );
    if (!confirmed || !mounted) return;
    final isSuccess = await ref
        .read(loadingOverlayProvider.notifier)
        .run(() => ref.read(transferPasswordEntryViewModelProvider.notifier).requestReset());
    if (!isSuccess && mounted) showAppSnackBar(context, l10n.transferResetFailed);
  }

  /// 再設定の申請を取り消す
  Future<void> _cancelReset() async {
    final l10n = AppLocalizations.of(context)!;
    final isSuccess = await ref
        .read(loadingOverlayProvider.notifier)
        .run(() => ref.read(transferPasswordEntryViewModelProvider.notifier).cancelReset());
    if (!mounted) return;
    showAppSnackBar(context, isSuccess ? l10n.transferResetCanceled : l10n.transferResetFailed);
  }

  /// お問い合わせ（端末のメールアプリ）を開く
  Future<void> _contact() => openExternalLink(context, Uri(scheme: 'mailto', path: LegalLinks.contactEmail));

  /// サインインを取り消し、AUT-02（電話番号入力画面）に戻る
  /// AuthGateがAUT-02へ切り替える
  Future<void> _backToPhoneInput() => ref
      .read(loadingOverlayProvider.notifier)
      .run(() => ref.read(transferPasswordEntryViewModelProvider.notifier).returnToPhoneInput());

  // ---- 描画 ----

  /// 見出し・パスワードの入力欄・エラー表示・「確認」ボタン・2つのリンクを描く
  /// 引き継ぎパスワードの確認のエラーを、ViewModelの状態から表示する
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferPasswordEntryViewModelProvider);
    final error = transferPasswordErrorOf(state.verification);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(l10n.transferPasswordEntryTitle, style: context.textStyles.h1),
              const SizedBox(height: 8),
              Text(l10n.transferPasswordEntryDescription, style: context.textStyles.description),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                obscureText: true,
                autofocus: true,
                style: context.textStyles.titleMedium,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _confirm(),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  localizedTransferPasswordError(context, error),
                  style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
                ),
              ],
              const SizedBox(height: 32),
              AppPrimaryButton(
                label: l10n.transferPasswordEntryButton,
                enabled: _controller.text.isNotEmpty && !state.verification.isLoading,
                onTap: _confirm,
              ),
              const SizedBox(height: 16),
              if (state.resetAt case final resetAt?) ...[
                Text(
                  l10n.transferResetPending(formatResetAt(context, resetAt)),
                  style: context.textStyles.description,
                ),
                TextButton(onPressed: _cancelReset, child: Text(l10n.transferResetCancel)),
              ] else
                TextButton(onPressed: _forgot, child: Text(l10n.transferPasswordForgot)),
              TextButton(onPressed: _contact, child: Text(l10n.transferPasswordContactSupport)),
              TextButton(onPressed: _backToPhoneInput, child: Text(l10n.transferPasswordBackToPhoneInput)),
            ],
          ),
        ),
      ),
    );
  }
}
