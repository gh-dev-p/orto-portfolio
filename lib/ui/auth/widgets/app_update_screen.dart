import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/external_link.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_primary_button.dart';
import '../view_models/app_update_providers.dart';

/// アップデートが必要なときに[child]の代わりにAUT-06を表示する（機能仕様書4.1.6）
class AppUpdateGate extends ConsumerWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(appUpdateRequiredProvider) ? const AppUpdateScreen() : child;
  }
}

/// 画面AUT-06：アップデート案内画面（機能仕様書4.1.6 / 画面設計書5.1.6）
///
/// 閉じる手段は無く、ストアで更新するまでアプリを使えない
class AppUpdateScreen extends ConsumerWidget {
  const AppUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final policy = ref.watch(appVersionPolicyProvider).value;
    final storeUrl = Platform.isIOS ? policy?.iosStoreUrl : policy?.androidStoreUrl;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Image.asset('assets/icon/app_icon_foreground.png', width: 96, height: 96),
              const SizedBox(height: 24),
              Text(l10n.appUpdateTitle, textAlign: TextAlign.center, style: context.textStyles.titleMedium),
              const SizedBox(height: 12),
              Text(l10n.appUpdateMessage, textAlign: TextAlign.center, style: context.textStyles.bodyRegular),
              const Spacer(),
              if (storeUrl != null)
                AppPrimaryButton(
                  label: l10n.appUpdateButton,
                  enabled: true,
                  onTap: () => openExternalLink(context, Uri.parse(storeUrl)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
