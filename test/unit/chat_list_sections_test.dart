import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/chat_list_sections.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';

ChatListEntry _room(String peerId, {bool hasMessage = true}) => ChatListEntry(
  chatRoomId: buildChatRoomId('me', peerId),
  peerAccountId: peerId,
  lastMessage: hasMessage ? LastMessagePreview(messageId: 'm1', text: 'hi', senderId: peerId) : null,
);

ChatRoomPartition _partition(
  List<ChatListEntry> rooms, {
  Set<String> friends = const {},
  Set<String> blocked = const {},
}) => partitionChatRooms(rooms: rooms, friendAccountIds: friends, blockedAccountIds: blocked);

List<String> _peers(List<ChatListEntry> rooms) => [for (final r in rooms) r.peerAccountId!];

void main() {
  group('partitionChatRooms', () {
    test('相手が友だちのルームは、メッセージの有無に関わらず通常のトークリストに入る', () {
      final result = _partition([_room('bob'), _room('carol', hasMessage: false)], friends: {'bob', 'carol'});
      expect(_peers(result.normal), ['bob', 'carol']);
      expect(result.requestCandidates, isEmpty);
    });

    test('友だちでない相手からのメッセージ付きルームは、リクエスト候補になる', () {
      final result = _partition([_room('dave')]);
      expect(result.normal, isEmpty);
      expect(_peers(result.requestCandidates), ['dave']);
    });

    test('友だちでない相手で、メッセージがまだ無いルームはどちらにも表示しない', () {
      final result = _partition([_room('erin', hasMessage: false)]);
      expect(result.normal, isEmpty);
      expect(result.requestCandidates, isEmpty);
    });

    test('自分がブロックした相手のルームは、友だちでもリクエストでもどちらにも表示しない', () {
      final result = _partition(
        [_room('bob'), _room('dave')],
        friends: {'bob'},
        blocked: {'bob', 'dave'},
      );
      expect(result.normal, isEmpty);
      expect(result.requestCandidates, isEmpty);
    });

    test('通常・リクエスト・非表示が混在しても、元の並び順を保って振り分ける', () {
      final result = _partition(
        [_room('a1'), _room('b1'), _room('a2'), _room('b2'), _room('x')],
        friends: {'a1', 'a2'},
        blocked: {'x'},
      );
      expect(_peers(result.normal), ['a1', 'a2']);
      expect(_peers(result.requestCandidates), ['b1', 'b2']);
    });

    group('ブロックを解除した相手（chatListにblockedAtがある）', () {
      final blockedAt = DateTime(2026, 10, 8, 12);
      ChatListEntry unblocked(String peerId, DateTime lastMessageAt) => ChatListEntry(
        chatRoomId: buildChatRoomId('me', peerId),
        peerAccountId: peerId,
        lastMessage: LastMessagePreview(messageId: 'm1', text: 'hi', senderId: peerId),
        lastMessageAt: lastMessageAt,
        blockedAt: blockedAt,
      );

      test('ブロック前のメッセージしか無ければ、リクエストに出さない（解除しただけでは出ない）', () {
        final result = _partition([unblocked('bob', blockedAt.subtract(const Duration(days: 1)))]);
        expect(result.normal, isEmpty);
        expect(result.requestCandidates, isEmpty);
      });

      test('ブロックした日時より新しいメッセージがあれば、リクエスト候補になる', () {
        final result = _partition([unblocked('bob', blockedAt.add(const Duration(minutes: 1)))]);
        expect(_peers(result.requestCandidates), ['bob']);
      });

      test('友だちに追加し直した相手は、メッセージの日時に関わらず通常のトークリストに入る', () {
        final result = _partition([unblocked('bob', blockedAt.subtract(const Duration(days: 1)))], friends: {'bob'});
        expect(_peers(result.normal), ['bob']);
      });
    });

    test('ルームが無ければ空', () {
      final result = _partition(const []);
      expect(result.normal, isEmpty);
      expect(result.requestCandidates, isEmpty);
    });
  });

  test('ChatListSections.allは通常とリクエストの両方を含む（未読バッジの集計対象）', () {
    final sections = ChatListSections(normal: [_room('bob')], requests: [_room('dave')]);
    expect(_peers(sections.all.toList()), ['bob', 'dave']);
  });
}
