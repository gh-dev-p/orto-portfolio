import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/image_pick.dart';
import '../../account/view_models/account_providers.dart';
import '../../album/widgets/album_detail_screen.dart';
import '../../album/widgets/album_list_screen.dart';
import '../../block/widgets/block_flow.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/ui/error_retry_view.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../plan/widgets/read_only_notice_bar.dart';
import '../../profile/widgets/friend_profile_screen.dart';
import '../view_models/chat_viewmodel.dart';
import '../view_models/sticker_packs_provider.dart';
import '../../chat_list/view_models/chat_list_viewmodel.dart';
import '../../group/widgets/group_info_screen.dart';
import '../../../domain/models/chat_room.dart';
import 'chat_image_viewer_screen.dart';
import 'image_send_preview_screen.dart';
import 'message_action.dart';
import 'message_actions_popup.dart';
import 'message_bubble.dart';
import 'message_input_bar.dart';
import 'message_list.dart';
import 'pinned_memo_bar.dart';
import 'sticker_picker_panel.dart';
import '../../group/widgets/meetup_status_bar.dart';
import 'request_action_bar.dart';
import '../../report/view_models/report_viewmodel.dart';
import '../../report/widgets/report_screen.dart';
import '../../group/widgets/meetup_badge.dart';
import '../../group/widgets/meetup_closed_bar.dart';
import '../../group/widgets/next_round_screen.dart';
import '../../group/widgets/join_requests_screen.dart';
import '../../group/widgets/organizer_invite_card.dart';
import '../../group/view_models/group_providers.dart';
import '../../group/widgets/announcement_edit_screen.dart';
import '../../group/widgets/meetup_announcement_panel.dart';

/// 画面CHA-02：トーク（1対1）
/// メッセージの表示・送信（テキスト・画像）・長押しの操作と、リクエストモードの「友だち追加」「ブロック」を行う
///
/// 機能仕様書：4.4.2〜4.4.5 / 画面設計書：5.3.2
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatRoomId, required this.myAccountId, required this.peerAccountId});

  final String chatRoomId;
  final String myAccountId;

  /// 相手のアカウントID（グループはnull）
  final String? peerAccountId;

  static const _maxLength = 2000;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  // ---- 状態・初期化 ----

  /// 入力欄のテキスト
  final _controller = TextEditingController();

  /// メッセージ一覧のスクロール位置
  final _scrollController = ScrollController();

  /// 部分コピー中のメッセージのID
  /// そのメッセージのバブル自体をその場で選択できるようにする。一覧の他の場所をタップすると解除する
  String? _selectableMessageId;

  /// 選んだ画像を端末で読み込み・縮小しているか
  /// 選択画面が閉じてからプレビューを開くまでの間、入力欄に読み込み中の表示を出す
  bool _preparingImage = false;

  /// 画面を閉じたときに、このトークを見るのをやめる処理
  /// 画面を開いたときにViewModelから受け取っておく
  VoidCallback? _stopViewingOnDispose;

  /// このトークのViewModelのProvider
  late final _provider = chatViewModelProvider((
    chatRoomId: widget.chatRoomId,
    myAccountId: widget.myAccountId,
    peerAccountId: widget.peerAccountId,
  ));

  ChatViewModel get _viewModel => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _stopViewingOnDispose = _viewModel.stopViewingOnDispose();
      _viewModel.startViewing();
      _markRead();
    });
  }

  @override
  void dispose() {
    // 画面の破棄中（ウィジェットの組み立て中）にProviderを変えないよう、後で呼ぶ。
    final stopViewing = _stopViewingOnDispose;
    if (stopViewing != null) Future.microtask(stopViewing);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 機能仕様書4.4.3.3：フォアグラウンド表示されたタイミングで既読化する。
    if (state == AppLifecycleState.resumed) _markRead();
  }

  // ---- 既読・画面遷移 ----

  /// 本人が実際にこのトークを見ているか
  /// アプリが前面にあり、この画面が最前面（プロフィール等を上に開いていない）で、パスコードのロックが解除されていること
  bool get _isViewing =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      ref.read(_provider).passcodeOpen;

  /// 相手からの未読メッセージを既読にする（機能仕様書4.4.3.3）
  /// 画面を開いたとき・アプリが前面に戻ったとき・開いている間に新着が届いたときに呼ぶ（見ていなかった間の新着は、見られる状態に戻った時点で既読にする）
  void _markRead() {
    if (!mounted || !_isViewing) return;
    unawaited(_viewModel.markRead());
  }

  /// この画面の上に別の画面を開き、閉じて戻ったら、その間に届いた分を既読にする
  /// 上の画面を開いている間はこのトークを見ていないため、新着のアプリ内バナーを出す
  Future<T?> _pushAndMarkRead<T>(Route<T> route) async {
    _viewModel.stopViewing();
    final result = await Navigator.of(context).push(route);
    if (!mounted) return result;
    _viewModel.startViewing();
    _markRead();
    return result;
  }

  /// 過去のメッセージを追加で読み込む
  /// 一覧の先頭（最も古い表示中のメッセージ）に着いたときに呼ぶ
  void _loadMore() {
    if (mounted) _viewModel.loadMore();
  }

  /// 画像の全画面表示（CHA-03）を開く
  /// 画像メッセージのタップ時に呼ぶ
  void _openImage(Message message) {
    final path = message.imagePath;
    if (path == null) return;
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(_provider);
    final sender = widget.peerAccountId == null ? ref.read(chatListPeerProvider(message.senderId)) : null;
    final senderName = message.isMine(widget.myAccountId)
        ? l10n.chaImageMine
        : resolveDisplayName(
            sender?.account.value ?? state.peer.value,
            nickname: sender?.nickname ?? state.peerNickname,
            unknownAccountLabel: l10n.commonUnknownAccount,
            deletedAccountLabel: l10n.commonDeletedAccount,
          );
    _pushAndMarkRead(
      MaterialPageRoute(
        builder: (_) => ChatImageViewerScreen(
          path: path,
          aspectRatio: MessageBubble.imageAspectRatio(message),
          senderName: senderName,
          createdAt: message.createdAt,
        ),
      ),
    );
  }

  /// アルバムの一覧（ALB-01）を開く
  void _openAlbums() {
    _pushAndMarkRead(
      MaterialPageRoute(
        builder: (_) => AlbumListScreen(
          chatRoomId: widget.chatRoomId,
          myAccountId: widget.myAccountId,
          peerAccountId: widget.peerAccountId,
        ),
      ),
    );
  }

  /// アルバムの案内のタップ時に、そのアルバム（ALB-02）を開く
  void _openAlbum(Message message) {
    final albumId = message.albumId;
    if (albumId == null) return;
    _pushAndMarkRead(
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(
          chatRoomId: widget.chatRoomId,
          albumId: albumId,
          myAccountId: widget.myAccountId,
          peerAccountId: widget.peerAccountId,
        ),
      ),
    );
  }

  // ---- 送信 ----

  /// 入力欄のテキストを送信する
  /// 送信ボタンのタップ時に呼ぶ
  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty || ref.read(_provider).sending) return;
    _controller.clear();
    _showSendResult(await _viewModel.sendText(text), image: false);
  }

  /// 選択パネルで選んだスタンプを送信する（機能仕様書4.4.8）
  Future<void> _sendSticker(StickerSelection selected) async {
    if (ref.read(_provider).sending) return;
    _showSendResult(
      await _viewModel.sendSticker(stickerPackId: selected.packId, stickerId: selected.stickerId),
      image: false,
    );
  }

  /// 当日の定型連絡を、確認なしでその場で送信する（オフ会グループのみ。機能仕様書4.7.8.11）
  Future<void> _sendMeetupStatus(MeetupStatus status) async {
    if (ref.read(_provider).sending) return;
    _showSendResult(await _viewModel.sendMeetupStatus(status), image: false);
  }

  /// 画像を選び、全画面のプレビューで確かめてから送信する
  /// カメラ・ギャラリーから選び、長辺1920px・JPEG品質85に縮小・圧縮する
  Future<void> _pickAndSendImage() async {
    if (ref.read(_provider).sending || _preparingImage) return;
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    // 選択の結果は読み込みと縮小が終わってから返り、選択画面が閉じた時点は分からないため、開く前から表示を出す。
    // 選択画面が開いている間は、その裏に隠れて見えない。
    setState(() => _preparingImage = true);
    final picked = await pickImageForUpload(context, source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
    if (!mounted) return;
    setState(() => _preparingImage = false);
    if (picked == null) return;
    final file = File(picked.path);
    final confirmed = await _pushAndMarkRead<bool>(
      MaterialPageRoute(builder: (_) => ImageSendPreviewScreen(file: file), fullscreenDialog: true),
    );
    if (confirmed != true || !mounted) return;
    _showSendResult(await _viewModel.sendImage(file), image: true);
  }

  /// 送信失敗のメッセージを再送する（画面設計書5.3.2 異常系）
  /// 送信失敗のバブルのタップ時に呼ぶ
  Future<void> _retry(Message failedMessage) async {
    final result = await _viewModel.retry(failedMessage);
    if (result != null) _showSendResult(result, image: failedMessage.isImage);
  }

  /// 送信の結果をSnackBarで知らせる
  /// 送信できたときは何も出さない
  void _showSendResult(ChatSendResult result, {required bool image}) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final message = switch (result) {
      ChatSendResult.sent => null,
      ChatSendResult.failed => image ? l10n.chaImageSendFailed : l10n.commonSendFailedRetry,
      ChatSendResult.imageTooLarge => l10n.chaImageTooLarge,
    };
    if (message != null) showAppSnackBar(context, message);
  }

  // ---- メッセージの操作 ----

  /// メッセージの長押しメニューを開く（画面設計書5.3.2）
  /// 長押しした位置の近くに出す（自分のメッセージ：コピー・部分コピー・削除・送信取消。相手のメッセージ：リアクション・コピー・部分コピー・削除・通報）
  Future<void> _openMessageActions(Message message, Offset globalPosition) async {
    if (message.isFailed) return;
    final isImage =
        message.isImage || message.isSticker || message.isAlbum || message.isMeetupStatus || message.isUnsupported;
    final action = await showMessageActionsPopup(
      context,
      isMine: message.isMine(widget.myAccountId),
      isImage: isImage,
      globalPosition: globalPosition,
      canAnnounce: !isImage && !message.isSystem && _isOrganizer && !_isClosedGroup,
      isClosedRoom: _isClosedGroup,
    );
    if (action == null || !mounted) return;

    switch (action.type) {
      case MessageActionType.react:
        await _toggleReaction(message, action.emoji!);
      case MessageActionType.copy:
        await _copyMessage(message);
      case MessageActionType.partialCopy:
        _enterSelectionMode(message);
      case MessageActionType.unsend:
        await _confirmAndUnsend(message);
      case MessageActionType.delete:
        await _confirmAndDelete(message);
      case MessageActionType.report:
        await _report(messageId: message.id, targetAccountId: message.senderId);
      case MessageActionType.announce:
        _announceMessage(message);
    }
  }

  /// 閉じたオフ会グループか（機能仕様書4.7.8.6）。読むだけで、送信・リアクション・送信取消はできない
  bool get _isClosedGroup {
    if (widget.peerAccountId != null) return false;
    final now = DateTime.now();
    return (ref.read(_provider).groupEntry?.isClosedAt(now) ?? false) ||
        (ref.read(groupRoomProvider(widget.chatRoomId)).value?.isClosedAt(now) ?? false);
  }

  /// 自分がこのオフ会グループの主催チームか（機能仕様書4.7.8.2）
  bool get _isOrganizer =>
      widget.peerAccountId == null &&
      (ref.read(groupRoomProvider(widget.chatRoomId)).value?.isOrganizer(widget.myAccountId) ?? false);

  /// メッセージの本文を入れた状態でお知らせの編集（GRP-07）を開く（機能仕様書4.7.8.4）
  void _announceMessage(Message message) {
    if (ref.read(isReadOnlyProvider(widget.myAccountId))) {
      showAppSnackBar(context, AppLocalizations.of(context)!.planReadOnlyNotice);
      return;
    }
    _pushAndMarkRead(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AnnouncementEditScreen(
          chatRoomId: widget.chatRoomId,
          myAccountId: widget.myAccountId,
          initialText: message.text,
        ),
      ),
    );
  }

  /// 吹き出しの下のリアクションのタップで、絵文字の選択をタップした位置の近くに開く（相手のメッセージのみ）
  /// 選んだ絵文字に変える（付けている絵文字と同じなら外す）
  Future<void> _openReactionPicker(Message message, Offset globalPosition) async {
    if (_isClosedGroup) return;
    final emoji = await showReactionPickerPopup(context, globalPosition: globalPosition);
    if (emoji == null || !mounted) return;
    await _toggleReaction(message, emoji);
  }

  /// メッセージの本文全体をコピーする
  Future<void> _copyMessage(Message message) async {
    await Clipboard.setData(ClipboardData(text: message.text));
    if (!mounted) return;
    showAppSnackBar(context, AppLocalizations.of(context)!.commonCopied);
  }

  /// 部分コピーを始める
  /// ダイアログ等は開かず、そのメッセージのバブル自体をその場で選択できるようにする（一覧の他の場所をタップすると解除する）
  void _enterSelectionMode(Message message) {
    setState(() => _selectableMessageId = message.id);
  }

  /// 部分コピーをやめる
  /// メッセージ一覧のタップ時に呼ぶ
  void _exitSelectionMode() {
    if (_selectableMessageId != null) setState(() => _selectableMessageId = null);
  }

  /// リアクションを付ける・変える・外す
  Future<void> _toggleReaction(Message message, String emoji) async {
    if (ref.read(isReadOnlyProvider(widget.myAccountId))) {
      showAppSnackBar(context, AppLocalizations.of(context)!.planReadOnlyNotice);
      return;
    }
    final ok = await _viewModel.toggleReaction(message, emoji);
    if (!ok && mounted) showAppSnackBar(context, AppLocalizations.of(context)!.chaReactionFailed);
  }

  /// 確認ダイアログの後、送信を取り消す
  /// 双方の画面から消える
  Future<void> _confirmAndUnsend(Message message) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.chaUnsendConfirmTitle,
      message: l10n.chaUnsendConfirmMessage,
      confirmLabel: l10n.chaMessageActionUnsend,
    );
    if (!confirmed || !mounted) return;
    final ok = await _viewModel.unsend(message);
    if (!ok && mounted) showAppSnackBar(context, l10n.chaUnsendFailed);
  }

  /// 確認ダイアログの後、自分の画面からだけ消す
  Future<void> _confirmAndDelete(Message message) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.chaDeleteConfirmTitle,
      message: l10n.chaDeleteConfirmMessage,
      confirmLabel: l10n.chaMessageActionDelete,
    );
    if (!confirmed || !mounted) return;
    final ok = await _viewModel.hideForMe(message);
    if (!ok && mounted) showAppSnackBar(context, l10n.chaDeleteFailed);
  }

  /// REP-01で相手を通報する
  /// メッセージの長押しメニューからなら、そのメッセージ[messageId]も記録する。同時にブロックもしたら、ブロックと同じくトーク一覧へ戻る（グループでは同じグループに居続けられるため戻らない。機能仕様書4.7.6）
  Future<void> _report({String? messageId, String? targetAccountId}) async {
    final isGroup = widget.peerAccountId == null;
    final outcome = await openReport(context, (
      myAccountId: widget.myAccountId,
      targetAccountId: targetAccountId ?? widget.peerAccountId,
      messageId: messageId,
      chatRoomId: isGroup ? widget.chatRoomId : null,
      albumId: null,
      albumItemId: null,
    ));
    if (!isGroup && outcome == ReportOutcome.reportedAndBlocked && mounted) Navigator.of(context).pop();
  }

  // ---- リクエストモード ----

  /// リクエストモードの「友だち追加」
  /// 追加できたら、友だちの一覧が更新されて通常のモード（入力欄あり）に自動で切り替わる
  Future<void> _addFriendFromRequest() async {
    if (ref.read(_provider).requestBusy) return;
    final ok = await ref.read(loadingOverlayProvider.notifier).run(_viewModel.addFriendFromRequest);
    if (!ok && mounted) showAppSnackBar(context, AppLocalizations.of(context)!.proFriendAddFailed);
  }

  /// リクエストモードの「ブロック」
  /// 確認ダイアログの後、相手をブロックしてトーク一覧へ戻る（友だちの解除も同時に行われる。画面設計書5.6.2）
  Future<void> _blockFromRequest() async {
    if (ref.read(_provider).requestBusy) return;
    final viewModel = _viewModel;
    viewModel.setRequestBusy(true);
    final blocked = await confirmAndBlockAccount(context: context, ref: ref, block: viewModel.blockPeer);
    if (!mounted) return;
    if (blocked) {
      Navigator.of(context).pop();
    } else {
      viewModel.setRequestBusy(false);
    }
  }

  // ---- 画面 ----

  /// 相手のプロフィール（PRO-01）を開く
  void _openPeerProfile() {
    _pushAndMarkRead(
      MaterialPageRoute(
        builder: (_) => FriendProfileScreen(
          accountId: widget.peerAccountId!,
          myAccountId: widget.myAccountId,
          openedFromChat: true,
        ),
      ),
    );
  }

  /// グループの参加者のプロフィール（PRO-01）を開く
  /// 友だちでない参加者には、友だち追加ではなく友だち申請を出す
  void _openMemberProfile(String accountId) {
    if (accountId == widget.myAccountId) return;
    _pushAndMarkRead(
      MaterialPageRoute(
        builder: (_) => FriendProfileScreen(
          accountId: accountId,
          myAccountId: widget.myAccountId,
          groupChatRoomId: widget.chatRoomId,
        ),
      ),
    );
  }

  /// グループ情報（GRP-03）を開く
  void _openGroupInfo() {
    _pushAndMarkRead(
      MaterialPageRoute(
        builder: (_) => GroupInfoScreen(chatRoomId: widget.chatRoomId, myAccountId: widget.myAccountId),
      ),
    );
  }

  /// グループのヘッダー（画像・名前・人数）
  Widget _groupHeader(ChatListEntry? entry) {
    if (entry == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openGroupInfo,
      child: Row(
        children: [
          AppAvatar(displayName: entry.name ?? '', photoURL: entry.photoURL, size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              l10n.grpTitleWithCount(entry.name ?? '', entry.memberCount),
              style: context.textStyles.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // オフ会グループは名前の横に印「オフ会」と残り日数（機能仕様書4.7.8.1）
          if (entry.isMeetup) ...[const SizedBox(width: 6), MeetupBadge.forEntry(entry)],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final readOnly = ref.watch(isReadOnlyProvider(widget.myAccountId));
    final albumEnabled = ref.watch(albumFeatureEnabledProvider);
    // 開いている間に届いた新着も既読にする（未読数が増えたら既読処理を呼ぶ）。
    ref.listen<int>(_provider.select((s) => s.unreadCount), (_, unread) {
      if (unread > 0) _markRead();
    });
    // パスコードのロックが解除されたら、ロック中に届いた分を既読にする。
    ref.listen<bool>(_provider.select((s) => s.passcodeOpen), (_, open) {
      if (open) _markRead();
    });
    // 退会した（他の参加者に退会させられた場合を含む）ら、その場で閉じる（機能仕様書4.7.4.2）。
    ref.listen<bool>(_provider.select((s) => s.hasLeftGroup), (_, hasLeft) {
      if (!hasLeft) return;
      final messenger = ScaffoldMessenger.of(context);
      final notice = AppLocalizations.of(context)!.grpLeftNotice;
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(buildAppSnackBar(notice));
    });
    final peerNickname = state.peerNickname;
    // 閉じたオフ会グループ（機能仕様書4.7.8.6）。閉じる日時はルームが読めればそちらを使う
    final groupRoom = widget.peerAccountId == null ? ref.watch(groupRoomProvider(widget.chatRoomId)).value : null;
    final now = DateTime.now();
    final closedEntry = widget.peerAccountId == null ? state.groupEntry : null;
    final isClosedGroup = (closedEntry?.isClosedAt(now) ?? false) || (groupRoom?.isClosedAt(now) ?? false);
    final closesAt = groupRoom?.closesAt ?? closedEntry?.closesAt;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(
        backgroundColor: context.colors.surface,
        // 相手のアイコンと名前は戻るボタンの横に左寄せで置く
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          if (albumEnabled)
            CupertinoButton(
              key: const Key('chat-open-albums'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: _openAlbums,
              child: Icon(CupertinoIcons.photo_on_rectangle, color: context.colors.primaryText),
            ),
          // グループ情報（GRP-03）を開くメニュー。ヘッダーのグループ名のタップでも開く
          if (widget.peerAccountId == null)
            CupertinoButton(
              key: const Key('chat-open-group-info'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: _openGroupInfo,
              child: Icon(
                CupertinoIcons.line_horizontal_3,
                color: context.colors.primaryText,
                semanticLabel: AppLocalizations.of(context)!.grpInfoTitle,
              ),
            ),
        ],
        titleWidget: widget.peerAccountId == null
            ? _groupHeader(state.groupEntry)
            : state.peer.when(
                data: (peer) {
                  final l10n = AppLocalizations.of(context)!;
                  final name = resolveDisplayName(
                    peer,
                    nickname: peerNickname,
                    unknownAccountLabel: l10n.commonUnknownAccount,
                    deletedAccountLabel: l10n.commonDeletedAccount,
                  );
                  final header = Row(
                    children: [
                      AppAvatar(displayName: name, photoURL: peer?.visiblePhotoURL, size: 32),
                      const SizedBox(width: 8),
                      Text(name, style: context.textStyles.titleMedium),
                    ],
                  );
                  // ヘッダー（アバター＋名前）タップでPRO-01へ遷移する。相手アカウントが
                  // 未取得・削除済みの場合は遷移先が成立しないためタップ無効のまま。
                  if (peer == null || peer.isDeleted) return header;
                  return GestureDetector(behavior: HitTestBehavior.opaque, onTap: _openPeerProfile, child: header);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => Text(AppLocalizations.of(context)!.commonUnknownAccount),
              ),
      ),
      body: Column(
        children: [
          // 主催チームに誘われているときのカード（機能仕様書4.7.8.2）
          if (widget.peerAccountId == null && (state.groupEntry?.isMeetup ?? false))
            OrganizerInviteCard(chatRoomId: widget.chatRoomId, myAccountId: widget.myAccountId),
          // 会の日時と場所・お知らせの枠（機能仕様書4.7.8.4）
          if (widget.peerAccountId == null && (state.groupEntry?.isMeetup ?? false))
            MeetupAnnouncementPanel(
              chatRoomId: widget.chatRoomId,
              myAccountId: widget.myAccountId,
              push: (route) => _pushAndMarkRead(route),
            ),
          // 主催チームの人に、承認待ちの参加の申請の帯（機能仕様書4.7.8.5）
          if (widget.peerAccountId == null && (state.groupEntry?.isMeetup ?? false))
            JoinRequestBanner(chatRoomId: widget.chatRoomId, myAccountId: widget.myAccountId),
          if (state.pinnedMemo case final memo?)
            PinnedMemoBar(memo: memo, onTap: state.peer.value?.isDeleted == false ? _openPeerProfile : null),
          Expanded(
            // 部分コピー中に、メッセージ一覧の他の場所をタップしたら解除する。
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _exitSelectionMode,
              child: state.messages.when(
                data: (messages) => MessageList(
                  messages: messages,
                  hasMore: state.hasMore,
                  onLoadMore: _loadMore,
                  myAccountId: widget.myAccountId,
                  peerAccountId: widget.peerAccountId,
                  groupMembers: state.groupMembers,
                  onOpenProfile: _openMemberProfile,
                  onReportSystemMessage: (message) => _report(messageId: message.id, targetAccountId: message.senderId),
                  scrollController: _scrollController,
                  selectableMessageId: _selectableMessageId,
                  onRetry: _retry,
                  onLongPress: _openMessageActions,
                  onOpenImage: _openImage,
                  onTapReactions: _openReactionPicker,
                  chatRoomId: widget.chatRoomId,
                  onOpenAlbum: albumEnabled ? _openAlbum : null,
                ),
                loading: () => const AppLoadingIndicator(),
                error: (error, _) => ErrorRetryView(
                  message: AppLocalizations.of(context)!.chaMessagesLoadError,
                  onRetry: () => _viewModel.retryLoad(),
                ),
              ),
            ),
          ),
          if (state.isRequestMode)
            RequestActionBar(
              busy: state.requestBusy,
              // 退会済みアカウントはPRO-01と同様に友だち追加の対象にしない。
              canAddFriend: !state.peerDeleted && !readOnly,
              onAddFriend: _addFriendFromRequest,
              onBlock: _blockFromRequest,
              onReport: _report,
            )
          else if (isClosedGroup)
            MeetupClosedBar(
              closesAt: closesAt,
              // 主催チームの人には次の回を作る入口（機能仕様書4.7.8.13）
              onCreateNextRound: groupRoom != null && groupRoom.canCreateNextRound(widget.myAccountId, now)
                  ? () => openNextRound(
                      context,
                      chatRoomId: widget.chatRoomId,
                      myAccountId: widget.myAccountId,
                      name: closedEntry?.name ?? '',
                    )
                  : null,
            )
          else if (readOnly)
            const ReadOnlyNoticeBar()
          else ...[
            // オフ会グループの会の日に、定型連絡のボタン（機能仕様書4.7.8.11）
            if (widget.peerAccountId == null)
              MeetupStatusBar(chatRoomId: widget.chatRoomId, sending: state.sending, onSend: _sendMeetupStatus),
            MessageInputBar(
              controller: _controller,
              sending: state.sending,
              preparingImage: _preparingImage,
              maxLength: ChatScreen._maxLength,
              onSend: _send,
              onPickImage: _pickAndSendImage,
              stickerPacks: ref.watch(stickerPacksProvider).value ?? const [],
              onSelectSticker: _sendSticker,
            ),
          ],
        ],
      ),
    );
  }
}
