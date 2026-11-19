import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../account/view_models/account_providers.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/header_icon_button.dart';
import '../../core/ui/text_edit_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/chat_room.dart';
import '../../../domain/models/friend_request.dart';
import '../../friend/widgets/friend_request_failure_message.dart';
import '../../group/widgets/group_system_text.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../block/widgets/block_flow.dart';
import '../view_models/friend_profile_viewmodel.dart';
import '../../chat/widgets/chat_screen.dart';
import 'add_friend_button.dart';
import '../../report/view_models/report_viewmodel.dart';
import '../../report/widgets/report_screen.dart';
import 'block_button.dart';
import 'friend_memo_tile.dart';
import 'report_button.dart';
import 'profile_action_button.dart';
import 'profile_layout.dart';

// ============================================================
// 画面
// ============================================================

/// 画面PRO-01：友だちのプロフィール
/// 友だち一覧から開くほか、FRI-04（検索結果）・QRC-01（QRの読み取り）から開いたときは、友だち追加の確認・確定の画面も兼ねる（追加した後は自動でトークのアイコンに切り替わる）
/// グループのメンバーの画面から開いたとき（[groupChatRoomId]）は、友だち追加の代わりに友だち申請を出す
///
/// 通話・ビデオ通話はアプリに無い機能のため、アイコンを置かない
///
/// 機能仕様書：4.5.2・4.3.1・4.3.8・4.3.3・4.3.4 / 画面設計書：5.7.1
class FriendProfileScreen extends ConsumerStatefulWidget {
  const FriendProfileScreen({
    super.key,
    required this.accountId,
    required this.myAccountId,
    this.openedFromChat = false,
    this.groupChatRoomId,
  });

  /// 表示する相手のアカウントID
  final String accountId;

  /// 自分のアカウントID
  final String myAccountId;

  /// CHA-02（トーク）のヘッダーのタップから開いたか
  /// trueなら、すでに相手とのトークから開いているため、トークのアイコンは出さない
  final bool openedFromChat;

  /// グループのメンバーの画面（GRP-03のメンバー・CHA-02（グループ）の送信者）から開いたときの、そのグループのチャットルームID
  /// 指定すると、友だちでない相手には「友だち追加」の代わりに「友だち申請」を出す（機能仕様書4.3.8）
  final String? groupChatRoomId;

  @override
  ConsumerState<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  // ---- 操作 ----

  /// この画面のViewModelのProvider
  late final _provider = friendProfileViewModelProvider((
    accountId: widget.accountId,
    myAccountId: widget.myAccountId,
    groupChatRoomId: widget.groupChatRoomId,
  ));

  /// この画面のViewModel
  FriendProfileViewModel get _viewModel => ref.read(_provider.notifier);

  /// この画面で友だちに追加したか
  /// trueなら、×で検索・QRなどの元の画面ではなくホームまで戻る
  bool _addedHere = false;

  /// 相手を友だちに追加する
  /// 失敗したらSnackBarで知らせる
  Future<void> _addFriend() async {
    if (ref.read(_provider).adding) return;
    if (ref.read(isReadOnlyProvider(widget.myAccountId))) {
      showAppSnackBar(context, AppLocalizations.of(context)!.planReadOnlyNotice);
      return;
    }
    final ok = await ref.read(loadingOverlayProvider.notifier).run(_viewModel.addFriend);
    if (ok) _addedHere = true;
    if (!ok && mounted) showAppSnackBar(context, AppLocalizations.of(context)!.proFriendAddFailed);
  }

  /// グループのメンバーに友だち申請を送る（機能仕様書4.3.8.1）
  /// 送ったら（相手から届いていて承認になったら、その旨を）SnackBarで知らせる。失敗も同じく知らせる
  Future<void> _sendFriendRequest() async {
    if (ref.read(_provider).adding) return;
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(isReadOnlyProvider(widget.myAccountId))) {
      showAppSnackBar(context, l10n.planReadOnlyNotice);
      return;
    }
    try {
      final accepted = await ref.read(loadingOverlayProvider.notifier).run(_viewModel.sendFriendRequest);
      if (!mounted) return;
      showAppSnackBar(context, accepted ? l10n.frqAccepted(_peerName(l10n)) : l10n.frqSent);
    } on FriendRequestException catch (error) {
      if (mounted) {
        showAppSnackBar(context, friendRequestFailureMessage(l10n, error.failure, fallback: l10n.frqSendFailed));
      }
    }
  }

  /// 相手から届いている友だち申請を承認する（機能仕様書4.3.8.2）
  Future<void> _acceptFriendRequest() async {
    if (ref.read(_provider).adding) return;
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(isReadOnlyProvider(widget.myAccountId))) {
      showAppSnackBar(context, l10n.planReadOnlyNotice);
      return;
    }
    try {
      await ref.read(loadingOverlayProvider.notifier).run(_viewModel.acceptFriendRequest);
      if (mounted) showAppSnackBar(context, l10n.frqAccepted(_peerName(l10n)));
    } on FriendRequestException catch (error) {
      if (mounted) {
        showAppSnackBar(context, friendRequestFailureMessage(l10n, error.failure, fallback: l10n.frqRespondFailed));
      }
    }
  }

  /// SnackBarに入れる相手の名前（「さん」付き。グループのシステムメッセージと同じ決まり）
  String _peerName(AppLocalizations l10n) =>
      groupPersonName(l10n, ref.read(_provider).account?.displayName ?? l10n.commonUnknownAccount);

  /// ×で画面を閉じる
  /// この画面で友だちに追加した後は、追加し終えた検索・QRなどの画面へは戻らず、ホームまで戻る
  void _close() {
    final navigator = Navigator.of(context);
    if (_addedHere) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      navigator.pop();
    }
  }

  /// 確認ダイアログの後、相手をブロックする
  /// ブロックしたら、相手のトークやこの画面が画面の積み重ねに残らないよう、ホームまで戻る
  Future<void> _block() async {
    if (ref.read(_provider).blocking) return;
    final viewModel = _viewModel;
    viewModel.setBlocking(true);
    final blocked = await confirmAndBlockAccount(context: context, ref: ref, block: viewModel.block);
    if (!mounted) return;
    if (blocked) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      viewModel.setBlocking(false);
    }
  }

  /// REP-01で相手を通報する
  /// 同時にブロックもしたら、ブロックと同じくホームまで戻る
  Future<void> _report() async {
    final outcome = await openReport(
      context,
      (
        myAccountId: widget.myAccountId,
        targetAccountId: widget.accountId,
        messageId: null,
        chatRoomId: null,
        albumId: null,
        albumItemId: null,
      ),
    );
    if (outcome == ReportOutcome.reportedAndBlocked && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// ニックネームの編集シートを出し、確定したら保存する（機能仕様書4.3.3）
  /// 失敗したらSnackBarで知らせる
  Future<void> _editNickname(String? currentNickname) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showTextEditSheet(
      context,
      title: l10n.proNicknameDialogTitle,
      initialValue: currentNickname ?? '',
      maxLength: 20,
      hintText: l10n.proNicknameDialogHint,
    );
    if (result == null || !mounted) return;
    final ok = await ref.read(loadingOverlayProvider.notifier).run(() => _viewModel.updateNickname(result));
    if (!ok && mounted) showAppSnackBar(context, l10n.proNicknameSaveFailed);
  }

  /// メモの編集シートを出し、確定したら保存する（機能仕様書4.3.7）
  /// 失敗したらSnackBarで知らせる
  Future<void> _editMemo(String? currentMemo) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showTextEditSheet(
      context,
      title: l10n.proMemoSheetTitle,
      initialValue: currentMemo ?? '',
      maxLength: 500,
      hintText: l10n.proMemoHint,
      maxLines: 5,
    );
    if (result == null || !mounted) return;
    final ok = await ref.read(loadingOverlayProvider.notifier).run(() => _viewModel.updateMemo(result));
    if (!ok && mounted) showAppSnackBar(context, l10n.proMemoSaveFailed);
  }

  /// メモのピン留めを切り替える（機能仕様書4.3.7）
  /// 失敗したらSnackBarで知らせる
  Future<void> _toggleMemoPin(bool pinned) async {
    final failedMessage = AppLocalizations.of(context)!.proMemoSaveFailed;
    final ok = await _viewModel.updateMemoPinned(pinned);
    if (!ok && mounted) showAppSnackBar(context, failedMessage);
  }

  // ---- 画面 ----

  /// 背景・アバター・表示名・ひとことと、トーク・友だち追加・ブロックのボタンを描く
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final account = state.account;
    final isFriend = state.isFriend;
    final isDeletedPeer = state.isDeletedPeer;
    final nickname = state.friend?.nickname;
    final memo = state.friend?.memo;
    final memoPinned = state.friend?.memoPinned ?? false;
    final l10n = AppLocalizations.of(context)!;
    final displayedName = resolveDisplayName(
      account,
      nickname: nickname,
      unknownAccountLabel: l10n.commonUnknownAccount,
      deletedAccountLabel: l10n.commonDeletedAccount,
    );

    // チャットアイコン（友だちのとき）・友だち追加ボタン（友だちでないとき）。退会済みの相手と、CHA-02から
    // 開いた場合のチャットアイコン（同じトークへ戻るだけで冗長なため）は出さない。
    final Widget? actions;
    if (isDeletedPeer || (isFriend && widget.openedFromChat)) {
      actions = null;
    } else if (isFriend) {
      actions = ProfileActionButton(
        icon: CupertinoIcons.chat_bubble,
        // トークから戻ったときにこのプロフィール画面ではなくホーム画面へ
        // 戻るよう、ホームより上の画面を取り除いてからトークを開く。
        onTap: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatRoomId: buildChatRoomId(widget.myAccountId, widget.accountId),
              myAccountId: widget.myAccountId,
              peerAccountId: widget.accountId,
            ),
          ),
          (route) => route.isFirst,
        ),
      );
    } else if (widget.groupChatRoomId != null) {
      // グループのメンバーの画面から開いたときは、友だち追加の代わりに友だち申請（IDは出さない）。
      final myName = ref.watch(
        accountsProvider.select(
          (async) => async.value?.where((own) => own.id == widget.myAccountId).firstOrNull?.displayName,
        ),
      );
      final caption = switch (state.requestStatus) {
        FriendRequestStatus.none => myName == null ? null : l10n.frqSendAs(myName),
        FriendRequestStatus.received => l10n.frqReceivedNotice,
        FriendRequestStatus.pending => null,
      };
      actions = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          switch (state.requestStatus) {
            FriendRequestStatus.none => AddFriendButton(
              key: const Key('friend-profile-send-request'),
              label: l10n.frqSendButton,
              onTap: _sendFriendRequest,
            ),
            FriendRequestStatus.pending => const FriendRequestPendingChip(),
            FriendRequestStatus.received => AddFriendButton(
              key: const Key('friend-profile-accept-request'),
              label: l10n.frqAcceptButton,
              onTap: _acceptFriendRequest,
            ),
          },
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(
              caption,
              key: const Key('friend-profile-request-caption'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
            ),
          ],
        ],
      );
    } else {
      // どのアカウントで追加するかを出す（アプリの中の操作は使用中のアカウントで固定、外部の招待はシートで選んだアカウント）。
      final myName = ref.watch(
        accountsProvider.select(
          (async) => async.value?.where((own) => own.id == widget.myAccountId).firstOrNull?.displayName,
        ),
      );
      actions = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AddFriendButton(onTap: _addFriend),
          if (myName != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.proAddAs(myName),
              key: const Key('friend-profile-add-as'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: ProfileLayout(
        backgroundURL: account?.visibleBackgroundURL,
        // 右上は「閉じる」アイコン（QRC-01・FRI-02等の×とそろえて右上に置く）。挙動は「戻る」（pop）で、
        // この画面で友だちに追加した後だけホームまで戻る。閲覧専用画面のため破棄すべき入力は無く、「キャンセル」の意味合いではない。
        topBar: Align(
          alignment: Alignment.topRight,
          child: HeaderIconButton(icon: Icons.close, onTap: _close),
        ),
        center: account == null
            ? null
            : ProfileSummary(
                displayName: displayedName,
                photoURL: account.visiblePhotoURL,
                // ニックネーム編集は既に友だちの場合のみ（機能仕様書4.3.3）。
                nameTrailing: isFriend && !isDeletedPeer
                    ? InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _editNickname(nickname),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.edit, size: 16, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      )
                    : null,
                bio: account.visibleBio,
                actions: actions,
              ),
        // 通報・ブロック：右上には×以外のアイコンを置かない方針（画面設計書5.7.1）のため、
        // 画面下部に控えめに配置する。退会済みの相手には、他の操作と同様に表示しない。
        bottom: account != null && !isDeletedPeer
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // メモは友だちの場合のみ（機能仕様書4.3.7）。
                  if (isFriend) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FriendMemoTile(
                        memo: memo,
                        pinned: memoPinned,
                        onEdit: () => _editMemo(memo),
                        onTogglePin: () => _toggleMemoPin(!memoPinned),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReportButton(busy: state.blocking, onTap: _report),
                      const SizedBox(width: 16),
                      BlockButton(busy: state.blocking, onTap: _block),
                    ],
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
