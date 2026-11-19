import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/friend.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../../config/service_providers.dart';

// ============================================================
// Provider
// ============================================================

/// 使用中のアカウントが追加した友だちの一覧（機能仕様書4.3.2）
/// 新しい順。使用中のアカウントが無ければ空
final friendsProvider = StreamProvider<List<Friend>>((ref) async* {
  final activeId = ref.watch(activeAccountIdProvider);
  if (activeId == null) {
    yield const [];
    return;
  }
  yield* ref.watch(friendRepositoryProvider).watchFriends(activeId);
});

/// 友だちのアカウントIDからニックネームへの対応（機能仕様書4.3.3）
/// トーク一覧・トーク・友だちのプロフィールで、表示名をニックネーム優先で決めるのに使う（付けていない友だちは含めない）
final friendNicknamesProvider = Provider<Map<String, String>>((ref) {
  final friends = ref.watch(friendsProvider).value ?? const [];
  return {
    for (final friend in friends)
      if (friend.nickname != null && friend.nickname!.isNotEmpty) friend.friendAccountId: friend.nickname!,
  };
});
