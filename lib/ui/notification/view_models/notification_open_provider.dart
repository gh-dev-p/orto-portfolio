import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/notification_target.dart';

import '../../account/view_models/account_providers.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../passcode/view_models/passcode_providers.dart';

export '../../../domain/models/notification_target.dart';

// ============================================================
// ViewModel
// ============================================================

/// 通知のタップで開く予定のトーク
/// 開いたら（[HomeShell]が）消す
class PendingNotificationTargetNotifier extends Notifier<NotificationTarget?> {

  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  /// 開く予定なしから始め、アクティブアカウントの切り替えを監視する
  @override
  NotificationTarget? build() {
    ref.listen<String?>(activeAccountIdProvider, onActiveAccountChanged);
    return null;
  }

  // ---- 操作 ----

  /// 開く予定のトークを設定する
  /// [switched]は、そのために使用中のアカウントが変わるか（開いた後に切り替えを知らせる）
  void set(NotificationTarget target, {bool switched = false}) {
    this.switched = switched;
    state = target;
  }

  /// 開く予定のトークのために、使用中のアカウントを切り替えたか
  bool switched = false;

  /// 開く予定を消す
  void clear() => state = null;

  /// アクティブアカウントが変わったときの処理
  /// 開く前に通知先から別のアカウントへ切り替えた・サインアウトした場合は、開く予定を取り消す
  void onActiveAccountChanged(String? previous, String? next) {
    final target = state;
    if (target != null && previous == target.accountId && next != target.accountId) clear();
  }
}

/// [PendingNotificationTargetNotifier]のProvider
/// アプリ全体で共有するため、破棄しない
final pendingNotificationTargetProvider = NotifierProvider<PendingNotificationTargetNotifier, NotificationTarget?>(
  PendingNotificationTargetNotifier.new,
);

// ============================================================
// Provider
// ============================================================

/// 今すぐ開ける通知先のトーク
/// アクティブなアカウントが通知先で、パスコードのガードが開いているときだけ値を持つ（ロック中に開くと、本人が見ていないメッセージが既読になるため）
final readyNotificationTargetProvider = Provider<NotificationTarget?>((ref) {
  final target = ref.watch(pendingNotificationTargetProvider);
  if (target == null) return null;
  if (ref.watch(activeAccountIdProvider) != target.accountId) return null;
  if (ref.watch(passcodeGuardStatusProvider) != PasscodeGuardStatus.open) return null;
  return target;
});

// ============================================================
// 通知のタップ時の処理
// ============================================================

/// 通知のタップ時の処理（機能仕様書4.4.6.1）
class NotificationOpener {
  NotificationOpener(this._ref);

  // ---- 状態・初期化 ----

  /// Providerを読むためのRef
  final Ref _ref;

  // ---- 操作 ----

  /// 通知先のアカウントに切り替え、トークを開く予定にする
  /// 実際に開くのは[HomeShell]で、[readyNotificationTargetProvider]が値を持った時点（自分のアカウント宛てでない通知は無視する）
  ///
  /// パスコードを設定したアカウントは、すでに解除済みでも必ずロック画面（AUT-04）を通す
  Future<void> open(NotificationTarget target) async {
    final accounts = await _ref.read(accountsProvider.future);
    if (!accounts.any((account) => account.id == target.accountId)) return;
    // 開く予定を入れる前にロックし、解除済みのまま一瞬でもトークが開かないようにする。
    _ref.read(unlockedAccountIdProvider.notifier).lock();
    final switched = _ref.read(activeAccountIdProvider) != target.accountId;
    _ref.read(pendingNotificationTargetProvider.notifier).set(target, switched: switched);
    await _ref.read(activeAccountIdProvider.notifier).setActive(target.accountId);
  }
}

/// [NotificationOpener]のProvider
final notificationOpenerProvider = Provider<NotificationOpener>((ref) => NotificationOpener(ref));

// ============================================================
// いま見ているトーク
// ============================================================

/// いま見ているトーク（CHA-02）
/// アカウントIDとチャットルームIDの組
typedef OpenChat = ({String accountId, String chatRoomId});

/// いま見ているトークを持つNotifier
/// CHA-02が、見ている間だけ設定する（上に別の画面を開いている間は外す。このトーク宛ての新着ではアプリ内バナーを出さない）
class OpenChatNotifier extends Notifier<OpenChat?> {

  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  /// 何も見ていない状態から始める
  @override
  OpenChat? build() => null;

  // ---- 操作 ----

  /// [chat]を見始めた
  void open(OpenChat chat) => state = chat;

  /// [chat]を見るのをやめた
  /// 別のトークに切り替わった後なら何もしない
  void close(OpenChat chat) {
    if (state == chat) state = null;
  }
}

/// [OpenChatNotifier]のProvider
/// アプリ全体で共有するため、破棄しない
final openChatProvider = NotifierProvider<OpenChatNotifier, OpenChat?>(OpenChatNotifier.new);

/// アプリを開いているときに受けた新着（開く先のトーク[target]）で、アプリ内バナーを出すか（機能仕様書4.4.6.2）
/// いま見ているトーク（[openChat]）宛てなら、画面に表示されているため出さない（別のトーク・別のアカウント宛て・トークのデータが無い通知では出す）
bool shouldShowForegroundBanner(NotificationTarget? target, OpenChat? openChat) {
  if (target == null || openChat == null) return true;
  return target.accountId != openChat.accountId || target.chatRoomId != openChat.chatRoomId;
}
