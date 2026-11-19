import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/empty_state_view.dart';
import '../../core/ui/error_retry_view.dart';
import '../../core/ui/press_opacity.dart';
import '../../core/ui/unread_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/account.dart';
import '../view_models/account_list_viewmodel.dart';
import 'account_creation_screen.dart';
import 'account_deletion_screen.dart';
import '../../home/widgets/home_shell.dart';
import '../../plan/widgets/plan_screen.dart';
import '../../profile/widgets/self_profile_screen.dart';

// ============================================================
// 関数
// ============================================================

/// ACC-01を画面中央に浮くカードとして開く（アカウントの切り替え用、画面設計書5.2.1「表示方式」）
/// トーク一覧・友だち一覧から呼ぶ（カードの外側のタップで閉じると、切り替えずに呼び出し元へ戻る）
Future<void> showAccountSwitcherDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (context) => const Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      constraints: BoxConstraints(minWidth: 280, maxWidth: 420),
      clipBehavior: Clip.antiAlias,
      child: _AccountListContent(inCard: true),
    ),
  );
}

// ============================================================
// 画面
// ============================================================

/// 画面ACC-01：アカウント一覧／選択画面（機能仕様書4.1.1・4.2.1・4.2.2・4.2.3・4.4.1 / 画面設計書5.2.1）
///
/// アカウント未選択のときにホーム画面として全画面で表示する（[HomeShell]と同格の遷移先）
/// アカウントの切り替えでは[showAccountSwitcherDialog]で、同じ内容を中央のカードとして表示する
class AccountListScreen extends StatelessWidget {
  const AccountListScreen({super.key});

  /// 角丸カードの中に一覧の内容を描く
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: context.colors.shadow, blurRadius: 32, offset: Offset(0, -8)),
            ],
          ),
          child: const _AccountListContent(inCard: false),
        ),
      ),
    );
  }
}

// ============================================================
// 画面の部品
// ============================================================

/// ACC-01の内容（見出し・「＋」ボタン・アカウントの一覧）
/// 表示する内容は[AccountListViewModel]から受け取る
class _AccountListContent extends ConsumerWidget {
  const _AccountListContent({required this.inCard});

  /// 中央のカードとして表示するか
  /// trueのときは行の分だけの高さになり、収まらない分はカードの中でスクロールする（falseのときは親の高さいっぱいに広がる）
  final bool inCard;

  /// 見出し・「＋」ボタン・アカウントの一覧を描く
  /// 読み込み中・読み込みの失敗（再試行つき）も表示する
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountListViewModelProvider);
    final accountsAsync = state.items;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: inCard ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.accListHeaderTitle, style: context.textStyles.h1),
              accountsAsync.when(
                data: (_) => _AddAccountButton(reachedLimit: state.reachedLimit),
                loading: () => const SizedBox(width: 32, height: 32),
                error: (_, _) => const SizedBox(width: 32, height: 32),
              ),
            ],
          ),
        ),
        Flexible(
          fit: inCard ? FlexFit.loose : FlexFit.tight,
          child: accountsAsync.when(
            data: (items) => _AccountList(items: items, inCard: inCard),
            loading: () => const AppLoadingIndicator(),
            error: (error, _) => ErrorRetryView(
              message: l10n.accListLoadError,
              onRetry: ref.read(accountListViewModelProvider.notifier).retry,
            ),
          ),
        ),
      ],
    );
  }
}

/// アカウントを追加する「＋」ボタン
/// 上限に達していたら作成画面へ進まず、上限の案内つきでプラン（SET-07）を開く
class _AddAccountButton extends StatelessWidget {
  const _AddAccountButton({required this.reachedLimit});

  /// アカウント数が上限に達しているか
  final bool reachedLimit;

  /// 丸い「＋」ボタンを描く
  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _handleTap(context),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: context.colors.accent, shape: BoxShape.circle),
        child: Icon(Icons.add, color: context.colors.onAccent, size: 20),
      ),
    );
  }

  /// タップ時に、プラン画面か作成画面を開く
  void _handleTap(BuildContext context) {
    if (reachedLimit) {
      openPlanScreen(context, showLimitNotice: true);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AccountCreationScreen()),
    );
  }
}

/// アカウントの一覧
/// タップで切り替え、長押しで削除のメニューを出す
class _AccountList extends ConsumerWidget {
  const _AccountList({required this.items, required this.inCard});

  /// 各行の表示内容
  final List<AccountListItem> items;

  /// 中央のカードの中か
  /// trueのときは高さを行の分だけに縮め、使用中の行に「プロフィール」ボタンを出す
  final bool inCard;

  /// [account]に切り替える
  /// 中央のカードで開いていれば閉じる（全画面のときは、AuthGateがホーム画面に切り替える）
  Future<void> _switchTo(BuildContext context, WidgetRef ref, Account account) async {
    await ref.read(accountListViewModelProvider.notifier).switchTo(account.id);
    if (!context.mounted) return;
    // アカウント切替目的（中央のカード）で開かれた場合は、戻る先の
    // 画面（チャット一覧／フレンド一覧）がAccount切替を検知して自動的に
    // 再描画するため、カードを閉じるだけでよい。
    // 全画面（AuthGateの中身）の場合は、アクティブアカウントが決まるとAuthGateがホーム画面に切り替える。
    // ここでスタックを差し替えるとAuthGate自体が消え、以後のサインアウト（退会等）やアカウント0件で
    // 画面が切り替わらなくなるため、何もしない。
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  /// カードを閉じて、PRO-02（自分のプロフィール）を開く
  void _openProfile(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => const SelfProfileScreen()));
  }

  /// アカウントの行の長押しメニューを出す（画面設計書5.2.1）
  /// ACC-03（アカウント削除）への入口
  Future<void> _showAccountMenu(BuildContext context, Account account) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.colors.error),
              title: Text(l10n.accDeletionTitle, style: TextStyle(color: context.colors.error)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => AccountDeletionScreen(account: account)));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// アカウントの行を並べて描く
  /// 使用中のアカウントは背景色で強調し、未読数とパスコードの鍵マークを出す（アカウントがなければ空の表示）
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return EmptyStateView(message: AppLocalizations.of(context)!.accListEmpty);
    }


    // 使用中のAccountの行は背景色で強調する。リスト側の左右パディング（8）と
    // 行内パディング（12）の合計を20にし、ヘッダータイトルと左端を揃えている。
    // 中央のカードでは、最後の行の下の余白を見出しの上の余白（20）に揃える。
    return ListView.separated(
      shrinkWrap: inCard,
      padding: EdgeInsets.fromLTRB(8, 8, 8, inCard ? 20 : 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final account = item.account;
        final isActive = item.isActive;
        final passcodeEnabled = item.passcodeEnabled;
        return Material(
          color: isActive ? context.colors.accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _switchTo(context, ref, account),
            onLongPress: () => _showAccountMenu(context, account),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  AppAvatar(displayName: account.displayName, photoURL: account.photoURL, size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                account.displayName,
                                style: context.textStyles.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            UnreadCountBadge(
                              count: item.unreadCount,
                              attention: !item.detailsHidden && item.hasGroupRequest,
                            ),
                          ],
                        ),
                        if (!item.detailsHidden && account.bio != null && account.bio!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            account.bio!,
                            style: context.textStyles.bodyRegular,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (inCard && isActive) ...[
                    const SizedBox(width: 8),
                    _ProfileButton(onPressed: () => _openProfile(context)),
                  ],
                  // パスコードロックを設定したAccountは、右端に鍵マークを出す（設定画面と同じアイコン）。
                  if (passcodeEnabled) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.lock_outline, size: 18, color: context.colors.secondaryText),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 使用中のアカウントの行に出す「プロフィール」ボタン
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.onPressed});

  final VoidCallback onPressed;

  /// 高さ28の小さなピル型を描く（タップ領域は44）
  /// CupertinoButtonは中の文字に英字用のフォントと字間を渡し、日本語が中央からずれるため使わない
  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    return PressOpacity(
      key: const Key('account-list-profile'),
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(minHeight: 28),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
          child: Text(
            AppLocalizations.of(context)!.accListProfileButton,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1,
              leadingDistribution: TextLeadingDistribution.even,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}
