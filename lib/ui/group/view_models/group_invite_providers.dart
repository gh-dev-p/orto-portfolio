import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/preferences_provider.dart';
import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../account/view_models/invite_account_choice_provider.dart';
import '../../passcode/view_models/passcode_providers.dart';

// ============================================================
// ViewModel
// ============================================================

/// グループの招待リンクで開く予定の招待トークン（機能仕様書4.7.2.5）
/// 開いたら（[HomeShell]が）消す。友だち招待（[PendingInviteNotifier]）と同じく、ログイン前に開いたリンクも端末に保存して持ち続ける
class PendingGroupInviteNotifier extends Notifier<String?> {
  /// 端末に保存するキー
  static const _prefsKey = 'pendingGroupInviteToken';

  @override
  String? build() => ref.read(sharedPreferencesProvider).getString(_prefsKey);

  /// 開く予定の招待を設定する（後から開いたリンクで上書きする）
  void set(String token) {
    state = token;
    ref.read(sharedPreferencesProvider).setString(_prefsKey, token);
  }

  /// 開く予定を消す
  void clear() {
    state = null;
    ref.read(sharedPreferencesProvider).remove(_prefsKey);
  }

  /// 開く予定の招待[token]を、開いたものとして消す
  /// まだ開く予定のままならtrue（Viewが開く）
  bool take(String token) {
    if (state != token) return false;
    clear();
    return true;
  }
}

// ============================================================
// Provider
// ============================================================

/// [PendingGroupInviteNotifier]のProvider
/// アプリ全体で共有するため、破棄しない
final pendingGroupInviteProvider = NotifierProvider<PendingGroupInviteNotifier, String?>(
  PendingGroupInviteNotifier.new,
);

/// 今すぐ開けるグループの招待トークン
/// 使用中のアカウントがあり、パスコードのガードが開いているときだけ値を持つ
/// 招待で使うアカウントを選んで切り替えている途中は、選んだアカウントが使用中になるまで値を持たない
final readyGroupInviteProvider = Provider<String?>((ref) {
  final token = ref.watch(pendingGroupInviteProvider);
  if (token == null) return null;
  if (ref.watch(activeAccountIdProvider) == null) return null;
  if (!ref.watch(inviteAccountReadyProvider)) return null;
  if (ref.watch(passcodeGuardStatusProvider) != PasscodeGuardStatus.open) return null;
  return token;
});

/// グループの招待トークン（引数は(自分のアカウントID, チャットルームID)）
final groupInviteTokenProvider = FutureProvider.autoDispose.family<String, (String, String)>((ref, key) {
  final (accountId, chatRoomId) = key;
  return ref.watch(groupRepositoryProvider).fetchInviteToken(accountId: accountId, chatRoomId: chatRoomId);
});

/// 招待トークンの確認内容（引数は(自分のアカウントID, 招待トークン)）
final groupInvitePreviewProvider = FutureProvider.autoDispose.family<GroupInvitePreview, (String, String)>((ref, key) {
  final (accountId, token) = key;
  return ref.watch(groupRepositoryProvider).previewInvite(accountId: accountId, token: token);
});
