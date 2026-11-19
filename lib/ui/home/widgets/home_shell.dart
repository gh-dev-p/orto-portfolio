import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/ui/app_bottom_nav.dart';
import '../../core/ui/app_home_header.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/notification_target.dart';
import '../view_models/home_viewmodel.dart';
import '../../account/view_models/invite_account_choice_provider.dart';
import '../../account/widgets/account_list_screen.dart';
import '../../account/widgets/invite_account_sheet.dart';
import '../../chat/widgets/chat_screen.dart';
import '../../chat_list/widgets/chat_list_body.dart';
import '../../friend/widgets/add_friend_menu_screen.dart';
import '../../group/view_models/group_providers.dart';
import '../../friend/view_models/friend_request_providers.dart';
import '../../group/widgets/group_friend_picker_screen.dart';
import '../../group/widgets/group_join_screen.dart';
import '../../group/widgets/join_requests_screen.dart';
import '../../friend/widgets/friend_list_body.dart';
import '../../friend/view_models/invite_link_provider.dart';
import '../../friend/widgets/invite_share.dart';
import '../../profile/widgets/friend_profile_screen.dart';
import '../../qr/widgets/qr_scan_screen.dart';
import '../../settings/widgets/settings_body.dart';

// ============================================================
// 画面
// ============================================================

/// ホームの枠（画面設計書4章補足）
/// トーク一覧・友だち一覧・設定の3タブを持つ
///
/// ヘッダー（[AppHomeHeader]）とボトムナビ（[AppBottomNav]）はタブを切り替えても同じ位置に居続けるため、HomeShellが1回だけ持ち、IndexedStackでは各タブの本文だけを切り替える
/// Navigatorのpush・popを使わず表示の切り替えだけで行うため、各タブのスクロール位置等は切り替えをまたいで保たれる
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // ---- 状態・初期化 ----

  /// 表示中のタブの番号
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // 通知のタップで開く予定のトーク（機能仕様書4.4.6.1）が開ける状態になったら開く。パスコードを設定した
    // アカウントは、ロックを解除するまで開ける状態にならない。アカウントを切り替えた直後に本画面が
    // 作られる場合もあるため、作られた時点の値でも判定する。
    ref.listenManual(homeViewModelProvider.select((state) => state.readyNotificationTarget), (_, target) {
      if (target != null) _openChatFromNotification(target);
    }, fireImmediately: true);
    // 招待リンクで開く予定の招待も同様に、開ける状態になったら開く。ログイン・アカウント作成・
    // アカウント選択の前に開いたリンクは、本画面が作られた時点で開く。
    ref.listenManual(homeViewModelProvider.select((state) => state.readyInviteAccountId), (_, accountId) {
      if (accountId != null) _openInvite(accountId);
    }, fireImmediately: true);
    ref.listenManual(homeViewModelProvider.select((state) => state.readyGroupInviteToken), (_, token) {
      if (token != null) _openGroupInvite(token);
    }, fireImmediately: true);
  }

  // ---- 操作 ----

  /// 通知のタップで開く予定のトークを開く
  /// ホームより上の画面（別のトーク・アカウント一覧のシート等）を閉じてから開く。グループへの招待の通知では、トーク一覧の「グループへの招待」を開く
  void _openChatFromNotification(NotificationTarget target) {
    // 画面の構築中にProviderを変更・画面遷移しないよう、描画の後に行う。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewModel = ref.read(homeViewModelProvider.notifier);
      final switched = viewModel.notificationSwitchedAccount;
      if (!viewModel.takeNotificationTarget(target)) return;
      // 別のアカウントのつもりで返信しないよう、切り替わったことを知らせる。
      final accountName = ref.read(homeViewModelProvider).activeAccount?.displayName;
      if (switched && accountName != null) {
        showAppSnackBar(context, AppLocalizations.of(context)!.notificationSwitchedAccount(accountName));
      }
      final navigator = Navigator.of(context);
      navigator.popUntil((route) => route.isFirst);
      if (target.isGroupInvite) {
        setState(() => _currentIndex = 0);
        ref.read(groupRequestsExpandedProvider.notifier).expand();
        return;
      }
      // 友だち申請の通知では、FRI-01の「友だち申請」を開く（機能仕様書4.3.8.2）
      if (target.isFriendRequest) {
        setState(() => _currentIndex = 1);
        ref.read(friendRequestsExpandedProvider.notifier).expand();
        return;
      }
      // 参加の申請の結果（承認以外）は、トーク一覧の「参加の申請」を開く（機能仕様書4.7.8.5）
      if (target.opensJoinApplications) {
        setState(() => _currentIndex = 0);
        ref.read(joinApplicationsExpandedProvider.notifier).expand();
        return;
      }
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatRoomId: target.chatRoomId,
            myAccountId: target.accountId,
            peerAccountId: target.peerAccountId,
          ),
        ),
      );
      // 参加の申請が届いた通知は、トークの上にGRP-09（参加の申請）を開く
      if (target.isJoinRequest) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => JoinRequestsScreen(chatRoomId: target.chatRoomId, myAccountId: target.accountId),
          ),
        );
      }
    });
  }

  /// アカウントを選ぶシートを出している間か（同時に2つ出さない）
  bool _choosingInviteAccount = false;

  /// 外部から届いた招待で使うアカウントを決める
  /// 選べるアカウントが2つ以上ならシートで選んでもらう。1つならそのアカウントを使う
  ///
  /// 使用中のアカウントのまま開いてよければtrue。シートを閉じた（[dismiss]で招待を消す）・選んだアカウントへ
  /// 切り替えに行った（切り替え・パスコードの解除の後に、開く予定の招待が改めて流れてくる）ならfalse
  Future<bool> _confirmInviteAccount({
    required bool forGroup,
    required bool Function() stillPending,
    required VoidCallback dismiss,
  }) async {
    final viewModel = ref.read(homeViewModelProvider.notifier);
    final myAccountId = ref.read(homeViewModelProvider).activeAccount?.id;
    final decision = viewModel.inviteAccountDecision;
    if (myAccountId == null || decision == null) return true;
    final String chosen;
    switch (decision) {
      case InviteAccountUse(:final accountId):
        chosen = accountId;
      case InviteAccountAsk():
        if (_choosingInviteAccount) return false;
        _choosingInviteAccount = true;
        final picked = await showInviteAccountSheet(context, ask: decision, forGroup: forGroup);
        _choosingInviteAccount = false;
        if (!mounted) return false;
        if (!stillPending()) {
          // シートを出している間に別の招待が届いていれば、そちらを開く。
          _replayReadyInvites();
          return false;
        }
        if (picked == null) {
          dismiss();
          return false;
        }
        chosen = picked;
    }
    if (chosen == myAccountId) return true;
    await viewModel.chooseInviteAccount(chosen);
    // 切り替えの前後で開く予定の招待の値が同じままだと、監視では流れてこないため、描画の後に確かめ直す
    // （パスコードを設定したアカウントは、解除した時点で監視から流れてくる）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _replayReadyInvites();
    });
    return false;
  }

  /// 今すぐ開ける招待があれば開く（シートを出している間に届いた招待のため）
  void _replayReadyInvites() {
    final state = ref.read(homeViewModelProvider);
    final accountId = state.readyInviteAccountId;
    if (accountId != null) _openInvite(accountId);
    final token = state.readyGroupInviteToken;
    if (token != null) _openGroupInvite(token);
  }

  /// 招待のために使用中のアカウントを切り替えていたら、そのことを知らせる
  /// 別のアカウントのつもりで操作しないよう、通知のタップと同じく案内する
  void _notifyInviteAccountSwitched() {
    if (!ref.read(homeViewModelProvider.notifier).takeInviteAccountChoice()) return;
    final accountName = ref.read(homeViewModelProvider).activeAccount?.displayName;
    if (accountName != null) showAppSnackBar(context, AppLocalizations.of(context)!.inviteSwitchedAccount(accountName));
  }

  /// グループの招待リンクで開く予定の招待を開く（機能仕様書4.7.2.5）
  /// 参加するアカウントを決めてから、ホームより上の画面を閉じてGRP-05を開く
  void _openGroupInvite(String token) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final viewModel = ref.read(homeViewModelProvider.notifier);
      if (!mounted || !viewModel.isGroupInvitePending(token)) return;
      final confirmed = await _confirmInviteAccount(
        forGroup: true,
        stillPending: () => viewModel.isGroupInvitePending(token),
        dismiss: viewModel.dismissGroupInvite,
      );
      if (!confirmed || !mounted) return;
      final myAccountId = ref.read(homeViewModelProvider).activeAccount?.id;
      if (myAccountId == null || !viewModel.takeGroupInvite(token)) return;
      final navigator = Navigator.of(context);
      navigator.popUntil((route) => route.isFirst);
      _notifyInviteAccountSwitched();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => GroupJoinScreen(token: token, myAccountId: myAccountId),
        ),
      );
    });
  }

  /// 招待リンクで開く予定の招待を開く
  /// 追加に使うアカウントを決めてから、ホームより上の画面を閉じて招待したアカウントのプロフィール（PRO-01）を開く。
  /// 開けなければSnackBarで知らせる。自分が持つアカウントの招待リンクは、アカウントを選ばずに知らせる
  void _openInvite(String accountId) {
    // 画面の構築中にProviderを変更・画面遷移しないよう、描画の後に行う。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final viewModel = ref.read(homeViewModelProvider.notifier);
      if (!mounted || !viewModel.isInvitePending(accountId)) return;
      if (!viewModel.isOwnAccount(accountId)) {
        final confirmed = await _confirmInviteAccount(
          forGroup: false,
          stillPending: () => viewModel.isInvitePending(accountId),
          dismiss: viewModel.dismissInvite,
        );
        if (!confirmed || !mounted) return;
      }
      final myAccountId = ref.read(homeViewModelProvider).activeAccount?.id;
      if (myAccountId == null || !viewModel.takeInvite(accountId)) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      _notifyInviteAccountSwitched();

      final result = await ref
          .read(loadingOverlayProvider.notifier)
          .run(() => viewModel.resolveInvite(accountId: accountId, myAccountId: myAccountId));
      // 解決の間にアカウントを切り替えた場合は、切り替え前のアカウントからの追加になるため開かない。
      if (!mounted || ref.read(homeViewModelProvider).activeAccount?.id != myAccountId) return;

      final found = result.account;
      if (found == null) {
        final l10n = AppLocalizations.of(context)!;
        showAppSnackBar(context, switch (result.error) {
          InviteLinkError.selfAdd => l10n.friInviteLinkSelf,
          _ => l10n.friInviteLinkNotFound,
        });
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FriendProfileScreen(accountId: found.id, myAccountId: myAccountId),
        ),
      );
    });
  }

  /// ボトムナビのタップで、タブを切り替える
  void _handleNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  // ---- 画面 ----

  /// ヘッダー・表示中のタブの本文・ボトムナビを描く
  @override
  Widget build(BuildContext context) {
    // アカウントの切り替え時は、切り替え前にどのタブを開いていても必ずトーク一覧に着地させる。
    ref.listen(homeViewModelProvider.select((state) => state.activeAccount?.id), (previous, next) {
      if (previous != next && _currentIndex != 0) setState(() => _currentIndex = 0);
    });
    final state = ref.watch(homeViewModelProvider);
    final activeAccount = state.activeAccount;
    final chatUnreadTotal = state.chatUnreadTotal;
    final l10n = AppLocalizations.of(context)!;
    final titles = [l10n.appHomeHeaderChatTitle, l10n.appHomeHeaderFriendTitle, l10n.appHomeHeaderSettingsTitle];

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            AppHomeHeader(
              // ヘッダータイトル
              title: titles[_currentIndex],

              // アバター（アクティブアカウント）と、他アカウントの未読合計
              avatarDisplayName: activeAccount?.displayName,
              avatarPhotoURL: activeAccount?.photoURL,
              otherAccountsUnread: state.otherAccountsUnread,
              otherAccountsHaveGroupRequest: state.otherAccountsHaveGroupRequest,

              // 追加ボタン
              onAdd: activeAccount == null ? null : () => showAddFriendMenu(context, myAccountId: activeAccount.id),

              // グループ作成
              onCreateGroup: activeAccount == null
                  ? null
                  : () => openGroupCreation(context, myAccountId: activeAccount.id),

              // 招待ボタン
              onInvite: activeAccount == null ? null : () => shareInvite(context, myAccountId: activeAccount.id),

              // QRボタン
              onTapQr: () {
                if (activeAccount == null) return;
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => QrScanScreen(myAccountId: activeAccount.id)));
              },

              // アカウントボタン
              onTapAvatar: () => showAccountSwitcherDialog(context),
            ),

            SizedBox(height: 0),

            // メインコンテナ
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: const [ChatListBody(), FriendListBody(), SettingsBody()],
              ),
            ),

            // ボトムナビ
            AppBottomNav(
              currentIndex: _currentIndex,
              chatUnreadCount: chatUnreadTotal,
              chatHasGroupRequest: state.chatHasGroupRequest,
              friendHasRequest: state.friendHasRequest,
              onTap: _handleNavTap,
            ),
          ],
        ),
      ),
    );
  }
}
