import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/blocked_account.dart';
import '../../account/view_models/account_providers.dart';
import '../../block/view_models/block_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// SET-02（ブロックリスト）の状態
class BlockListState {
  const BlockListState({required this.blocked, required this.myAccountId});

  /// ブロックした相手（ブロックした日時の新しい順）
  /// 読み込み中・読み込みの失敗も表す
  final AsyncValue<List<BlockedAccount>> blocked;

  /// 使用中のアカウントID
  /// 使用中のアカウントが無ければnull（解除できない）
  final String? myAccountId;
}

// ============================================================
// ViewModel
// ============================================================

/// SET-02（ブロックリスト）のViewModel
/// 使用中のアカウントがブロックした相手を渡し、ブロックの解除を扱う
///
/// 画面設計書：5.6.2
class BlockListViewModel extends Notifier<BlockListState> {

  // ---- 状態・初期化 ----

  /// 表示内容を作る
  /// 使用中のアカウントと、ブロックした相手の一覧を監視し、変わるたびに作り直す（解除後も自動で一覧から消える）
  @override
  BlockListState build() {
    return BlockListState(
      blocked: ref.watch(blockedAccountsProvider),
      myAccountId: ref.watch(activeAccountProvider)?.id,
    );
  }

  // ---- 操作 ----

  /// ブロックした相手の一覧を読み込み直す
  /// 読み込みに失敗したときの「再試行」から呼ぶ
  void retry() => ref.invalidate(blockedAccountsProvider);

  /// 相手[targetAccountId]のブロックを解除する
  /// 成功したらtrue（元の友だち関係には戻らない）。使用中のアカウントが無ければ何もせずtrue
  Future<bool> unblock(String targetAccountId) async {
    final myAccountId = state.myAccountId;
    if (myAccountId == null) return true;
    try {
      await ref.read(blockRepositoryProvider).unblockAccount(accountId: myAccountId, targetAccountId: targetAccountId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================
// Provider
// ============================================================

/// [BlockListViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final blockListViewModelProvider = NotifierProvider.autoDispose<BlockListViewModel, BlockListState>(
  BlockListViewModel.new,
);

/// SET-02の1行分の、ブロックした相手（アカウントIDがキー）のアカウント
/// 行ごとに必要になったときだけ監視する。読み込み中・読み込みの失敗も表す（見つからなければnull）
final blockListPeerProvider = Provider.autoDispose.family<AsyncValue<Account?>, String>((ref, accountId) {
  return ref.watch(accountByIdProvider(accountId));
});
