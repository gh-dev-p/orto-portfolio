import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/chat_list_sections.dart';
import 'package:multi_id_msg/domain/models/account_notification_settings.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/domain/models/message.dart';
import 'package:multi_id_msg/domain/models/notification_target.dart';

void main() {
  group('groupReadCount', _groupReadCountTests);

  test('グループごとの通知オフを読み取る', () {
    expect(AccountNotificationSettings.fromData(null).mutedGroupIds, isEmpty);
    expect(
      AccountNotificationSettings.fromData({
        'mutedGroupIds': ['g1'],
      }).mutedGroupIds,
      ['g1'],
    );
  });

  test('「~」を含まないルームIDをグループとして扱う', () {
    expect(isGroupChatRoomId('Ab12Cd34'), isTrue);
    expect(isGroupChatRoomId(buildChatRoomId('alice', 'bob')), isFalse);
  });

  test('システムメッセージの種類を読み取る', () {
    expect(MessageType.fromValue('system'), MessageType.system);
    final preview = LastMessagePreview.fromMap({
      'messageId': 'm1',
      'type': 'system',
      'senderId': 'alice',
      'systemType': 'member_joined',
      'targetAccountIds': ['bob'],
    });
    expect(preview.type, MessageType.system);
    expect(preview.systemType, 'member_joined');
    expect(preview.targetAccountIds, ['bob']);
  });

  group('partitionChatRooms', () {
    test('グループは友だち・ブロックの関係によらず通常のトークに入る', () {
      const group = ChatListEntry(chatRoomId: 'g1', peerAccountId: null, isGroup: true, name: 'グループ');
      final partition = partitionChatRooms(
        rooms: const [group],
        friendAccountIds: const {},
        blockedAccountIds: const {},
      );
      expect(partition.normal, [group]);
      expect(partition.requestCandidates, isEmpty);
    });
  });

  group('NotificationTarget.fromData', () {
    test('グループのトークは相手のIDが無くても開ける', () {
      final target = NotificationTarget.fromData({'type': 'message', 'accountId': 'bob', 'chatRoomId': 'g1'});
      expect(target, isNotNull);
      expect(target!.peerAccountId, isNull);
    });

    test('1対1のトークは相手のIDが無ければ開けない', () {
      expect(NotificationTarget.fromData({'accountId': 'bob', 'chatRoomId': 'alice~bob'}), isNull);
    });

    test('グループへの招待の通知を読み取る', () {
      final target = NotificationTarget.fromData({'type': 'group_invite', 'accountId': 'bob', 'chatRoomId': 'g1'});
      expect(target!.isGroupInvite, isTrue);
      expect(
        NotificationTarget.fromData({'type': 'message', 'accountId': 'bob', 'chatRoomId': 'g1'})!.isGroupInvite,
        isFalse,
      );
    });
  });
}

void _groupReadCountTests() {
  final base = DateTime(2026, 11, 1, 12);
  final members = [
    GroupMember(accountId: 'me', lastReadAt: base.add(const Duration(hours: 1))),
    GroupMember(accountId: 'read', lastReadAt: base.add(const Duration(minutes: 1))),
    GroupMember(accountId: 'same', lastReadAt: base),
    GroupMember(accountId: 'old', lastReadAt: base.subtract(const Duration(minutes: 1))),
    const GroupMember(accountId: 'never'),
  ];

  test('メッセージの後にトークを開いた人を、自分を除いて数える', () {
    expect(groupReadCount(members, base, myAccountId: 'me'), 2);
  });

  test('送信中で時刻が無いメッセージは0', () {
    expect(groupReadCount(members, null, myAccountId: 'me'), 0);
  });
}
