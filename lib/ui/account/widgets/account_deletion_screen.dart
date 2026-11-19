import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_primary_button.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/account.dart';
import '../view_models/account_deletion_viewmodel.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../passcode/widgets/passcode_entry_screen.dart';

// ============================================================
// 画面
// ============================================================

/// 画面ACC-03：アカウント削除画面（機能仕様書4.2.3 / 画面設計書5.2.3）
/// 実データは物理削除せず`isDeleted: true`のソフトデリートとする（データ設計書3.2）
///
/// 入口は、ACC-01のアカウント行の長押しメニューと、SET-01の「アカウント削除」（使用中のアカウントが対象）
class AccountDeletionScreen extends ConsumerWidget {
  const AccountDeletionScreen({super.key, required this.account});

  /// 削除するアカウント
  final Account account;

  // ---- 操作 ----

  /// アカウントを削除する
  /// 「削除」のタップ時に呼ぶ（削除できたら一番下の画面まで戻す）
  /// ロック中のアカウントは、AUT-04の確認モードで今のパスコードを入力できた場合だけ削除する
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(accountDeletionViewModelProvider.notifier);
    if (await viewModel.needsPasscode(account)) {
      if (!context.mounted) return;
      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PasscodeEntryScreen(accountId: account.id, mode: PasscodeEntryMode.confirm),
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final success = await ref
        .read(loadingOverlayProvider.notifier)
        .run(() => ref.read(accountDeletionViewModelProvider.notifier).delete(account));
    if (!context.mounted || !success) return;
    // ルート（AuthGate配下の_AccountGateが管理するホーム画面）まで戻す。
    // _AccountGateがaccountsProvider/activeAccountIdProviderの変化を検知し、
    // 残りのAccount有無に応じてHomeShell／ACC-01／ACC-02のいずれかへ自動的に切り替わる。
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ---- 描画 ----

  /// 削除するアカウント・確認の文言・「削除」ボタンを描く
  /// ViewModelの状態を監視し、削除中はボタンを押せなくし、失敗したらエラーを表示する
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountDeletionViewModelProvider);
    final deleting = state.isLoading;
    final hasError = state.hasError;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.accDeletionTitle),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              AppAvatar(displayName: account.displayName, photoURL: account.photoURL, size: 72),
              const SizedBox(height: 12),
              Text(account.displayName, style: context.textStyles.h1),
              const SizedBox(height: 24),
              Text(
                l10n.accDeletionConfirmMessage,
                textAlign: TextAlign.center,
                style: context.textStyles.description,
              ),
              if (hasError) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.accDeletionFailedGeneric,
                  style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
                ),
              ],
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: l10n.accDeletionSubmitButton,
                enabled: !deleting,
                destructive: true,
                onTap: () => _delete(context, ref),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: deleting ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
