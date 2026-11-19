import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/account_plan_limits.dart';
import '../../../data/repositories/user/user_repository.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/chat_room.dart';
import '../../../domain/models/group.dart';
import 'active_account_provider.dart';
import '../../auth/view_models/auth_providers.dart';
import '../../passcode/view_models/passcode_providers.dart';
import '../../../config/service_providers.dart';

// ============================================================
// Provider
// ============================================================

/// ログイン中のユーザが保有する全アカウント（機能仕様書4.1.1・4.2.1・4.2.2）
/// 削除済み（`isDeleted: true`、機能仕様書4.2.3）のアカウントは除く（一覧・アカウント数の上限・アクティブアカウントのどれからも見えなくする）
///
/// [authStateChangesProvider]を`ref.watch`で参照することが重要：ログイン中のユーザを直接読むだけだと、サインアウトで
/// このStreamが権限エラーになった後（サインアウト後のFirestoreの監視はpermission-deniedを返す）、本Providerは
/// autoDisposeでないため古いエラー状態が残ったままになり、再ログインしても作り直されずエラー画面が残り続けてしまう。
/// authStateChangesProviderを明示的にwatchすることで、サインアウト→再ログインのたびに作り直され、新しいuidで監視し直す
final accountsProvider = StreamProvider<List<Account>>((ref) async* {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    yield const [];
    return;
  }
  yield* ref
      .watch(accountRepositoryProvider)
      .watchAccountsForUser(user.uid)
      .map((accounts) => accounts.where((a) => !a.isDeleted).toList());
});

/// ログイン中のユーザのプラン（`users/{uid}.plan`）
/// `users/{uid}`の作成前・未ログインならnull
final userPlanProvider = StreamProvider<String?>((ref) async* {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    yield null;
    return;
  }
  yield* ref.watch(userRepositoryProvider).watchUserPlan(user.uid);
});

/// ログイン中のユーザが作成できるアカウント数の上限（ACC-01の「＋」用）
/// 無制限ならnull。`users/{uid}.plan`から[AccountPlanLimits]で決める（作成の拒否はfirestore.rulesが保証するため、表示上の一時的なずれは許容）
final accountLimitProvider = Provider<AsyncValue<int?>>((ref) {
  return ref.watch(userPlanProvider).whenData(AccountPlanLimits.forPlan);
});

/// ログイン中のユーザの使い続けるアカウント（`users/{uid}.keptAccountIds`、機能仕様書4.2.1.3）
final keptAccountsProvider = StreamProvider<KeptAccounts>((ref) async* {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    yield (ids: const [], chosen: false);
    return;
  }
  yield* ref.watch(userRepositoryProvider).watchKeptAccounts(user.uid);
});

/// アカウント数がプランの上限を超えているか（機能仕様書4.2.1.3）
/// プラン・一覧の取得前はfalse
final isOverLimitProvider = Provider<bool>((ref) {
  final plan = ref.watch(userPlanProvider);
  final accounts = ref.watch(accountsProvider).value;
  if (!plan.hasValue || accounts == null) return false;
  return AccountPlanLimits.isOverLimit(plan.value, accounts.length);
});

/// アカウントが読み取り専用か（機能仕様書4.2.1.3）
/// 上限を超えている間、使い続けるアカウント以外はtrue。取得前はfalse
/// （拒否はfirestore.rulesが保証するため、ここは表示用）
final isReadOnlyProvider = Provider.family<bool, String>((ref, accountId) {
  if (!ref.watch(isOverLimitProvider)) return false;
  final kept = ref.watch(keptAccountsProvider).value;
  return kept != null && !kept.ids.contains(accountId);
});

/// 使い続けるアカウントを選べるか（上限を超えていて、まだ選んでいない）
final canChooseKeptAccountsProvider = Provider<bool>((ref) {
  if (!ref.watch(isOverLimitProvider)) return false;
  final kept = ref.watch(keptAccountsProvider).value;
  return kept != null && !kept.chosen;
});

/// 使用中（アクティブ）のアカウント
/// アカウントの一覧を取得できていれば、そこから取り出す（未選択・取得前ならnull）
final activeAccountProvider = Provider<Account?>((ref) {
  final activeId = ref.watch(activeAccountIdProvider);
  if (activeId == null) return null;
  final accounts = ref.watch(accountsProvider).value;
  if (accounts == null) return null;
  for (final account in accounts) {
    if (account.id == activeId) return account;
  }
  return null;
});

/// 任意のアカウントIDからアカウントを取得する（トークの相手の表示名・アイコン用）
/// 自分のアカウントならその一覧から、そうでなければFirestoreのドキュメントを監視する（相手の表示名・画像の変更や退会が、開いている画面にそのまま反映される）
///
/// 表示している画面が無くなったら監視をやめる（autoDispose）
final accountByIdProvider = StreamProvider.autoDispose.family<Account?, String>((ref, accountId) {
  // 一覧の他のアカウントが変わっただけでは作り直さないよう、該当のAccountだけを見る
  // （変更の無いAccountは同じインスタンスのまま流れてくる。account_repository.dart）。
  final own = ref.watch(
    accountsProvider.select((async) => async.value?.where((account) => account.id == accountId).firstOrNull),
  );
  if (own != null) return Stream.value(own);
  return ref.watch(accountRepositoryProvider).watchAccount(accountId);
});

/// 指定したアカウントのトーク一覧（`chatList`）
/// 使われなくなったら（サインアウト・アカウント削除で対象から外れたら）監視をやめる（autoDispose。残すと、サインアウト後に権限エラーになる監視が残り続ける）
final chatListForAccountProvider = StreamProvider.autoDispose.family<List<ChatListEntry>, String>((ref, accountId) {
  return ref.watch(chatRepositoryProvider).watchChatList(accountId);
});

/// 指定したアカウントに届いているグループへの招待
/// 使われなくなったら監視をやめる（autoDispose。理由は[chatListForAccountProvider]と同じ）
final groupRequestsForAccountProvider = StreamProvider.autoDispose.family<List<GroupRequest>, String>((ref, accountId) {
  return ref.watch(groupRepositoryProvider).watchRequests(accountId);
});

/// 使用中のアカウントを除く、ほかのアカウントの未読の合計（AppHomeHeaderのアバター用）
/// 使用中のアカウントの未読は、CHA-01のボトムナビのタブバッジで表示済みのため除く
/// ロック中のアカウントの未読も、件数だけなので含める（ACC-01と同じ）
///
/// ホーム画面（CHA-01・FRI-01・SET-01）はHomeShellのIndexedStackで常に表示しているため、ほかの各アカウントの`chatList`を常に監視する（アカウント数−1個。データ設計書3.2.4）
final otherAccountsUnreadTotalProvider = Provider.autoDispose<int>((ref) {
  final myAccounts = ref.watch(accountsProvider).value;
  if (myAccounts == null) return 0;

  final activeId = ref.watch(activeAccountIdProvider);
  var total = 0;
  for (final account in myAccounts) {
    if (account.id == activeId) continue;
    final entries = ref.watch(chatListForAccountProvider(account.id)).value ?? const [];
    total += entries.fold<int>(0, (sum, entry) => sum + entry.unreadCount);
  }
  return total;
});

/// 使用中のアカウントを除く、ほかのアカウントのどれかにグループへの招待が届いているか（AppHomeHeaderのアバター用）
/// [otherAccountsUnreadTotalProvider]と同じく、ほかの各アカウントの`groupRequests`を常に監視する（アカウント数−1個）
final otherAccountsHaveGroupRequestProvider = Provider.autoDispose<bool>((ref) {
  final myAccounts = ref.watch(accountsProvider).value;
  if (myAccounts == null) return false;

  final activeId = ref.watch(activeAccountIdProvider);
  var hasRequest = false;
  // 途中で抜けると残りの監視が外れ、招待が増減するたびに付け外しが起きるため、全アカウントを見る。
  for (final account in myAccounts) {
    if (account.id == activeId) continue;
    final requests = ref.watch(groupRequestsForAccountProvider(account.id)).value ?? const [];
    final locked = ref.watch(passcodeEnabledProvider(account.id)).value ?? true;
    if (requests.isNotEmpty && !locked) hasRequest = true;
  }
  return hasRequest;
});
