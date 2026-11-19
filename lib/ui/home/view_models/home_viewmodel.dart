import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/account.dart';
import '../../account/view_models/account_providers.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../account/view_models/invite_account_choice_provider.dart';
import '../../chat/view_models/chat_providers.dart';
import '../../friend/view_models/invite_link_provider.dart';
import '../../group/view_models/group_invite_providers.dart';
import '../../group/view_models/group_providers.dart';
import '../../friend/view_models/friend_request_providers.dart';
import '../../notification/view_models/notification_open_provider.dart';

// ============================================================
// 状態クラス
// ============================================================

/// ホーム（タブの枠）の状態
class HomeState {
  const HomeState({
    required this.activeAccount,
    required this.chatUnreadTotal,
    required this.chatHasGroupRequest,
    required this.friendHasRequest,
    required this.otherAccountsUnread,
    required this.otherAccountsHaveGroupRequest,
    required this.readyNotificationTarget,
    required this.readyInviteAccountId,
    required this.readyGroupInviteToken,
  });

  /// 使用中のアカウント
  /// ヘッダーのアバターと、追加・招待・QRの対象。使用中のアカウントが無ければnull
  final Account? activeAccount;

  /// ボトムナビ「トーク」タブの未読の合計（データ設計書3.2.4）
  final int chatUnreadTotal;

  /// 使用中のアカウントにグループへの招待が届いているか
  /// 未読数として数えられないため、trueならボトムナビ「トーク」タブに未読の合計に代えて「!」を出す
  final bool chatHasGroupRequest;

  /// 使用中のアカウントに友だち申請が届いているか（機能仕様書4.3.8.2）
  /// trueならボトムナビ「友だち」タブに「!」を出す
  final bool friendHasRequest;

  /// ほかのアカウントの未読の合計（ヘッダーのアバターのバッジ）
  final int otherAccountsUnread;

  /// ほかのアカウントのどれかにグループへの招待が届いているか
  /// trueならヘッダーのアバターに未読の合計に代えて「!」を出す
  final bool otherAccountsHaveGroupRequest;

  /// 通知のタップで開く予定の、今すぐ開けるトーク（機能仕様書4.4.6.1）
  /// 開けるものが無ければnull（パスコードを設定したアカウントは、ロックを解除するまでnull）
  final NotificationTarget? readyNotificationTarget;

  /// 招待リンクで開く予定の、今すぐ開ける招待（招待したアカウントのID）
  /// 開けるものが無ければnull（パスコードを設定したアカウントは、ロックを解除するまでnull）
  final String? readyInviteAccountId;

  /// 今すぐ開けるグループの招待トークン（機能仕様書4.7.2.5）
  final String? readyGroupInviteToken;
}

// ============================================================
// ViewModel
// ============================================================

/// ホーム（トーク一覧・友だち一覧・設定の3タブの枠）のViewModel
/// ヘッダー・ボトムナビに出す内容と、通知のタップで開くトーク・招待リンクで開く招待を渡す
///
/// 画面設計書：4章補足
class HomeViewModel extends Notifier<HomeState> {

  // ---- 状態・初期化 ----

  /// 表示内容を作る
  /// 使用中のアカウント・トークの表示区分・グループへの招待・ほかのアカウントの未読・開く予定のトーク・招待を監視し、変わるたびに作り直す
  @override
  HomeState build() {
    final activeAccount = ref.watch(activeAccountProvider);
    // 一覧に出すルーム（通常＋トークリクエスト）だけを集計し、ブロックした相手など一覧に出ないルームの未読が、
    // 見えないままバッジに残らないようにする。
    final sections = ref.watch(chatListSectionsProvider).value;
    final chatUnreadTotal = activeAccount == null || sections == null
        ? 0
        : sections.all.fold<int>(0, (sum, room) => sum + room.unreadCount);
    return HomeState(
      activeAccount: activeAccount,
      chatUnreadTotal: chatUnreadTotal,
      chatHasGroupRequest: activeAccount != null && (ref.watch(groupRequestsProvider).value?.isNotEmpty ?? false),
      friendHasRequest: activeAccount != null && ref.watch(visibleFriendRequestsProvider).isNotEmpty,
      otherAccountsUnread: ref.watch(otherAccountsUnreadTotalProvider),
      otherAccountsHaveGroupRequest: ref.watch(otherAccountsHaveGroupRequestProvider),
      readyNotificationTarget: ref.watch(readyNotificationTargetProvider),
      readyInviteAccountId: ref.watch(readyInviteProvider),
      readyGroupInviteToken: ref.watch(readyGroupInviteProvider),
    );
  }

  // ---- 操作 ----

  /// 通知のタップで開く予定のトーク[target]を、開いたものとして消す
  /// まだ開く予定のままならtrue（Viewがトークを開く）。すでに消えた・別の予定に変わったならfalse
  bool takeNotificationTarget(NotificationTarget target) {
    if (ref.read(pendingNotificationTargetProvider) != target) return false;
    ref.read(pendingNotificationTargetProvider.notifier).clear();
    return true;
  }

  /// 通知のタップで開く予定のトークのために、使用中のアカウントを切り替えたか
  bool get notificationSwitchedAccount => ref.read(pendingNotificationTargetProvider.notifier).switched;

  /// 招待リンクで開く予定の招待[accountId]を、開いたものとして消す
  /// まだ開く予定のままならtrue（Viewが開く）。すでに消えた・別の予定に変わったならfalse
  bool takeInvite(String accountId) => ref.read(inviteLinkOpenerProvider).take(accountId);

  /// 開く予定のグループの招待[token]を、開いたものとして消す
  bool takeGroupInvite(String token) => ref.read(pendingGroupInviteProvider.notifier).take(token);

  /// 開く予定の招待（招待したアカウント[accountId]）が、まだ開く予定のままか
  bool isInvitePending(String accountId) => ref.read(pendingInviteProvider) == accountId;

  /// 開く予定のグループの招待[token]が、まだ開く予定のままか
  bool isGroupInvitePending(String token) => ref.read(pendingGroupInviteProvider) == token;

  /// 開く予定の招待を、開かずに消す（アカウントを選ぶシートを閉じた）
  void dismissInvite() => ref.read(pendingInviteProvider.notifier).clear();

  /// 開く予定のグループの招待を、開かずに消す（アカウントを選ぶシートを閉じた）
  void dismissGroupInvite() => ref.read(pendingGroupInviteProvider.notifier).clear();

  /// [accountId]が自分の持つアカウント（使用中以外も含む）か
  bool isOwnAccount(String accountId) =>
      (ref.read(accountsProvider).value ?? const []).any((account) => account.id == accountId);

  /// 外部から届いた招待で使うアカウントの決め方
  /// 招待で使うアカウントを選んで切り替えた後（[takeInviteAccountChoice]の前）は、選び直さないようnull
  InviteAccountDecision? get inviteAccountDecision {
    if (ref.read(inviteAccountChoiceProvider) != null) return null;
    return ref.read(inviteAccountDecisionProvider);
  }

  /// 招待で使うアカウントに[accountId]を選び、使用中のアカウントを切り替える
  /// パスコードを設定したアカウントは、解除してから招待が開く（開く予定の招待は、切り替え後に改めて流れてくる）
  Future<void> chooseInviteAccount(String accountId) async {
    ref.read(inviteAccountChoiceProvider.notifier).choose(accountId);
    await ref.read(activeAccountIdProvider.notifier).setActive(accountId);
  }

  /// 招待を開くときに、選んだアカウントの記録を消す
  /// 招待のために使用中のアカウントを切り替えていたらtrue（Viewが切り替えたことを知らせる）
  bool takeInviteAccountChoice() {
    final switched = ref.read(inviteAccountChoiceProvider) != null;
    ref.read(inviteAccountChoiceProvider.notifier).clear();
    return switched;
  }

  /// 招待したアカウント[accountId]を、使用中のアカウント[myAccountId]から友だち追加する候補として解決する
  /// 解決できたらそのアカウント、できなければ失敗の種類を返す
  Future<({Account? account, InviteLinkError? error})> resolveInvite({
    required String accountId,
    required String myAccountId,
  }) => ref.read(inviteLinkOpenerProvider).resolve(accountId: accountId, myAccountId: myAccountId);
}

// ============================================================
// Provider
// ============================================================

/// [HomeViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final homeViewModelProvider = NotifierProvider.autoDispose<HomeViewModel, HomeState>(HomeViewModel.new);
