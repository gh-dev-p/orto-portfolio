import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';

void main() {
  group('未読のリアクションの件数', () {
    test('unreadReactionsのキーの数を数える', () {
      expect(unreadReactionCount({'unreadReactions': {'m1~peer': true, 'm2~peer': true}}), 2);
    });

    test('フィールド・データが無いときは0', () {
      expect(unreadReactionCount({'unreadCount': 3}), 0);
      expect(unreadReactionCount(null), 0);
    });
  });

  group('トーク一覧のプレビューを「リアクションされました」にするか', () {
    final t1 = DateTime(2026, 10, 8, 10);
    final t2 = DateTime(2026, 10, 8, 11);

    test('未読のリアクションのうち、最も新しい日時を取り出す（日時が無い値は無視する）', () {
      expect(
        unreadReactionLatestAt({
          'unreadReactions': {'m1~a': Timestamp.fromDate(t1), 'm2~a': Timestamp.fromDate(t2), 'm3~a': true},
        }),
        t2,
      );
      expect(unreadReactionLatestAt({'unreadReactions': {'m1~a': true}}), isNull);
      expect(unreadReactionLatestAt(null), isNull);
    });

    test('最新メッセージより後に付いたときだけ', () {
      ChatListEntry entry({DateTime? messageAt, DateTime? reactedAt}) => ChatListEntry(
        chatRoomId: 'a~b',
        peerAccountId: 'b',
        lastMessageAt: messageAt,
        latestUnreadReactionAt: reactedAt,
      );
      expect(entry(messageAt: t1, reactedAt: t2).showsReactionPreview, isTrue);
      expect(entry(messageAt: t2, reactedAt: t1).showsReactionPreview, isFalse);
      expect(entry(messageAt: t1).showsReactionPreview, isFalse);
      expect(entry(reactedAt: t1).showsReactionPreview, isTrue);
    });
  });
}
