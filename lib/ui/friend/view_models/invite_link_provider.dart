import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_flavor.dart';
import '../../../config/invite_links.dart';
import '../../../config/preferences_provider.dart';
import '../../../config/service_providers.dart';
import '../../../domain/models/account.dart';
import '../../account/view_models/account_providers.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../account/view_models/invite_account_choice_provider.dart';
import '../../auth/view_models/auth_gate_viewmodel.dart';
import '../../group/view_models/group_invite_providers.dart';
import '../../passcode/view_models/passcode_providers.dart';
import 'friend_invite_key_providers.dart';

// ============================================================
// enum
// ============================================================

/// 招待リンクからの友だち追加の失敗
/// Viewが表示の文言に変換する
enum InviteLinkError {
  /// 自分のアカウントの招待リンクだった
  selfAdd,
  /// 見つからなかった（退会済み・ブロック関係にあるアカウントも含む）
  notFound,
}

// ============================================================
// ViewModel
// ============================================================

/// 招待リンクで開く予定の、招待したアカウントのID
/// 開いたら（[HomeShell]が）消す
///
/// 未ログイン・アカウント未作成・アカウント未選択の間も持ち続け、ホームを開けた時点で処理する
/// SMS認証の間にアプリが終了しても失わないよう、端末にも保存する
class PendingInviteNotifier extends Notifier<String?> {

  // ---- 状態・初期化 ----

  /// 端末に保存するキー
  static const _prefsKey = 'pendingInviteAccountId';

  /// 最初の状態を作る
  /// 端末に保存した招待があれば、そこから始める
  @override
  String? build() => ref.read(sharedPreferencesProvider).getString(_prefsKey);

  // ---- 操作 ----

  /// 開く予定の招待を設定する（後から開いたリンクで上書きする）
  void set(String accountId) {
    state = accountId;
    ref.read(sharedPreferencesProvider).setString(_prefsKey, accountId);
  }

  /// 開く予定を消す
  void clear() {
    state = null;
    ref.read(sharedPreferencesProvider).remove(_prefsKey);
  }
}

/// [PendingInviteNotifier]のProvider
/// アプリ全体で共有するため、破棄しない
final pendingInviteProvider = NotifierProvider<PendingInviteNotifier, String?>(PendingInviteNotifier.new);

// ============================================================
// Provider
// ============================================================

/// 招待リンクの受け取り
/// アプリの最上位（[MultiIdMsgApp]）で`ref.listen`されることで動き出す、副作用だけのProvider
///
/// アプリを開いたリンクのうち、この環境の招待リンクだけを、開く予定の招待にする（ログイン前に開いたリンクも、ログイン・アカウント作成の後に処理する）
final inviteLinkInitProvider = Provider<void>((ref) {
  final subscription = ref.watch(inviteLinkServiceProvider).links.listen((uri) {
    final accountId = InviteLinks.accountIdFrom(uri, currentFlavor);
    if (accountId != null) ref.read(pendingInviteProvider.notifier).set(accountId);
    ref.read(receivedInviteKeysProvider.notifier).rememberFromLink(uri);
    final groupToken = InviteLinks.groupTokenFrom(uri, currentFlavor);
    if (groupToken != null) ref.read(pendingGroupInviteProvider.notifier).set(groupToken);
  }, onError: (Object _) {}); // 読めないリンクは無視し、通常の起動のまま
  ref.onDispose(subscription.cancel);
});

/// クリップボードからの招待の引き継ぎ（機能仕様書4.3.5.2）
/// アプリの最上位（[MultiIdMsgApp]）で`ref.listen`されることで動き出す、副作用だけのProvider
///
/// ログインしていない間だけ確かめる（アップデートしただけの人に、貼り付けボタンを出さないため）
/// 貼り付けボタンで受け取った本文は、ログインの状態に関係なく受け取る
final inviteClipboardInitProvider = Provider<void>((ref) {
  ref.listen(authGateViewModelProvider, (_, status) {
    if (status == AuthGateStatus.signedOut) ref.read(inviteClipboardRestorerProvider).check();
  }, fireImmediately: true);
  final subscription = ref.watch(inviteClipboardServiceProvider).pasted.listen(
    (text) => ref.read(inviteClipboardRestorerProvider).receive(text),
  );
  ref.onDispose(subscription.cancel);
});

/// 今すぐ開ける招待（招待したアカウントのID）
/// 使用中のアカウントがあり、パスコードのガードが開いているときだけ値を持つ
/// 招待で使うアカウントを選んで切り替えている途中は、選んだアカウントが使用中になるまで値を持たない
final readyInviteProvider = Provider<String?>((ref) {
  final accountId = ref.watch(pendingInviteProvider);
  if (accountId == null) return null;
  if (ref.watch(activeAccountIdProvider) == null) return null;
  if (!ref.watch(inviteAccountReadyProvider)) return null;
  if (ref.watch(passcodeGuardStatusProvider) != PasscodeGuardStatus.open) return null;
  return accountId;
});

// ============================================================
// 招待リンクを開く処理
// ============================================================

/// 招待リンクを開く処理
class InviteLinkOpener {
  InviteLinkOpener(this._ref);

  // ---- 状態・初期化 ----

  /// Providerを読むためのRef
  final Ref _ref;

  // ---- 操作 ----

  /// 開く予定の招待[accountId]を、開いたものとして消す
  /// まだ開く予定のままならtrue（Viewが開く）。すでに消えた・別の予定に変わったならfalse
  bool take(String accountId) {
    if (_ref.read(pendingInviteProvider) != accountId) return false;
    _ref.read(pendingInviteProvider.notifier).clear();
    return true;
  }

  /// 招待したアカウント[accountId]を、使用中のアカウント[myAccountId]から友だち追加する候補として解決する
  /// QRコード（4.3.1.2）と同じく、退会済み・ブロック関係にあるアカウントは「見つからない」扱いにする（ブロックした事実を悟らせない）
  Future<({Account? account, InviteLinkError? error})> resolve({
    required String accountId,
    required String myAccountId,
  }) async {
    // 自分が持つ別のアカウントの招待リンクも、自分自身として扱う。
    final ownAccounts = _ref.read(accountsProvider).value ?? const [];
    if (accountId == myAccountId || ownAccounts.any((account) => account.id == accountId)) {
      return (account: null, error: InviteLinkError.selfAdd);
    }

    Account? found;
    try {
      found = await _ref.read(accountRepositoryProvider).getAccount(accountId);
      if (found != null && !found.isDeleted) {
        final blocked = await _ref.read(blockRepositoryProvider).isBlockedEitherWay(myAccountId, found.id);
        if (blocked) found = null;
      }
    } catch (_) {
      found = null;
    }

    if (found == null || found.isDeleted) return (account: null, error: InviteLinkError.notFound);
    return (account: found, error: null);
  }
}

/// [InviteLinkOpener]のProvider
final inviteLinkOpenerProvider = Provider<InviteLinkOpener>((ref) => InviteLinkOpener(ref));

// ============================================================
// クリップボードからの招待の引き継ぎ
// ============================================================

/// 招待の貼り付けボタン（AUT-02）の表示の状態（機能仕様書4.3.5.2）
enum InvitePasteStatus {
  /// 出さない
  hidden,
  /// 出している
  offered,
  /// 貼り付けた本文が、招待リンクではなかった
  notInvite,
  /// 招待を受け取った（招待したアカウントのIDは[pendingInviteProvider]、グループは[pendingGroupInviteProvider]）
  received,
}

/// 招待の貼り付けボタンの表示の状態
/// 端末に保存しない（アプリを開き直したら出さない）
class InvitePasteNotifier extends Notifier<InvitePasteStatus> {
  @override
  InvitePasteStatus build() => InvitePasteStatus.hidden;

  /// 状態を変える
  void set(InvitePasteStatus status) => state = status;
}

/// [InvitePasteNotifier]のProvider
final invitePasteProvider = NotifierProvider<InvitePasteNotifier, InvitePasteStatus>(InvitePasteNotifier.new);

/// 案内ページがコピーした招待リンクを、初回起動時に引き継ぐ処理（機能仕様書4.3.5.2）
/// App Storeからアプリを開くと招待リンクがアプリに届かないため、クリップボードで引き継ぐ
/// クリップボードの本文は自分では読まず、貼り付けボタンが押されたときに受け取る（iOSの貼り付けの確認を出さないため）
class InviteClipboardRestorer {
  InviteClipboardRestorer(this._ref);

  // ---- 状態・初期化 ----

  /// 確認済みかどうかを端末に保存するキー
  static const _checkedKey = 'inviteClipboardChecked';

  /// Providerを読むためのRef
  final Ref _ref;

  // ---- 操作 ----

  /// クリップボードにURLがありそうなら、貼り付けボタンを出す
  /// 確認は1回だけ。すでに開く予定の招待があれば、出さない
  Future<void> check() async {
    final preferences = _ref.read(sharedPreferencesProvider);
    if (preferences.getBool(_checkedKey) ?? false) return;
    await preferences.setBool(_checkedKey, true);
    if (_hasPendingInvite()) return;
    if (!await _ref.read(inviteClipboardServiceProvider).hasUrl()) return;
    // 確かめている間に招待リンクでアプリが開いた場合は、そちらを使う。
    if (_hasPendingInvite()) return;
    _ref.read(invitePasteProvider.notifier).set(InvitePasteStatus.offered);
  }

  /// 貼り付けボタンで受け取った本文[text]が招待リンクなら、開く予定の招待にする
  void receive(String text) {
    final uri = Uri.tryParse(text.trim());
    final accountId = uri == null ? null : InviteLinks.accountIdFrom(uri, currentFlavor);
    final groupToken = uri == null ? null : InviteLinks.groupTokenFrom(uri, currentFlavor);
    if (accountId != null) _ref.read(pendingInviteProvider.notifier).set(accountId);
    if (uri != null) _ref.read(receivedInviteKeysProvider.notifier).rememberFromLink(uri);
    if (groupToken != null) _ref.read(pendingGroupInviteProvider.notifier).set(groupToken);
    final received = accountId != null || groupToken != null;
    _ref.read(invitePasteProvider.notifier).set(received ? InvitePasteStatus.received : InvitePasteStatus.notInvite);
  }

  /// 貼り付けボタンを閉じる
  void dismiss() => _ref.read(invitePasteProvider.notifier).set(InvitePasteStatus.hidden);

  /// 開く予定の招待（友だち・グループ）があるか
  bool _hasPendingInvite() => _ref.read(pendingInviteProvider) != null || _ref.read(pendingGroupInviteProvider) != null;
}

/// [InviteClipboardRestorer]のProvider
final inviteClipboardRestorerProvider = Provider<InviteClipboardRestorer>((ref) => InviteClipboardRestorer(ref));
