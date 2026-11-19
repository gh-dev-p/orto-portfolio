import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/blocked_account.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../../config/service_providers.dart';

// ============================================================
// Provider
// ============================================================

/// 使用中のアカウントがブロックした相手の一覧（SET-02）
/// ブロックした日時の新しい順。使用中のアカウントが無ければ空
final blockedAccountsProvider = StreamProvider<List<BlockedAccount>>((ref) async* {
  final activeId = ref.watch(activeAccountIdProvider);
  if (activeId == null) {
    yield const [];
    return;
  }
  yield* ref.watch(blockRepositoryProvider).watchBlockedAccounts(activeId);
});

/// 相手（アカウントIDがキー）が、使用中のアカウントをブロックしているか
/// ブロックされた側のCHA-01に、相手のルームが「トークリクエスト」として現れないようにするのに使う
final blockedByPeerProvider = FutureProvider.autoDispose.family<bool, String>((ref, peerAccountId) async {
  final activeId = ref.watch(activeAccountIdProvider);
  if (activeId == null) return false;
  return ref.watch(blockRepositoryProvider).isBlockedBy(accountId: activeId, peerAccountId: peerAccountId);
});
