import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_slide_to_confirm.dart';
import '../../../domain/models/verification_start.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/widgets/verification_code_screen.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../view_models/withdrawal_viewmodel.dart';

// ============================================================
// 画面
// ============================================================

/// 画面SET-04：退会
/// 保有する全アカウント・ユーザ（uid）・Firebase Authのユーザーを削除する
///
/// すべてのアカウントが消えて元に戻せないため、誤操作を防ぐ確認を2段階置く。
/// 理解の確認のチェックを入れてから、スライド（[AppSlideToConfirm]）で確定する
class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  /// 理解の確認のチェックが入っているか
  bool _acknowledged = false;

  // ---- 操作 ----

  /// SMS再認証のうえで退会する（機能仕様書4.1.5）
  /// 成功したら、ホームより上の画面をすべて閉じる
  Future<void> _withdraw() async {
    final navigator = Navigator.of(context);
    final loading = ref.read(loadingOverlayProvider.notifier);
    final viewModel = ref.read(withdrawalViewModelProvider.notifier);

    final start = await loading.run(viewModel.startReauthentication);
    if (!mounted) return;
    if (start == VerificationStart.failed) return;
    if (start == VerificationStart.codeSent) {
      final verified = await navigator.push<bool>(MaterialPageRoute(builder: (_) => const VerificationCodeScreen()));
      if (verified != true || !mounted) return;
    }

    final success = await ref
        .read(loadingOverlayProvider.notifier)
        .run(() => ref.read(withdrawalViewModelProvider.notifier).withdraw());
    if (!success) return;
    // サインアウトでAuthGateがホームをAUT-02（電話番号入力画面）に切り替えるため、本画面を含むホームより上の
    // 画面をすべて閉じる。
    navigator.popUntil((route) => route.isFirst);
  }

  // ---- 画面 ----

  /// 確認のメッセージ・失敗の表示・理解の確認のチェック・確定のスライド・「キャンセル」ボタンを描く
  /// メッセージが長く、文字サイズの設定によっては画面に収まらないためスクロールできるようにする
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(withdrawalViewModelProvider);
    final withdrawing = state.isLoading;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.withdrawalTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Text(l10n.withdrawalMessage, textAlign: TextAlign.center, style: context.textStyles.description),
              if (state.hasError) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.withdrawalFailed,
                  textAlign: TextAlign.center,
                  style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
                ),
              ],
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _acknowledged,
                onChanged: withdrawing ? null : (value) => setState(() => _acknowledged = value ?? false),
                title: Text(l10n.withdrawalAcknowledge, style: context.textStyles.listItemLabel),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 16),
              AppSlideToConfirm(
                label: l10n.withdrawalSlideLabel,
                semanticLabel: l10n.withdrawalSubmitButton,
                enabled: _acknowledged && !withdrawing,
                onConfirmed: _withdraw,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: withdrawing ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
