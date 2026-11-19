import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/friend_request.dart';
import '../../account/view_models/account_providers.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../block/view_models/block_providers.dart';

// ============================================================
// ViewModel
// ============================================================

/// FRI-01の「友だち申請」を開いているか
/// 友だち申請の通知のタップで開く（機能仕様書4.3.8.2）
class FriendRequestsExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void expand() => state = true;
}

// ============================================================
// Provider
// ============================================================

/// [FriendRequestsExpandedNotifier]のProvider
final friendRequestsExpandedProvider = NotifierProvider<FriendRequestsExpandedNotifier, bool>(
  FriendRequestsExpandedNotifier.new,
);

/// 申請の期限の判定に使う今の時刻（テストで差し替える）
final friendRequestClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// アカウント（引数）に届いた友だち申請（期限切れを含む、新しい順。機能仕様書4.3.8）
final receivedFriendRequestsProvider = StreamProvider.autoDispose.family<List<FriendRequest>, String>((ref, accountId) {
  return ref.watch(friendRequestRepositoryProvider).watchReceived(accountId);
});

/// アカウント（引数）が送った友だち申請（期限切れを含む）
final sentFriendRequestsProvider = StreamProvider.autoDispose.family<List<SentFriendRequest>, String>((ref, accountId) {
  return ref.watch(friendRequestRepositoryProvider).watchSent(accountId);
});

/// 使用中のアカウントに届いた友だち申請のうち、FRI-01に出すもの（機能仕様書4.3.8.2）
/// 期限切れ・退会済みの相手・ブロック関係にある相手からの申請は除く。使用中のアカウントが無ければ空
final visibleFriendRequestsProvider = Provider.autoDispose<List<FriendRequest>>((ref) {
  final activeId = ref.watch(activeAccountIdProvider);
  if (activeId == null) return const [];
  final requests = ref.watch(receivedFriendRequestsProvider(activeId)).value ?? const [];
  if (requests.isEmpty) return const [];
  final now = ref.watch(friendRequestClockProvider)();
  final blockedIds = {
    for (final blocked in ref.watch(blockedAccountsProvider).value ?? const []) blocked.blockedAccountId,
  };
  return [
    for (final request in requests)
      if (request.isLiveAt(now) &&
          !blockedIds.contains(request.senderAccountId) &&
          ref.watch(accountByIdProvider(request.senderAccountId)).value?.isDeleted != true &&
          ref.watch(blockedByPeerProvider(request.senderAccountId)).value != true)
        request,
  ];
});
