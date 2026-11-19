import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/models/blocked_account.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';
import 'package:multi_id_msg/domain/models/firestore_values.dart';
import 'package:multi_id_msg/domain/models/message.dart';

// 他の人が書いた値に型の違うものがあっても、一覧やトークの全体を止めないことを確かめる（認可の監査の項目1・2・6）

class _FakeMetadata extends Fake implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
}

// ignore: subtype_of_sealed_class
class _FakeDoc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this.id, this._data);

  @override
  final String id;

  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  SnapshotMetadata get metadata => _FakeMetadata();
}

void main() {
  group('Message.fromFirestore', () {
    test('型の違う値は無いものとして扱う', () {
      final message = Message.fromFirestore(
        _FakeDoc('m', {
          'senderId': 'alice',
          'type': 1,
          'text': 123,
          'imageWidth': double.nan,
          'imageHeight': double.infinity,
          'createdAt': 'poison',
          'readBy': [1, 'bob'],
          'reactions': {'bob': 123, 'alice': '👍'},
          'hiddenFor': 'alice',
          'targetAccountIds': [1],
          'systemType': 123,
          'unsentAt': 'poison',
        }),
      );
      expect(message.text, '');
      expect(message.type, MessageType.text);
      expect(message.imageWidth, isNull);
      expect(message.imageHeight, isNull);
      expect(message.createdAt, isNull);
      expect(message.readBy, ['bob']);
      expect(message.reactions, {'alice': '👍'});
      expect(message.hiddenFor, isEmpty);
      expect(message.targetAccountIds, isEmpty);
      expect(message.systemType, isNull);
      expect(message.unsentAt, isNull);
    });

    test('正しい値はそのまま読む', () {
      final at = DateTime(2026, 1, 1);
      final message = Message.fromFirestore(
        _FakeDoc('m', {
          'senderId': 'alice',
          'type': 'image',
          'imagePath': 'p',
          'imageWidth': 800,
          'imageHeight': 600.0,
          'createdAt': Timestamp.fromDate(at),
          'readBy': ['alice'],
          'reactions': {'bob': '👍'},
        }),
      );
      expect(message.type, MessageType.image);
      expect(message.imageWidth, 800);
      expect(message.imageHeight, 600);
      expect(message.createdAt, at);
      expect(message.reactions, {'bob': '👍'});
    });
  });

  group('ChatListEntry.fromFirestore', () {
    test('改ざんされたlastMessageでも行は読める', () {
      for (final poison in <Map<String, dynamic>>[
        {'systemType': 123},
        {'targetAccountIds': [1]},
        {'createdAt': 'poison'},
        {'type': 1, 'text': 1, 'senderId': 1, 'messageId': 1},
      ]) {
        final entry = ChatListEntry.fromFirestore(
          _FakeDoc('alice~carol', {'peerAccountId': 'carol', 'lastMessage': poison, 'lastMessageAt': 'poison'}),
        );
        expect(entry.peerAccountId, 'carol');
        expect(entry.lastMessage, isNotNull);
        expect(entry.lastMessageAt, isNull);
      }
    });

    test('lastMessageがmapでなければ無いものとして扱う', () {
      final entry = ChatListEntry.fromFirestore(_FakeDoc('a~b', {'lastMessage': 'poison', 'unreadReactions': 1}));
      expect(entry.lastMessage, isNull);
      expect(entry.unreadCount, 0);
    });
  });

  test('Account.fromFirestoreは型の違う値で例外にしない', () {
    final account = Account.fromFirestore(
      _FakeDoc('alice', {'displayName': 123, 'bio': {'a': 1}, 'allowIdSearch': 'x', 'isDeleted': 'yes'}),
    );
    expect(account.displayName, '');
    expect(account.bio, isNull);
    expect(account.allowIdSearch, isTrue);
    expect(account.isDeleted, isFalse);
  });

  group('BlockedAccount.fromFirestore', () {
    final at = DateTime(2026, 1, 1);

    test('blockedAccountDatesの日時を優先する', () {
      final account = BlockedAccount.fromFirestore(_FakeDoc('bob', {'blockedAccountId': 'bob'}), blockedAt: at);
      expect(account.blockedAt, at);
    });

    test('以前のドキュメントの日時も読める', () {
      final account = BlockedAccount.fromFirestore(
        _FakeDoc('bob', {'blockedAccountId': 'bob', 'blockedAt': Timestamp.fromDate(at)}),
      );
      expect(account.blockedAt, at);
    });
  });

  test('parseSkippingBrokenは解析できない項目だけを飛ばす', () {
    final parsed = parseSkippingBroken<_FakeDoc, Message>([
      _FakeDoc('ok', {'senderId': 'alice'}),
      _FakeDoc('broken', {'senderId': 1}),
      _FakeDoc('ok2', {'senderId': 'bob'}),
    ], Message.fromFirestore);
    expect(parsed.map((m) => m.id), ['ok', 'ok2']);
  });
}
