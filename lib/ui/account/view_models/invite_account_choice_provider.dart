import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/account.dart';
import 'account_providers.dart';
import 'active_account_provider.dart';

// ============================================================
// 外部から届いた招待で使うアカウント
// ============================================================
//
// 基本原則：アプリの中で、使用中のアカウントで自分から始めた操作（QRの読み取り・ID検索など）は、そのアカウントで固定。
// アプリの外から届いた招待（招待リンク・貼り付け）でアプリが開いたときは、使うアカウントを選ばせる。

/// 外部から届いた招待で使うアカウントの決め方
sealed class InviteAccountDecision {
  const InviteAccountDecision();
}

/// シートで選んでもらう（選べるアカウントが2つ以上）
class InviteAccountAsk extends InviteAccountDecision {
  const InviteAccountAsk({required this.accounts, required this.readOnlyIds, required this.initialAccountId});

  /// シートに並べる、自分のアカウント（読み取り専用も含む）
  final List<Account> accounts;

  /// [accounts]のうち、読み取り専用で選べないもの
  final Set<String> readOnlyIds;

  /// 最初に選んだ状態にするアカウント（使用中のアカウント）
  final String initialAccountId;
}

/// 選ばずに、このアカウントで開く（選べるアカウントが1つ以下）
class InviteAccountUse extends InviteAccountDecision {
  const InviteAccountUse(this.accountId);

  final String accountId;
}

/// 外部から届いた招待で使うアカウントを決める
/// [accounts]は自分のアカウント（一覧の順）、[readOnlyIds]はそのうち読み取り専用のもの、[activeAccountId]は使用中のアカウント
///
/// 選べる（読み取り専用でない）アカウントが2つ以上ならシートで選ぶ。1つならそのアカウント、無ければ使用中のアカウント
InviteAccountDecision decideInviteAccount({
  required List<Account> accounts,
  required Set<String> readOnlyIds,
  required String activeAccountId,
}) {
  final selectable = accounts.where((account) => !readOnlyIds.contains(account.id)).toList();
  if (selectable.length >= 2) {
    final initial = selectable.any((account) => account.id == activeAccountId) ? activeAccountId : selectable.first.id;
    return InviteAccountAsk(accounts: accounts, readOnlyIds: readOnlyIds, initialAccountId: initial);
  }
  if (selectable.length == 1) return InviteAccountUse(selectable.single.id);
  return InviteAccountUse(activeAccountId);
}

/// 外部から届いた招待で、使用中と別のアカウントを選んだときの、選んだアカウントのID
/// そのアカウントに切り替えて（パスコードがあれば解除して）から招待を開くまでの間だけ値を持つ。端末には保存しない
///
/// 値がある間、開く予定の招待（[readyInviteProvider]・[readyGroupInviteProvider]）は、使用中のアカウントがこのアカウントになるまで開かない
/// 使用中のアカウントが別のアカウントに変わったら（解除をやめて別のアカウントを選んだ等）、選び直しになるよう消す
class InviteAccountChoiceNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.listen<String?>(activeAccountIdProvider, (_, next) {
      if (state != null && next != null && next != state) state = null;
    });
    return null;
  }

  /// 選んだアカウント[accountId]を覚える
  void choose(String accountId) => state = accountId;

  /// 開いたので消す
  void clear() => state = null;
}

/// [InviteAccountChoiceNotifier]のProvider
/// アプリ全体で共有するため、破棄しない
final inviteAccountChoiceProvider = NotifierProvider<InviteAccountChoiceNotifier, String?>(
  InviteAccountChoiceNotifier.new,
);

/// 開く予定の招待を、いまの使用中のアカウントで開いてよいか
/// アカウントを選んで切り替えている途中（選んだアカウントがまだ使用中でない）ならfalse
final inviteAccountReadyProvider = Provider<bool>((ref) {
  final choice = ref.watch(inviteAccountChoiceProvider);
  return choice == null || choice == ref.watch(activeAccountIdProvider);
});

/// 外部から届いた招待で使うアカウントの決め方（使用中のアカウントが無ければnull）
final inviteAccountDecisionProvider = Provider<InviteAccountDecision?>((ref) {
  final activeId = ref.watch(activeAccountIdProvider);
  if (activeId == null) return null;
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  final readOnlyIds = {
    for (final account in accounts)
      if (ref.watch(isReadOnlyProvider(account.id))) account.id,
  };
  return decideInviteAccount(accounts: accounts, readOnlyIds: readOnlyIds, activeAccountId: activeId);
});
