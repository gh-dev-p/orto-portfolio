import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/account_plan_limits.dart';
import '../../../config/service_providers.dart';
import '../../../domain/models/account.dart';
import '../../passcode/view_models/passcode_providers.dart';
import 'account_providers.dart';
import 'active_account_provider.dart';

// ============================================================
// 状態クラス
// ============================================================

/// ACC-01（アカウント一覧画面）の1行分の表示内容
class AccountListItem {
  const AccountListItem({
    required this.account,
    required this.isActive,
    required this.unreadCount,
    required this.hasGroupRequest,
    required this.passcodeEnabled,
    required this.detailsHidden,
  });

  /// アカウント
  final Account account;

  /// 使用中（アクティブ）のアカウントか
  /// trueなら行を背景色で強調する
  final bool isActive;

  /// このアカウントの未読の合計
  final int unreadCount;

  /// このアカウントにグループへの招待が届いているか
  /// trueなら未読の合計に代えて「!」を出す
  final bool hasGroupRequest;

  /// パスコードロックを設定しているか
  /// trueなら行の右端に鍵マークを出す
  final bool passcodeEnabled;

  /// ひとこと・招待の有無を隠すか
  /// ロックを解除していないアカウントは、名前・画像・未読の件数だけを出す（解除前の第三者に、中身の手がかりを見せないため）
  final bool detailsHidden;
}

/// ACC-01（アカウント一覧画面）の状態
class AccountListState {
  const AccountListState({required this.items, required this.accountLimit});

  /// アカウントの一覧（各行の表示内容）
  /// 読み込み中・読み込みの失敗も表す
  final AsyncValue<List<AccountListItem>> items;

  /// 作成できるアカウント数の上限
  /// 無制限ならnull（プランの取得前は無料プランの上限として扱う）
  final int? accountLimit;

  /// アカウント数が上限に達しているか
  /// trueなら「＋」で作成画面へ進まず、上限の案内を出す
  bool get reachedLimit {
    final limit = accountLimit;
    final count = items.value?.length;
    return limit != null && count != null && count >= limit;
  }
}

// ============================================================
// ViewModel
// ============================================================

/// ACC-01（アカウント一覧画面）のViewModel
/// 保有するアカウントの一覧（使用中・未読数・パスコードの有無つき）と、アカウントの切り替えを扱う
///
/// 機能仕様書：4.1.1・4.2.1・4.2.2・4.2.3・4.4.1 / 画面設計書：5.2.1
class AccountListViewModel extends Notifier<AccountListState> {

  // ---- 状態・初期化 ----

  /// 表示内容を作る
  /// アカウントの一覧・プランの上限・未読数・グループへの招待・使用中のアカウント・パスコードの有無を監視し、変わるたびに作り直す
  @override
  AccountListState build() {
    final accountsAsync = ref.watch(accountsProvider);
    // 取得前はnull（無制限）と区別がつかないため、hasValueで判定して無料プランの上限を使う。
    final limitAsync = ref.watch(accountLimitProvider);
    final accountLimit = limitAsync.hasValue ? limitAsync.value : AccountPlanLimits.forPlan(null);
    final unreadCounts = ref.watch(_accountUnreadCountsProvider).value ?? const <String, int>{};
    final activeAccountId = ref.watch(activeAccountIdProvider);
    final unlockedAccountId = ref.watch(unlockedAccountIdProvider);

    final items = accountsAsync.whenData(
      (accounts) => [
        for (final account in accounts)
          AccountListItem(
            account: account,
            isActive: account.id == activeAccountId,
            unreadCount: unreadCounts[account.id] ?? 0,
            // ほかのアカウントの分はホームが常に監視しているため、ACC-01を開いても読み取りは増えない。
            hasGroupRequest: ref.watch(groupRequestsForAccountProvider(account.id)).value?.isNotEmpty ?? false,
            passcodeEnabled: ref.watch(passcodeEnabledProvider(account.id)).value ?? false,
            // 確認できるまでは隠す。
            detailsHidden:
                account.id != unlockedAccountId && (ref.watch(passcodeEnabledProvider(account.id)).value ?? true),
          ),
      ],
    );
    return AccountListState(items: items, accountLimit: accountLimit);
  }

  // ---- 操作 ----

  /// 使用中のアカウントを切り替える
  /// アカウントの行のタップ時に呼ぶ（画面の閉じ方・ホームへの差し替えはView側で行う）
  Future<void> switchTo(String accountId) => ref.read(activeAccountIdProvider.notifier).setActive(accountId);

  /// アカウントの一覧を読み込み直す
  /// 読み込みに失敗したときの「再試行」から呼ぶ
  void retry() => ref.invalidate(accountsProvider);
}

// ============================================================
// Provider
// ============================================================

/// [AccountListViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final accountListViewModelProvider = NotifierProvider.autoDispose<AccountListViewModel, AccountListState>(
  AccountListViewModel.new,
);

/// 各アカウントの未読の合計（accountId → 未読数）
/// データ設計書3.2.4：自分の各アカウントの`chatList`を1回ずつ取得し、アカウントごとに合計する（uidでは検索しない）
///
/// 常時の監視はせず、ACC-01を開いている間だけ生存する（autoDispose。画面を開くたびに取り直す）
final _accountUnreadCountsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final myAccounts = ref.watch(accountsProvider).value;
  if (myAccounts == null || myAccounts.isEmpty) return const {};

  final repository = ref.watch(chatRepositoryProvider);
  final lists = await Future.wait([for (final account in myAccounts) repository.fetchChatList(account.id)]);
  return {
    for (var i = 0; i < myAccounts.length; i++)
      myAccounts[i].id: lists[i].fold<int>(0, (sum, entry) => sum + entry.unreadCount),
  };
});
