import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_providers.dart';
import 'active_account_provider.dart';

// ============================================================
// enum
// ============================================================

/// ログイン後の入口（AccountGate）で表示する画面の種類
enum AccountGateStatus {
  /// アカウントを1つも持っていない（ACC-02 アカウント作成）
  noAccount,
  /// アカウントを持っているが、使用中のアカウントが無い（ACC-01 アカウント一覧）
  selectAccount,
  /// 使用中のアカウントがある（ホーム）
  home,
}

// ============================================================
// ViewModel
// ============================================================

/// ログイン後の入口（AccountGate、画面遷移図4章）のViewModel
/// 保有するアカウントと使用中のアカウントを監視し、表示する画面の種類を返す（読み込み中・読み込みの失敗も表す）
class AccountGateViewModel extends Notifier<AsyncValue<AccountGateStatus>> {

  // ---- 状態・初期化 ----

  /// 表示する画面の種類を決める
  /// アカウントが0件ならACC-02、使用中のアカウントが無ければACC-01、あればホーム
  @override
  AsyncValue<AccountGateStatus> build() {
    return ref.watch(accountsProvider).whenData((accounts) {
      if (accounts.isEmpty) return AccountGateStatus.noAccount;
      return ref.watch(activeAccountIdProvider) == null ? AccountGateStatus.selectAccount : AccountGateStatus.home;
    });
  }

  // ---- 操作 ----

  /// アカウントの一覧を読み込み直す
  /// 読み込みに失敗したときの「再試行」から呼ぶ
  void retry() => ref.invalidate(accountsProvider);
}

// ============================================================
// Provider
// ============================================================

/// [AccountGateViewModel]のProvider
/// 入口はログインしている間ずっと表示するため、破棄しない
final accountGateViewModelProvider = NotifierProvider<AccountGateViewModel, AsyncValue<AccountGateStatus>>(
  AccountGateViewModel.new,
);
