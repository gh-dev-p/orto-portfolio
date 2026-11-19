import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../config/account_plan_limits.dart';
import '../../../config/legal_links.dart';
import '../../../config/store_products.dart';
import '../../../data/services/billing/store_purchase_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/external_link.dart';
import '../../account/view_models/account_providers.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_primary_button.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/error_retry_view.dart';
import '../view_models/purchase_flow_viewmodel.dart';
import 'kept_accounts_screen.dart';

// ============================================================
// 関数
// ============================================================

/// SET-07を開く
/// [showLimitNotice]は[PlanScreen.showLimitNotice]を参照
Future<void> openPlanScreen(BuildContext context, {bool showLimitNotice = false}) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => PlanScreen(showLimitNotice: showLimitNotice)));

/// プランの表示名
String planDisplayName(AppLocalizations l10n, String? plan) => switch (plan) {
  AccountPlanLimits.grade1Plan => l10n.planNameGrade1,
  AccountPlanLimits.grade2Plan => l10n.planNameGrade2,
  AccountPlanLimits.adminPlan => l10n.planNameAdmin,
  _ => l10n.planNameFree,
};

/// ストアの表示名（商標なので翻訳しない）
String _storeName(SubscriptionStore store) => switch (store) {
  SubscriptionStore.appStore => 'App Store',
  SubscriptionStore.playStore => 'Google Play',
};

/// 請求先のアカウントの表示名
String _billingAccountName(AppLocalizations l10n, SubscriptionStore store) => switch (store) {
  SubscriptionStore.appStore => 'Apple Account',
  SubscriptionStore.playStore => l10n.planBillingAccountGoogle,
};

/// [store]の解約・プラン変更の画面
Uri _subscriptionsUri(SubscriptionStore store) => switch (store) {
  SubscriptionStore.appStore => StoreProducts.appStoreSubscriptionsUri,
  SubscriptionStore.playStore => StoreProducts.playStoreSubscriptionsUri,
};

// ============================================================
// 画面
// ============================================================

/// 画面SET-07：プラン（機能仕様書4.6.4 / 画面設計書5.6.7）
/// 今のプランと有料プランを表示し、購入・復元とストアの管理画面への導線を出す
///
/// 価格はストアが返す表示用の文字列をそのまま出す（端末のストアの国・通貨になる）。
/// 増えるアカウント数で見せ、1アカウントあたりの単価は出さない
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key, this.showLimitNotice = false});

  /// アカウント数が上限に達している間、上部に案内を出すか
  /// ACC-01の「＋」から開くときだけtrue（購入で上限が増えれば案内は消える）
  final bool showLimitNotice;

  /// 購入・復元の結果を知らせる
  void _showOutcome(BuildContext context, WidgetRef ref, PurchaseOutcome outcome) {
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(context, switch (outcome) {
      PurchaseOutcome.applied => l10n.planPurchaseApplied,
      PurchaseOutcome.scheduled => l10n.planChangeScheduled,
      PurchaseOutcome.pending => l10n.planPurchasePending,
      PurchaseOutcome.alreadyOwned => l10n.planPurchaseAlreadyOwned,
      PurchaseOutcome.failed => l10n.planPurchaseFailed,
      PurchaseOutcome.nothingToRestore => l10n.planNothingToRestore,
    });
    ref.read(purchaseFlowViewModelProvider.notifier).clearOutcome();
  }

  /// 今のプラン・有料プラン・復元などを縦に並べて描く
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(purchaseFlowViewModelProvider, (_, next) {
      final outcome = next.outcome;
      if (outcome != null) _showOutcome(context, ref, outcome);
    });
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final plan = ref.watch(userPlanProvider).value;
    final accountCount = ref.watch(accountsProvider).value?.length ?? 0;
    final limit = AccountPlanLimits.forPlan(plan);
    final busy = ref.watch(purchaseFlowViewModelProvider).busy;
    final products = ref.watch(planProductsProvider);
    final notifier = ref.read(purchaseFlowViewModelProvider.notifier);
    final isPaid = StoreProducts.paidPlans.contains(plan);
    final activeStore = ref.watch(activeSubscriptionProvider).value?.store;
    final store = activeStore ?? SubscriptionStore.current;
    final isOtherStore = activeStore != null && activeStore != SubscriptionStore.current;
    final scheduledChange = ref.watch(scheduledPlanChangeProvider).value;
    final transferable = ref.watch(transferablePlanProvider);
    final transferablePlan = isPaid ? null : transferable.value;
    final scheduled = isPaid && scheduledChange?.plan != plan ? scheduledChange : null;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.planTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (showLimitNotice && limit != null && accountCount >= limit && ref.watch(userPlanProvider).hasValue) ...[
              Text(
                plan == AccountPlanLimits.grade2Plan ? l10n.planLimitReachedTopPlan : l10n.planLimitReachedUpgrade,
                style: context.textStyles.bodyRegular.copyWith(color: context.colors.error),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              scheduled == null
                  ? l10n.planCurrent(planDisplayName(l10n, plan))
                  : l10n.planCurrentScheduled(
                      planDisplayName(l10n, plan),
                      DateFormat.MMMd(languageCode).format(scheduled.startsAt.toLocal()),
                      planDisplayName(l10n, scheduled.plan),
                    ),
              style: context.textStyles.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              limit == null ? l10n.planAccountCountUnlimited(accountCount) : l10n.planAccountCount(accountCount, limit),
              style: context.textStyles.bodyRegular,
            ),
            if (scheduled != null) ...[
              const SizedBox(height: 4),
              Text(l10n.planScheduledNotice, style: context.textStyles.bodyRegular),
            ],
            if (ref.watch(isOverLimitProvider)) ...[
              const SizedBox(height: 12),
              Text(
                l10n.planReadOnlyExplanation,
                style: context.textStyles.bodyRegular.copyWith(color: context.colors.error),
              ),
              if (ref.watch(canChooseKeptAccountsProvider))
                TextButton(onPressed: () => openKeptAccountsScreen(context), child: Text(l10n.planKeptAccountsButton)),
            ],
            const SizedBox(height: 16),
            if (isOtherStore) ...[
              Text(l10n.planOtherStoreNotice(_storeName(store)), style: context.textStyles.bodyRegular),
              const SizedBox(height: 12),
            ],
            if (transferablePlan != null && plan != AccountPlanLimits.adminPlan) ...[
              Text(
                l10n.planTransferNotice(_billingAccountName(l10n, store), planDisplayName(l10n, transferablePlan)),
                style: context.textStyles.bodyRegular,
              ),
              const SizedBox(height: 12),
            ],
            if (plan != AccountPlanLimits.adminPlan)
              products.when(
                data: (byPlan) => byPlan.isEmpty
                    ? Text(l10n.planStoreUnavailable, style: context.textStyles.bodyRegular)
                    : Column(
                        children: [
                          for (final paidPlan in StoreProducts.paidPlans)
                            if (byPlan[paidPlan] case final product?)
                              _PlanCard(
                                plan: paidPlan,
                                product: product,
                                isCurrent: paidPlan == plan,
                                isScheduled: paidPlan == scheduled?.plan,
                                isPaid: isPaid,
                                isTransfer: transferablePlan != null,
                                canBuy: !isOtherStore,
                                enabled: !busy && !transferable.isLoading,
                                onBuy: transferablePlan != null
                                    ? notifier.restore
                                    : () => notifier.buy(product, plan: paidPlan),
                              ),
                        ],
                      ),
                loading: () => const SizedBox(height: 160, child: AppLoadingIndicator()),
                error: (_, _) =>
                    ErrorRetryView(message: l10n.planLoadError, onRetry: () => ref.invalidate(planProductsProvider)),
              ),
            const SizedBox(height: 8),
            TextButton(onPressed: busy ? null : notifier.restore, child: Text(l10n.planRestoreButton)),
            if (isPaid)
              TextButton(
                onPressed: () => openExternalLink(context, _subscriptionsUri(store)),
                child: Text(l10n.planManageButton(_storeName(store))),
              ),
            const SizedBox(height: 8),
            Text(l10n.planAutoRenewNotice(_billingAccountName(l10n, store), _storeName(store)), style: context.textStyles.captionRegular),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => openExternalLink(context, Uri.parse(LegalLinks.termsOfServiceUrl(languageCode))),
                  child: Text(l10n.setTermsOfServiceTile),
                ),
                TextButton(
                  onPressed: () => openExternalLink(context, Uri.parse(LegalLinks.privacyPolicyUrl(languageCode))),
                  child: Text(l10n.setPrivacyPolicyTile),
                ),
                TextButton(
                  onPressed: () => openExternalLink(context, Uri.parse(LegalLinks.tokushohoUrl(languageCode))),
                  child: Text(l10n.planTokushohoLink),
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

/// 有料プラン1つの表示と購入ボタン
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.product,
    required this.isCurrent,
    required this.isScheduled,
    required this.isPaid,
    required this.isTransfer,
    required this.canBuy,
    required this.enabled,
    required this.onBuy,
  });

  /// プラン
  final String plan;

  /// ストアの商品
  final StoreProduct product;

  /// 今のプランか
  final bool isCurrent;

  /// 次回の更新で変わる予定のプランか
  final bool isScheduled;

  /// 今のプランが有料か
  /// trueならボタンを「このプランに変更」にする
  final bool isPaid;

  /// ボタンを契約の引き継ぎにするか
  /// ストアの契約を引き継げるときはtrue（購入すると「登録済み」のダイアログになる）
  final bool isTransfer;

  /// 購入ボタンを出すか
  /// 別のストアに有効な契約があるときはfalse（二重課金を防ぐ）
  final bool canBuy;

  /// 購入できる状態か
  final bool enabled;

  /// 購入ボタンのタップ
  final VoidCallback onBuy;

  /// プラン名・増えるアカウント数・価格・ボタンを描く
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(planDisplayName(l10n, plan), style: context.textStyles.bodyRegular),
          const SizedBox(height: 4),
          Text(l10n.planExtraAccounts(AccountPlanLimits.extraOverFree(plan)), style: context.textStyles.h1),
          const SizedBox(height: 4),
          Text(l10n.planTotalAccounts(AccountPlanLimits.forPlan(plan)!), style: context.textStyles.bodyRegular),
          const SizedBox(height: 8),
          Text(l10n.planPricePerMonth(product.priceString), style: context.textStyles.titleMedium),
          if (canBuy) ...[
            const SizedBox(height: 12),
            AppPrimaryButton(
              label: switch ((isCurrent, isScheduled, isPaid)) {
                (true, _, _) => l10n.planCurrentBadge,
                (_, true, _) => l10n.planScheduledBadge,
                (_, _, true) => l10n.planChangeButton,
                _ when isTransfer => l10n.planTransferButton,
                _ => l10n.planBuyButton,
              },
              enabled: enabled && !isCurrent && !isScheduled,
              onTap: onBuy,
            ),
          ],
        ],
      ),
    );
  }
}
