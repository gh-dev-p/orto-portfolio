import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/error_retry_view.dart';
import '../../profile/widgets/section_card.dart';
import '../view_models/notification_settings_viewmodel.dart';

// ============================================================
// 画面
// ============================================================

/// 画面SET-06：通知設定（画面設計書5.6.6）
/// アカウント[accountId]宛ての通知と、リアクションの通知のオン・オフを切り替える。設定はアカウントごとで、そのアカウントでログインしている全端末に効く
///
/// 端末（OS）の通知の許可がオフのときは、LINEに準拠して、その旨と端末の設定アプリへの導線を上部に出す（スイッチは操作できるまま）
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key, required this.accountId});

  /// 対象のアカウント（SET-01を開いたときの使用中のアカウント）
  final String accountId;

  // ---- 操作 ----

  /// 設定の変更を保存し、失敗したらSnackBarで知らせる
  Future<void> _save(BuildContext context, Future<bool> Function() update) async {
    final ok = await update();
    if (!ok && context.mounted) showAppSnackBar(context, AppLocalizations.of(context)!.setNotificationUpdateFailed);
  }

  // ---- 画面 ----

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(notificationSettingsViewModelProvider(accountId));
    final viewModel = ref.read(notificationSettingsViewModelProvider(accountId).notifier);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.setNotificationTile),
      body: state.settings.when(
        loading: () => const AppLoadingIndicator(),
        error: (_, _) => ErrorRetryView(message: l10n.setNotificationLoadError, onRetry: viewModel.retry),
        data: (settings) => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            if (state.permissionDenied == true) ...[const _DeviceNotificationOffNotice(), const SizedBox(height: 16)],
            SectionCard(
              children: [
                _SwitchRow(
                  title: l10n.setNotificationMessagesTitle,
                  subtitle: l10n.setNotificationMessagesSubtitle,
                  value: settings.messages,
                  onChanged: (value) => _save(context, () => viewModel.setMessagesEnabled(value)),
                ),
                // 通知がオフの間は、リアクションの通知も送られないため操作できなくする。
                _SwitchRow(
                  title: l10n.setNotificationReactionsTitle,
                  subtitle: l10n.setNotificationReactionsSubtitle,
                  value: settings.messages && settings.reactions,
                  onChanged: settings.messages
                      ? (value) => _save(context, () => viewModel.setReactionsEnabled(value))
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// 端末（OS）の通知の許可がオフのときの案内と、端末の設定アプリへの導線
class _DeviceNotificationOffNotice extends StatelessWidget {
  const _DeviceNotificationOffNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SectionCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_off_outlined, color: context.colors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.setNotificationDeviceOff,
                  style: context.textStyles.listItemLabel.copyWith(color: context.colors.primaryText),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: TextButton(
              onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.notification),
              child: Text(l10n.setNotificationOpenDeviceSettings),
            ),
          ),
        ),
      ],
    );
  }
}

/// 見出し・補足とスイッチを並べた1行
/// [onChanged]がnullなら操作できない（薄く表示する）
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onChanged == null ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.titleBold),
                  const SizedBox(height: 4),
                  Text(subtitle, style: context.textStyles.bodyRegular),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(value: value, activeTrackColor: context.colors.accent, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
