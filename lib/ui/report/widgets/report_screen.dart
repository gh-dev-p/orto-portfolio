import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/report_reason.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_primary_button.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/field_label.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../view_models/report_viewmodel.dart';

// ============================================================
// 関数
// ============================================================

/// REP-01（通報）を開き、閉じたら結果をSnackBarで知らせる
/// PRO-01・CHA-02（メッセージの長押しメニュー・リクエストモード）の共通の流れ
///
/// 結果を返す（閉じただけならnull）。ブロックもした場合（[ReportOutcome.reportedAndBlocked]）の画面遷移は呼び出し側で行う
Future<ReportOutcome?> openReport(BuildContext context, ReportArgs args) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  final outcome = await Navigator.of(
    context,
  ).push<ReportOutcome>(MaterialPageRoute(builder: (_) => ReportScreen(args: args)));
  final message = switch (outcome) {
    ReportOutcome.reported => l10n.repDone,
    ReportOutcome.reportedAndBlocked => l10n.repDoneAndBlocked,
    ReportOutcome.blockFailed => l10n.repBlockFailed,
    ReportOutcome.failed || null => null,
  };
  if (message != null) messenger.showSnackBar(buildAppSnackBar(message));
  return outcome;
}

// ============================================================
// 画面
// ============================================================

/// 画面REP-01：通報
/// 理由を選び、詳しい内容（任意）を書いて、相手を運営に通報する。同時にブロックすることもできる
///
/// 機能仕様書：4.3.6 / 画面設計書：5.9.1
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.args});

  final ReportArgs args;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  /// この画面のViewModel
  ReportViewModel get _viewModel => ref.read(reportViewModelProvider(widget.args).notifier);

  /// 通報を送る
  /// 記録できたら結果を持って閉じる。失敗したら閉じずにSnackBarで知らせる（入力は残す）
  Future<void> _submit() async {
    final outcome = await ref.read(loadingOverlayProvider.notifier).run(_viewModel.submit);
    if (outcome == null || !mounted) return;
    if (outcome == ReportOutcome.failed) {
      showAppSnackBar(context, AppLocalizations.of(context)!.repFailed);
      return;
    }
    Navigator.of(context).pop(outcome);
  }

  /// 理由の表示名
  String _reasonLabel(AppLocalizations l10n, ReportReason reason) => switch (reason) {
    ReportReason.spam => l10n.repReasonSpam,
    ReportReason.harassment => l10n.repReasonHarassment,
    ReportReason.impersonation => l10n.repReasonImpersonation,
    ReportReason.inappropriate => l10n.repReasonInappropriate,
    ReportReason.other => l10n.repReasonOther,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(reportViewModelProvider(widget.args));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.repTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.args.targetAccountId == null ? l10n.repGroupDescription : l10n.repDescription,
                style: context.textStyles.description,
              ),
              const SizedBox(height: 16),

              // 理由
              FieldLabel(l10n.repReasonLabel),
              RadioGroup<ReportReason>(
                groupValue: state.reason,
                onChanged: (reason) {
                  if (reason != null) _viewModel.selectReason(reason);
                },
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        title: Text(_reasonLabel(l10n, reason), style: context.textStyles.listItemLabel),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 詳しい内容（任意）
              FieldLabel(l10n.repDetailLabel),
              TextField(
                maxLength: reportDetailMaxLength,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(hintText: l10n.repDetailHint),
                onChanged: _viewModel.updateDetail,
              ),
              const SizedBox(height: 8),

              // 同時にブロックする
              if (widget.args.targetAccountId != null)
                CheckboxListTile(
                  value: state.alsoBlock,
                  onChanged: (value) => _viewModel.setAlsoBlock(value ?? false),
                  title: Text(l10n.repAlsoBlock, style: context.textStyles.listItemLabel),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              const SizedBox(height: 24),

              AppPrimaryButton(
                label: l10n.repSubmitButton,
                enabled: state.canSubmit,
                destructive: true,
                onTap: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
