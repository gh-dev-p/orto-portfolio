import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/chat_image_too_large_exception.dart';
import '../../../domain/models/chat_room.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/message.dart';
import '../../../domain/models/message_history.dart';
import '../../../utils/image_size.dart';
import '../../account/view_models/account_providers.dart';
import '../../friend/view_models/friend_providers.dart';
import '../../group/view_models/group_providers.dart';
import '../../notification/view_models/notification_open_provider.dart';
import '../../passcode/view_models/passcode_providers.dart';
import 'chat_providers.dart';
import 'local_outbox.dart';

// ============================================================
// enum
// ============================================================

/// メッセージ（テキスト・画像）の送信の結果
enum ChatSendResult {
  /// 送信できた
  sent,

  /// 送信できなかった（送信失敗のメッセージとして残し、タップで再送できる）
  failed,

  /// 画像が10MB以上のため送れなかった（再送しても送れないため、メッセージは残さない）
  imageTooLarge,
}

// ============================================================
// 状態クラス
// ============================================================

/// CHA-02（トーク）を開くときの引数
/// チャットルームID・自分のアカウントID・相手のアカウントID（グループはnull）の組
typedef ChatScreenArgs = ({String chatRoomId, String myAccountId, String? peerAccountId});

/// CHA-02（トーク）の状態
class ChatState {
  const ChatState({
    required this.messages,
    required this.hasMore,
    required this.peer,
    required this.peerNickname,
    this.pinnedMemo,
    this.groupEntry,
    this.hasLeftGroup = false,
    this.groupMembers = const [],
    required this.isRequestMode,
    required this.sending,
    required this.requestBusy,
    required this.unreadCount,
    required this.passcodeOpen,
  });

  /// 表示するメッセージ（古い順）
  /// 端末上だけにあるメッセージ（送信失敗・アップロード中の画像）を含む。読み込み中・読み込みの失敗も表す
  final AsyncValue<List<Message>> messages;

  /// これより過去のメッセージがあるか
  /// trueなら、一覧の先頭に着いたときに追加で読み込む
  final bool hasMore;

  /// 相手のアカウント
  /// 読み込み中・読み込みの失敗も表す（見つからなければnull）
  final AsyncValue<Account?> peer;

  /// 相手に付けたニックネーム
  /// 付けていなければnull
  final String? peerNickname;

  /// 相手のメモのうち、トークにピン留めしているもの（機能仕様書4.3.7）
  /// ピン留めしていなければnull
  final String? pinnedMemo;

  /// グループのトーク一覧の行（名前・画像・人数。1対1はnull）
  final ChatListEntry? groupEntry;

  /// このグループから抜けた（強制退会を含む）か
  final bool hasLeftGroup;

  /// グループの参加者（既読の人数に使う）
  final List<GroupMember> groupMembers;

  /// リクエストモード（画面設計書5.3.2）か
  /// 相手が自分の友だちでなければtrue（返信できず、「友だち追加」「ブロック」を出す。友だちの一覧の取得前はfalse）
  final bool isRequestMode;

  /// テキストを送信中か
  final bool sending;

  /// リクエストモードの「友だち追加」「ブロック」を実行中か（二重タップの防止）
  final bool requestBusy;

  /// このトークの未読数
  /// 開いている間に新着が届いたら増えるため、Viewはこれを監視して既読にする
  final int unreadCount;

  /// パスコードのガードが開いている（ロックが解除されている）か
  /// Viewはこれを監視して、ロック中に届いた分を解除後に既読にする
  final bool passcodeOpen;

  /// 相手が退会済みか
  bool get peerDeleted => peer.value?.isDeleted ?? false;

  /// 指定した項目だけを変えた、新しい状態を作る
  /// 指定しなかった項目は今の値を引き継ぐ
  ChatState copyWith({AsyncValue<List<Message>>? messages, bool? sending, bool? requestBusy}) {
    return ChatState(
      messages: messages ?? this.messages,
      hasMore: hasMore,
      peer: peer,
      peerNickname: peerNickname,
      pinnedMemo: pinnedMemo,
      groupEntry: groupEntry,
      hasLeftGroup: hasLeftGroup,
      groupMembers: groupMembers,
      isRequestMode: isRequestMode,
      sending: sending ?? this.sending,
      requestBusy: requestBusy ?? this.requestBusy,
      unreadCount: unreadCount,
      passcodeOpen: passcodeOpen,
    );
  }
}

// ============================================================
// ViewModel
// ============================================================

/// CHA-02（トーク）のViewModel
/// メッセージの表示・送信（テキスト・画像）・既読・リアクション・送信取消・削除と、リクエストモードの「友だち追加」「ブロック」を扱う
///
/// 機能仕様書：4.4.2〜4.4.5 / 画面設計書：5.3.2
class ChatViewModel extends Notifier<ChatState> {
  ChatViewModel(this.args);

  // ---- 状態・初期化 ----

  /// 開いているトーク
  final ChatScreenArgs args;

  /// 端末上だけにあるメッセージ（送信失敗・アップロード中の画像）
  final _outbox = LocalOutbox();

  /// テキストを送信中か
  bool _sending = false;

  /// リクエストモードの「友だち追加」「ブロック」を実行中か
  bool _requestBusy = false;

  /// 既読の人数を最後に取り直した時刻
  DateTime? _membersRefreshedAt;

  /// 既読処理の実行中か
  bool _markingRead = false;

  /// 既読処理の実行中に、もう一度の要求があったか（[markRead]が重なって走らないようにする）
  bool _markReadAgain = false;

  /// 最後に読み込んだメッセージの履歴
  /// 端末上だけにあるメッセージが変わったときに、表示するメッセージを作り直すのに使う
  AsyncValue<MessageHistory> _historyAsync = const AsyncLoading();

  /// いま見ているトーク（このトークの新着ではアプリ内バナーを出さない）
  OpenChat get _openChat => (accountId: args.myAccountId, chatRoomId: args.chatRoomId);

  /// 表示内容を作る
  /// メッセージ・相手・友だち・未読数・パスコードのガードを監視し、変わるたびに作り直す
  @override
  ChatState build() {
    final roomKey = (args.myAccountId, args.chatRoomId);
    // ルームが無い間（まだ1通もやり取りしていない相手）は、メッセージを読みに行かず空のトークとして
    // 表示する（ルームが無いとメッセージの読み取りはルールで拒否される。データ設計書3.3）。
    final AsyncValue<MessageHistory> historyAsync = _isGroup ? _groupHistory(roomKey) : _directHistory(roomKey);
    _historyAsync = historyAsync;
    final peerAccountId = args.peerAccountId;
    final friends = ref.watch(friendsProvider).value;
    final peerFriend = friends?.where((f) => f.friendAccountId == peerAccountId).firstOrNull;
    final groupEntry = _isGroup ? ref.watch(groupEntryProvider(roomKey)) : null;

    return ChatState(
      messages: _visibleMessages(),
      hasMore: historyAsync.value?.hasMore ?? false,
      peer: peerAccountId == null ? const AsyncData(null) : ref.watch(accountByIdProvider(peerAccountId)),
      peerNickname: ref.watch(friendNicknamesProvider)[peerAccountId],
      pinnedMemo: peerFriend?.memoPinned == true ? peerFriend?.memo : null,
      groupEntry: groupEntry?.value,
      hasLeftGroup: groupEntry is AsyncData<ChatListEntry?> && groupEntry.value == null,
      groupMembers: _isGroup ? ref.watch(groupMembersProvider(args.chatRoomId)).value ?? const [] : const [],
      isRequestMode: !_isGroup && friends != null && peerFriend == null,
      sending: _sending,
      requestBusy: _requestBusy,
      unreadCount: ref.watch(chatUnreadCountProvider(roomKey).select((async) => async.value ?? 0)),
      passcodeOpen: ref.watch(passcodeGuardStatusProvider) == PasscodeGuardStatus.open,
    );
  }

  /// 既読の人数を取り直す（機能仕様書4.7.3.3）
  /// 自分の送信時に呼ぶ。読み取りを増やさないよう、30秒に1回までとする（データ設計書8.6）
  void _refreshGroupMembers() {
    if (!_isGroup) return;
    final now = DateTime.now();
    final last = _membersRefreshedAt;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) return;
    _membersRefreshedAt = now;
    ref.invalidate(groupMembersProvider(args.chatRoomId));
  }

  /// グループのトークか
  bool get _isGroup => args.peerAccountId == null;

  /// 1対1のメッセージの履歴
  AsyncValue<MessageHistory> _directHistory((String, String) roomKey) {
    return switch (ref.watch(chatRoomExistsProvider(roomKey))) {
      AsyncData(value: true) => ref.watch(messagesProvider((chatRoomId: args.chatRoomId, since: null))),
      AsyncData(value: false) => const AsyncData(MessageHistory(messages: [], hasMore: false)),
      AsyncError(:final error, :final stackTrace) => AsyncError(error, stackTrace),
      _ => const AsyncLoading(),
    };
  }

  /// グループのメッセージの履歴（参加した時刻より後だけを読む）
  AsyncValue<MessageHistory> _groupHistory((String, String) roomKey) {
    return switch (ref.watch(groupJoinedAtProvider(roomKey))) {
      AsyncData(:final value?) => ref.watch(messagesProvider((chatRoomId: args.chatRoomId, since: value))),
      AsyncData() => const AsyncData(MessageHistory(messages: [], hasMore: false)),
      AsyncError(:final error, :final stackTrace) => AsyncError(error, stackTrace),
      _ => const AsyncLoading(),
    };
  }

  /// 読み込むメッセージの範囲
  MessagesKey get _messagesKey => (
    chatRoomId: args.chatRoomId,
    since: _isGroup ? ref.read(groupJoinedAtProvider((args.myAccountId, args.chatRoomId))).value : null,
  );

  /// 表示するメッセージ
  /// 読み込んだ履歴に、端末上だけにあるメッセージを加える（「削除」済み・送信取消済みのメッセージは除く）
  AsyncValue<List<Message>> _visibleMessages() =>
      _historyAsync.whenData((history) => _outbox.visibleMessages(history, myAccountId: args.myAccountId));

  /// 端末上だけにあるメッセージや、送信中の状態が変わったときに、表示内容を更新する
  void _refresh() {
    if (!ref.mounted) return;
    state = state.copyWith(messages: _visibleMessages(), sending: _sending, requestBusy: _requestBusy);
  }

  // ---- 表示 ----

  /// このトークを見始めた
  /// 画面を開いたとき・上に開いた画面から戻ったときにViewが呼ぶ（このトーク宛ての新着ではアプリ内バナーを出さない）
  void startViewing() => ref.read(openChatProvider.notifier).open(_openChat);

  /// このトークを見るのをやめた
  /// 上に別の画面を開くときにViewが呼ぶ（その間は、このトーク宛ての新着でもアプリ内バナーを出す）
  void stopViewing() => ref.read(openChatProvider.notifier).close(_openChat);

  /// 画面を閉じたときに、このトークを見るのをやめる処理
  /// Viewは画面を開いたときに受け取っておき、破棄するときに呼ぶ（ViewModelが先に破棄されても呼べるよう、必要なものを先に取っておく）
  VoidCallback stopViewingOnDispose() {
    final openChatNotifier = ref.read(openChatProvider.notifier);
    final openChat = _openChat;
    return () => openChatNotifier.close(openChat);
  }

  /// 過去のメッセージを追加で読み込む
  /// 一覧の先頭（最も古い表示中のメッセージ）に着いたときに呼ぶ
  void loadMore() => ref.read(messagesProvider(_messagesKey).notifier).loadMore();

  /// メッセージを読み込み直す
  /// 読み込みに失敗したときの「再試行」から呼ぶ
  void retryLoad() {
    if (_isGroup) ref.invalidate(groupJoinedAtProvider((args.myAccountId, args.chatRoomId)));
    if (!_isGroup) ref.invalidate(chatRoomExistsProvider((args.myAccountId, args.chatRoomId)));
    ref.invalidate(messagesProvider(_messagesKey));
  }

  /// 相手からの未読メッセージを既読にする（機能仕様書4.4.3.3）
  /// 本人が実際にこのトークを見ているときだけ、Viewが呼ぶ（実行中に呼ばれたら、終わった後にもう一度行う）
  Future<void> markRead() async {
    if (_markingRead) {
      _markReadAgain = true;
      return;
    }
    _markingRead = true;
    try {
      do {
        _markReadAgain = false;
        final repository = ref.read(chatRepositoryProvider);
        await (_isGroup
            ? repository.markGroupRead(chatRoomId: args.chatRoomId, readerAccountId: args.myAccountId)
            : repository.markRead(chatRoomId: args.chatRoomId, readerAccountId: args.myAccountId));
      } while (_markReadAgain && ref.mounted);
    } catch (error) {
      // 通信失敗等。未読数は残るため、次に開いたとき・新着が届いたときにやり直す。
      debugPrint('[Chat] markRead failed: $error');
    } finally {
      _markingRead = false;
    }
  }

  // ---- 送信 ----

  /// テキストを送信する
  /// 空白だけ・送信中なら何もせずsent。失敗したら送信失敗のメッセージとして残し、failed
  Future<ChatSendResult> sendText(String text) async {
    if (text.trim().isEmpty || _sending) return ChatSendResult.sent;
    _sending = true;
    _refresh();
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            chatRoomId: args.chatRoomId,
            senderAccountId: args.myAccountId,
            peerAccountId: args.peerAccountId,
            text: text,
          );
      _refreshGroupMembers();
      return ChatSendResult.sent;
    } catch (_) {
      _outbox.addFailedText(senderId: args.myAccountId, text: text);
      return ChatSendResult.failed;
    } finally {
      _sending = false;
      _refresh();
    }
  }

  /// スタンプを送信する（機能仕様書4.4.8）
  /// 失敗したらfailed（送信失敗のメッセージは残さず、もう一度選び直してもらう）
  Future<ChatSendResult> sendSticker({required String stickerPackId, required String stickerId}) async {
    if (_sending) return ChatSendResult.sent;
    _sending = true;
    _refresh();
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendStickerMessage(
            chatRoomId: args.chatRoomId,
            senderAccountId: args.myAccountId,
            peerAccountId: args.peerAccountId,
            stickerPackId: stickerPackId,
            stickerId: stickerId,
          );
      _refreshGroupMembers();
      return ChatSendResult.sent;
    } catch (_) {
      return ChatSendResult.failed;
    } finally {
      _sending = false;
      _refresh();
    }
  }

  /// 当日の定型連絡を送信する（オフ会グループのみ。機能仕様書4.7.8.11）
  /// 失敗したらfailed（送信失敗のメッセージは残さず、もう一度押してもらう。スタンプと同じ）
  Future<ChatSendResult> sendMeetupStatus(MeetupStatus status) async {
    if (_sending || args.peerAccountId != null) return ChatSendResult.sent;
    _sending = true;
    _refresh();
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMeetupStatusMessage(chatRoomId: args.chatRoomId, senderAccountId: args.myAccountId, status: status);
      _refreshGroupMembers();
      return ChatSendResult.sent;
    } catch (_) {
      return ChatSendResult.failed;
    } finally {
      _sending = false;
      _refresh();
    }
  }

  /// 画像を送信する
  /// 送信中は、画像の吹き出しにアップロードの進み具合を重ねて表示する（画面設計書5.3.2）。画像の送信中もテキストは送れる
  ///
  /// 失敗したら、テキストと同じく送信失敗のメッセージとして残し、failed（タップでアップロードからやり直す。機能仕様書4.4.4.2）。10MB以上ならimageTooLarge
  Future<ChatSendResult> sendImage(File file) async {
    final repository = ref.read(chatRepositoryProvider);
    final messageId = repository.newMessageId(args.chatRoomId);
    // 大きさの読み取りを待たず、送信の操作の直後から吹き出しを出す。
    _outbox.startUpload(messageId: messageId, senderId: args.myAccountId, localImagePath: file.path);
    _refresh();

    ({int width, int height})? size;
    try {
      size = await readImageSize(file);
      if (_outbox.updateSize(messageId, width: size.width, height: size.height)) _refresh();
    } catch (_) {
      // 大きさを読めない場合は、正方形の枠のまま表示する。
    }

    try {
      if (!ref.mounted) return ChatSendResult.failed;
      await repository.sendImageMessage(
        chatRoomId: args.chatRoomId,
        messageId: messageId,
        senderAccountId: args.myAccountId,
        peerAccountId: args.peerAccountId,
        file: file,
        size: size,
        onProgress: (progress) {
          if (_outbox.updateProgress(messageId, progress)) _refresh();
        },
      );
      _refreshGroupMembers();
      return ChatSendResult.sent;
    } on ChatImageTooLargeException {
      return ChatSendResult.imageTooLarge;
    } catch (_) {
      _outbox.addFailedImage(
        senderId: args.myAccountId,
        localImagePath: file.path,
        width: size?.width,
        height: size?.height,
      );
      return ChatSendResult.failed;
    } finally {
      _outbox.finishUpload(messageId);
      _refresh();
    }
  }

  /// 送信失敗のメッセージを再送する（画面設計書5.3.2 異常系）
  /// テキストの送信中なら何もしない（null）。画像はアップロードからやり直す（機能仕様書4.4.4.2）
  Future<ChatSendResult?> retry(Message failedMessage) async {
    if (_sending) return null;
    _outbox.removeFailed(failedMessage.id);
    _refresh();
    final localImagePath = failedMessage.localImagePath;
    if (failedMessage.isImage && localImagePath != null) return sendImage(File(localImagePath));
    return sendText(failedMessage.text);
  }

  // ---- メッセージの操作 ----

  /// リアクションを付ける・変える・外す
  /// 同じ絵文字をもう一度選んだら外す。成功したらtrue
  Future<bool> toggleReaction(Message message, String emoji) async {
    final current = message.reactions[args.myAccountId];
    try {
      await ref
          .read(chatRepositoryProvider)
          .setReaction(
            chatRoomId: args.chatRoomId,
            messageId: message.id,
            reactorAccountId: args.myAccountId,
            emoji: current == emoji ? null : emoji,
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 送信を取り消す
  /// 双方の画面から消す（データ上は`unsentAt`を付ける論理削除で、本文の退避はCloud Functionsの`onMessageUnsent`が行う）。成功したらtrue
  Future<bool> unsend(Message message) async {
    try {
      await ref.read(chatRepositoryProvider).unsendMessage(chatRoomId: args.chatRoomId, messageId: message.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 自分の画面からだけ消す（論理削除）
  /// 成功したらtrue
  Future<bool> hideForMe(Message message) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .hideMessageForMe(
            chatRoomId: args.chatRoomId,
            messageId: message.id,
            accountId: args.myAccountId,
            since: _messagesKey.since,
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- リクエストモード ----

  /// リクエストモードの「友だち追加」
  /// 相手を自分の友だちに追加する（PRO-01の「友だち追加」と同じ。機能仕様書4.3.1：片方向。ルームは既にある）
  ///
  /// 成功したらtrue（友だちの一覧が更新され、通常のモード（入力欄あり）に自動で切り替わる）。実行中なら何もせずtrue
  Future<bool> addFriendFromRequest() async {
    if (_requestBusy) return true;
    setRequestBusy(true);
    try {
      await ref
          .read(friendRepositoryProvider)
          .addFriend(myAccountId: args.myAccountId, peerAccountId: args.peerAccountId!);
      return true;
    } catch (_) {
      return false;
    } finally {
      setRequestBusy(false);
    }
  }

  /// リクエストモードの「ブロック」
  /// 相手をブロックする（ブロックの記録・双方向の友だちの解除・自分側の未読のリセットを1回で行う）。失敗したら例外を投げる
  Future<void> blockPeer() {
    return ref
        .read(blockRepositoryProvider)
        .blockAccount(accountId: args.myAccountId, targetAccountId: args.peerAccountId!);
  }

  /// リクエストモードの「友だち追加」「ブロック」を実行中かを設定する
  /// ブロックの確認〜実行（block_flow）の間、Viewが呼ぶ
  void setRequestBusy(bool busy) {
    _requestBusy = busy;
    _refresh();
  }
}

// ============================================================
// Provider
// ============================================================

/// [ChatViewModel]のProvider
/// 引数は開いているトーク。誰も監視しなくなったら破棄される（autoDispose）
final chatViewModelProvider = NotifierProvider.autoDispose.family<ChatViewModel, ChatState, ChatScreenArgs>(
  ChatViewModel.new,
);
