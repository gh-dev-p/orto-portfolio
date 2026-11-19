import 'chat_room.dart';

/// CHA-01（チャット一覧）の表示区分（画面設計書5.3.1）。
class ChatListSections {
  const ChatListSections({this.normal = const [], this.requests = const []});

  /// 通常のトークリスト（相手が友だちのルーム）。
  final List<ChatListEntry> normal;

  /// 「未確認のトークリクエスト」（友だち未追加の相手からメッセージを受信したルーム）。
  final List<ChatListEntry> requests;

  /// 未読バッジの集計対象（通常のルーム＋リクエスト）。ブロック済み・ブロックされた
  /// 相手のルームなど、一覧に表示しないルームは含まない。
  Iterable<ChatListEntry> get all => [...normal, ...requests];
}

/// 区分けの第1段階の結果。[requestCandidates]は、「相手にブロックされていないか」の
/// 確認（非同期）を経て初めてリクエストとして確定する。
class ChatRoomPartition {
  const ChatRoomPartition({required this.normal, required this.requestCandidates});

  final List<ChatListEntry> normal;
  final List<ChatListEntry> requestCandidates;
}

/// [rooms]（自分のトーク一覧）を、相手との関係で区分けする。
///
/// - グループ → 通常のトークリスト（友だち・ブロックの関係で区分けしない。機能仕様書4.7.3.1）
/// - 相手を自分がブロックしている → 一覧に表示しない
/// - 相手が友だち → 通常のトークリスト
/// - 相手が友だちでなく、メッセージが1件以上ある → リクエスト候補
///   （相手をブロックしたことがあれば、ブロックした日時より新しいメッセージがあるときだけ）
/// - 相手が友だちでなく、メッセージも無い → 一覧に表示しない
///
/// 判定は受信側（自分）の友だちコレクションを都度参照して行い、chatListには新規フィールドを
/// 持たせない（友だち関係は片方向のため、追加した側にしか友だちドキュメントが無い）。
/// メッセージの有無は`lastMessage`で見る。友だちでない相手には自分から返信できない
/// （CHA-02のリクエストモード）ため、メッセージがあれば相手からのものである。
/// ただし、ブロックで友だち関係が解除された相手とのトークには、ブロック前のやり取りが残っている。
/// ブロック中は相手が送れないため、`lastMessageAt`が`blockedAt`より新しいときだけ、解除後に
/// 相手から届いたものとしてリクエストにする（解除しただけでリクエストに出さない）。
ChatRoomPartition partitionChatRooms({
  required List<ChatListEntry> rooms,
  required Set<String> friendAccountIds,
  required Set<String> blockedAccountIds,
}) {
  final normal = <ChatListEntry>[];
  final candidates = <ChatListEntry>[];
  for (final room in rooms) {
    final peerId = room.peerAccountId;
    if (room.isGroup || peerId == null) {
      normal.add(room);
      continue;
    }
    if (blockedAccountIds.contains(peerId)) continue;
    if (friendAccountIds.contains(peerId)) {
      normal.add(room);
    } else if (room.lastMessage != null && _hasMessageSinceBlock(room)) {
      candidates.add(room);
    }
  }
  return ChatRoomPartition(normal: normal, requestCandidates: candidates);
}

/// [room]に、相手を最後にブロックした後のメッセージがあるか（ブロックしたことが無ければtrue）
bool _hasMessageSinceBlock(ChatListEntry room) {
  final blockedAt = room.blockedAt;
  if (blockedAt == null) return true;
  final lastMessageAt = room.lastMessageAt;
  return lastMessageAt != null && lastMessageAt.isAfter(blockedAt);
}
