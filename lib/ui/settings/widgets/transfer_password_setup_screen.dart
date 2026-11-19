import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../config/transfer_password_rules.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../view_models/transfer_password_setup_viewmodel.dart';
import '../../auth/widgets/transfer_password_error_localization.dart';
import '../../core/ui/app_primary_button.dart';
import '../../core/ui/field_label.dart';

/// 画面SET-05：引き継ぎパスワード設定画面。
///
/// 新しい端末でのログイン時に求める引き継ぎパスワードを登録・変更する。確認のため2回入力させ、
/// 保存できたら`true`を結果として閉じる（SET-01側で完了を通知する）。
class TransferPasswordSetupScreen extends ConsumerStatefulWidget {
  const TransferPasswordSetupScreen({super.key});

  @override
  ConsumerState<TransferPasswordSetupScreen> createState() => _TransferPasswordSetupScreenState();
}

class _TransferPasswordSetupScreenState extends ConsumerState<TransferPasswordSetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _lengthValid {
    final length = _passwordController.text.length;
    return length >= TransferPasswordRules.minLength && length <= TransferPasswordRules.maxLength;
  }

  bool get _matches => _passwordController.text == _confirmController.text;

  Future<void> _save() async {
    if (!_lengthValid || !_matches) return;
    final success = await ref
        .read(loadingOverlayProvider.notifier)
        .run(() => ref.read(transferPasswordSetupViewModelProvider.notifier).register(_passwordController.text));
    if (success && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferPasswordSetupViewModelProvider);
    final error = transferPasswordErrorOf(state);
    final l10n = AppLocalizations.of(context)!;
    final showMismatch = _confirmController.text.isNotEmpty && !_matches;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.transferPasswordSetupTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.transferPasswordSetupDescription, style: context.textStyles.description),
              const SizedBox(height: 24),
              FieldLabel(l10n.transferPasswordFieldLabel),
              TextField(
                controller: _passwordController,
                obscureText: true,
                maxLength: TransferPasswordRules.maxLength,
                decoration: InputDecoration(hintText: l10n.transferPasswordFieldHint, counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              FieldLabel(l10n.transferPasswordConfirmFieldLabel),
              TextField(
                controller: _confirmController,
                obscureText: true,
                maxLength: TransferPasswordRules.maxLength,
                decoration: InputDecoration(hintText: l10n.transferPasswordConfirmFieldHint, counterText: ''),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
              if (showMismatch || error != null) ...[
                const SizedBox(height: 8),
                Text(
                  showMismatch ? l10n.transferPasswordMismatch : localizedTransferPasswordError(context, error!),
                  style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
                ),
              ],
              const SizedBox(height: 32),
              AppPrimaryButton(
                label: l10n.transferPasswordSaveButton,
                enabled: _lengthValid && _matches && !state.isLoading,
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
