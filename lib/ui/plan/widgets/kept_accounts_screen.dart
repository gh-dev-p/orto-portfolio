import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/account_plan_limits.dart';
import '../../../config/service_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/view_models/account_providers.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_primary_button.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';

// ============================================================
// 関数
// ============================================================

/// SET-08を開く
Future<void> openKeptAccountsScreen(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KeptAccountsScreen()));

// ============================================================
// 画面
// ============================================================

/// 使い続けるアカウントを選ぶ画面（SET-08、機能仕様書4.2.1.3）
class KeptAccountsScreen extends ConsumerStatefulWidget {
  const KeptAccountsScreen({super.key});

  @override
  ConsumerState<KeptAccountsScreen> createState() => _KeptAccountsScreenState();
}

class _KeptAccountsScreenState extends ConsumerState<KeptAccountsScreen> {
  /// 選択中のアカウントID。今の一覧を初期値にする
  late final Set<String> _selected = {...?ref.read(keptAccountsProvider).value?.ids};

  /// 保存中か
  bool _saving = false;

  /// 確認の後、選択を保存して画面を閉じる
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.keptAccountsConfirmTitle,
      message: l10n.keptAccountsConfirmMessage,
      confirmLabel: l10n.keptAccountsConfirmButton,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(billingRepositoryProvider).setKeptAccounts(_selected.toList());
      if (!mounted) return;
      showAppSnackBar(context, l10n.keptAccountsSaved);
      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('[KeptAccounts] failed to save: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, l10n.keptAccountsSaveFailed);
    }
  }

  /// 説明・アカウントの一覧・決定ボタンを描く
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final limit = AccountPlanLimits.forPlan(ref.watch(userPlanProvider).value) ?? accounts.length;
    final reachedLimit = _selected.length >= limit;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.keptAccountsTitle),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.keptAccountsDescription(limit), style: context.textStyles.bodyRegular),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final account in accounts)
                    CheckboxListTile(
                      value: _selected.contains(account.id),
                      secondary: AppAvatar(displayName: account.displayName, photoURL: account.photoURL, size: 40),
                      title: Text(account.displayName),
                      subtitle: Text(account.id),
                      onChanged: _saving || (reachedLimit && !_selected.contains(account.id))
                          ? null
                          : (checked) => setState(() {
                              checked == true ? _selected.add(account.id) : _selected.remove(account.id);
                            }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppPrimaryButton(
                label: l10n.keptAccountsConfirmButton,
                enabled: !_saving && _selected.length == limit,
                onTap: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
