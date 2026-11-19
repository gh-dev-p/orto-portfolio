import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/blocked_account.dart';
import '../../../domain/models/chat_list_sections.dart';
import '../../../domain/models/chat_room.dart';
import '../../../domain/models/message_history.dart';
import '../../../data/repositories/chat/chat_repository.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../block/view_models/block_providers.dart';
import '../../friend/view_models/friend_providers.dart';
import '../../../config/service_providers.dart';

// ============================================================
// Provider
// ============================================================

/// アクティブアカウントのトーク一覧（機能仕様書4.4.1、データ設計書3.2.4）
final chatRoomsProvider = StreamProvider<List<ChatListEntry>>((ref) async* {
  final activeId = ref.watch(activeAccountIdProvider);
  if (activeId == null) {
    yield const [];
    return;
  }
  yield* ref.watch(chatRepositoryProvider).watchChatList(activeId);
});

/// トークがメッセージを読みに行ってよいか（ルームがあるか）
/// 引数は(自分のアカウントID, チャットルームID)。ルームが無い間は、メッセージを読みに行かず空のトークとして表示する（データ設計書3.3）
final chatRoomExistsProvider = StreamProvider.autoDispose.family<bool, (String, String)>((ref, key) {
  final (accountId, chatRoomId) = key;
  return ref.watch(chatRepositoryProvider).watchChatRoomExists(accountId: accountId, chatRoomId: chatRoomId);
});

/// 読み込むメッセージの範囲（[messagesProvider]の引数）
typedef MessagesKey = ({String chatRoomId, DateTime? since});

/// 自分がこのグループに参加した時刻（データ設計書8.2）
/// 引数は(自分のアカウントID, チャットルームID)。これより前のメッセージは読めない
final groupJoinedAtProvider = FutureProvider.autoDispose.family<DateTime?, (String, String)>((ref, key) {
  final (accountId, chatRoomId) = key;
  return ref.watch(chatRepositoryProvider).fetchGroupJoinedAt(chatRoomId: chatRoomId, accountId: accountId);
});

/// 自分のこのトークの未読数
/// 引数は(自分のアカウントID, チャットルームID)。トークを開いている間に届いたメッセージを既読にするのに使う（機能仕様書4.4.3.3）
final chatUnreadCountProvider = StreamProvider.autoDispose.family<int, (String, String)>((ref, key) {
  final (accountId, chatRoomId) = key;
  return ref.watch(chatRepositoryProvider).watchUnreadCount(accountId: accountId, chatRoomId: chatRoomId);
});

/// CHA-01の表示区分（通常のトークリスト・未確認のトークリクエスト）
/// 友だち・ブロックの状態が変わるたびに区分けし直す
///
/// リクエストの候補のうち、相手にブロックされているものは除く（ブロックされた側の一覧に、相手のルームがリクエストとして現れないようにする）
final chatListSectionsProvider = FutureProvider<ChatListSections>((ref) async {
  final myAccountId = ref.watch(activeAccountIdProvider);
  if (myAccountId == null) return const ChatListSections();

  final rooms = await ref.watch(chatRoomsProvider.future);
  final friends = await ref.watch(friendsProvider.future);
  // ブロック済みの相手を一覧から隠すのは表示上の補助で、実際の拒否はfirestore.rulesが行う。
  // ブロックリストを読めない場合（ルールの未デプロイ等でpermission-denied）に、トーク一覧
  // 全体が取得エラーにならないよう、その場合は「ブロックなし」として扱う。
  List<BlockedAccount> blocked;
  try {
    blocked = await ref.watch(blockedAccountsProvider.future);
  } catch (_) {
    blocked = const [];
  }

  final partition = partitionChatRooms(
    rooms: rooms,
    friendAccountIds: {for (final f in friends) f.friendAccountId},
    blockedAccountIds: {for (final b in blocked) b.blockedAccountId},
  );

  final blockedByPeer = await Future.wait([
    for (final room in partition.requestCandidates) ref.watch(blockedByPeerProvider(room.peerAccountId!).future),
  ]);
  return ChatListSections(
    normal: partition.normal,
    requests: [
      for (var i = 0; i < partition.requestCandidates.length; i++)
        if (!blockedByPeer[i]) partition.requestCandidates[i],
    ],
  );
});

/// チャットルームのメッセージの履歴（機能仕様書4.4.3）
/// 引数はチャットルームIDと、読める範囲の始まり（グループの参加時刻。1対1はnull）。直近[ChatRepository.messagePageSize]件だけを監視し、それより過去は[MessagesNotifier.loadMore]で追加で取得する
final messagesProvider = AsyncNotifierProvider.family<MessagesNotifier, MessageHistory, MessagesKey>(
  MessagesNotifier.new,
);

// ============================================================
// Notifier
// ============================================================

/// チャットルームのメッセージの履歴
/// 直近のメッセージの監視と、過去のメッセージの追加の取得をまとめる
class MessagesNotifier extends AsyncNotifier<MessageHistory> {
  MessagesNotifier(this.key);

  // ---- 状態・初期化 ----

  /// チャットルームID
  final MessagesKey key;

  String get chatRoomId => key.chatRoomId;

  /// 読み込んだメッセージの履歴
  late MessageHistoryAccumulator _history;

  /// 過去のメッセージを取得中か
  bool _loadingMore = false;

  /// 直近のメッセージの監視を始める
  /// 最初の結果が届いたら返し、以降は届くたびに状態を更新する
  @override
  Future<MessageHistory> build() {
    _history = MessageHistoryAccumulator(pageSize: ChatRepository.messagePageSize);
    _loadingMore = false;

    final history = _history;
    final first = Completer<MessageHistory>();
    final subscription = ref
        .watch(chatRepositoryProvider)
        .watchLatestMessages(chatRoomId, since: key.since)
        .listen(
          (page) {
            history.applyLive(page.messages, cursor: page.cursor, fromCache: page.isFromCache);
            // 初回の結果はbuildの戻り値として返し、以降はstateを更新して画面へ流す。
            if (!first.isCompleted) {
              first.complete(history.history);
            } else {
              state = AsyncData(history.history);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!first.isCompleted) {
              first.completeError(error, stackTrace);
            } else {
              state = AsyncError(error, stackTrace);
            }
          },
        );
    ref.onDispose(subscription.cancel);
    return first.future;
  }

  // ---- 読み込み ----

  /// 読み込んだ最も古いメッセージより過去の1ページを取得し、履歴に加える
  /// 取得中・これ以上過去が無い場合は何もしない（失敗したら状態を変えず、次に一覧の先頭に着いたときにやり直す）
  Future<void> loadMore() async {
    final history = _history;
    final cursor = history.cursor;
    if (_loadingMore || !history.hasMore || cursor == null) return;

    _loadingMore = true;
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .fetchOlderMessages(chatRoomId, cursor: cursor, limit: ChatRepository.messagePageSize, since: key.since);
      // 取得中に画面が閉じた／監視が作り直された場合は、古い履歴へ反映しない。作り直した後もref.mountedは
      // （新しいRefを指すため）trueのままなので、履歴が同じものかどうかも確かめる。
      if (!ref.mounted || !identical(history, _history)) return;
      history.addOlder(page.messages, cursor: page.cursor);
      state = AsyncData(history.history);
    } catch (_) {
      // 通信失敗など。次にリストの先頭へ到達したときに再試行する。
    } finally {
      _loadingMore = false;
    }
  }
}
