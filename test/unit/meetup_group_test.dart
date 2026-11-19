// オフ会グループと主催チーム（機能仕様書4.7.8、データ設計書8.14）
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/domain/models/notification_target.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/group/widgets/group_failure_message.dart';
import 'package:multi_id_msg/ui/group/widgets/group_info_screen.dart';
import 'package:multi_id_msg/ui/group/widgets/group_system_text.dart';

// ignore: subtype_of_sealed_class
class _FakeDoc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this.id, this._data);

  @override
  final String id;

  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic>? data() => _data;
}

const _meetup = GroupRoom(chatRoomId: 'g1', kind: GroupKind.meetup, organizerIds: ['alice']);
const _standard = GroupRoom(chatRoomId: 'g1');

GroupMember _member(String id, {String? invitedBy}) => GroupMember(accountId: id, organizerInvitedBy: invitedBy);

void main() {
  test('種類の値を読み取る。無い・知らない値は普通のグループ', () {
    expect(GroupKind.fromValue('meetup'), GroupKind.meetup);
    expect(GroupKind.fromValue(null), GroupKind.standard);
    expect(GroupKind.fromValue('other'), GroupKind.standard);
    expect(GroupKind.meetup.value, 'meetup');
  });

  test('ルームから種類と主催チームを読み取る。普通のグループは主催チームを持たない', () {
    final meetup = GroupRoom.fromMap('g1', {
      'groupKind': 'meetup',
      'organizerIds': ['alice', 1],
    });
    expect(meetup.isMeetup, isTrue);
    expect(meetup.organizerIds, ['alice']);
    expect(meetup.isOrganizer('alice'), isTrue);
    expect(meetup.isOrganizer('bob'), isFalse);

    final standard = GroupRoom.fromMap('g1', {
      'organizerIds': ['alice'],
    });
    expect(standard.isMeetup, isFalse);
    expect(standard.isOrganizer('alice'), isFalse);
  });

  test('トーク一覧の行から種類を読み取る。1対1はオフ会にならない', () {
    final meetup = ChatListEntry.fromFirestore(_FakeDoc('g1', {'type': 'group', 'groupKind': 'meetup'}));
    expect(meetup.isMeetup, isTrue);
    final standard = ChatListEntry.fromFirestore(_FakeDoc('g2', {'type': 'group'}));
    expect(standard.isMeetup, isFalse);
    final direct = ChatListEntry.fromFirestore(_FakeDoc('a~b', {'peerAccountId': 'b', 'groupKind': 'meetup'}));
    expect(direct.isMeetup, isFalse);
  });

  test('誘いのフィールドを読み取る', () {
    final member = GroupMember.fromFirestore(_FakeDoc('bob', {'organizerInvitedBy': 'alice'}));
    expect(member.isInvitedToOrganizers, isTrue);
    expect(member.organizerInvitedBy, 'alice');
    expect(GroupMember.fromFirestore(_FakeDoc('bob', {})).isInvitedToOrganizers, isFalse);
  });

  group('メンバー一覧の並び', () {
    final members = [_member('carol'), _member('alice'), _member('me'), _member('bob')];

    test('オフ会グループは主催チームとそのほかに分け、それぞれ自分を先頭にする', () {
      const room = GroupRoom(chatRoomId: 'g1', kind: GroupKind.meetup, organizerIds: ['alice', 'me']);
      final sections = groupMemberSections(members, room: room, myAccountId: 'me');
      expect(sections.organizers.map((m) => m.accountId), ['me', 'alice']);
      expect(sections.others.map((m) => m.accountId), ['carol', 'bob']);
    });

    test('普通のグループ・ルームが読めないときは全員をそのほかに入れる', () {
      for (final room in [_standard, null]) {
        final sections = groupMemberSections(members, room: room, myAccountId: 'me');
        expect(sections.organizers, isEmpty);
        expect(sections.others.map((m) => m.accountId), ['me', 'carol', 'alice', 'bob']);
      }
    });
  });

  group('メンバーの行のメニュー', () {
    test('普通のグループは今のまま（自分以外に「退会させる」）', () {
      expect(groupMemberActions(room: _standard, myAccountId: 'me', member: _member('bob')), [
        GroupMemberAction.remove,
      ]);
      expect(groupMemberActions(room: _standard, myAccountId: 'me', member: _member('me')), isEmpty);
    });

    test('オフ会グループで主催チームでない人には、メニューを出さない', () {
      expect(groupMemberActions(room: _meetup, myAccountId: 'bob', member: _member('carol')), isEmpty);
      expect(groupMemberActions(room: _meetup, myAccountId: 'bob', member: _member('alice')), isEmpty);
      expect(groupMemberActions(room: _meetup, myAccountId: 'bob', member: _member('bob')), isEmpty);
    });

    test('主催チームの人には、入れる・外す・抜ける・退会させるを出す', () {
      const room = GroupRoom(chatRoomId: 'g1', kind: GroupKind.meetup, organizerIds: ['alice', 'dave']);
      expect(groupMemberActions(room: room, myAccountId: 'alice', member: _member('bob')), [
        GroupMemberAction.inviteToOrganizers,
        GroupMemberAction.remove,
      ]);
      expect(
        groupMemberActions(
          room: room,
          myAccountId: 'alice',
          member: _member('bob', invitedBy: 'dave'),
        ),
        [GroupMemberAction.remove],
      );
      expect(groupMemberActions(room: room, myAccountId: 'alice', member: _member('dave')), [
        GroupMemberAction.removeFromOrganizers,
        GroupMemberAction.remove,
      ]);
      expect(groupMemberActions(room: room, myAccountId: 'alice', member: _member('alice')), [
        GroupMemberAction.leaveOrganizers,
      ]);
    });
  });

  test('主催チームへの誘いの通知は、グループのトークを開く', () {
    final target = NotificationTarget.fromData({'type': 'organizer_invite', 'accountId': 'bob', 'chatRoomId': 'g1'})!;
    expect(target.isOrganizerInvite, isTrue);
    expect(target.isGroupInvite, isFalse);
    expect(target.peerAccountId, isNull);
  });

  test('名前の代わりの「退会済みアカウント」「不明なアカウント」には「さん」を付けない', () {
    final ja = lookupAppLocalizations(const Locale('ja'));
    expect(groupPersonName(ja, 'B'), 'Bさん');
    expect(groupPersonName(ja, '退会済みアカウント'), '退会済みアカウント');
    expect(groupPersonName(ja, '不明なアカウント'), '不明なアカウント');
    expect(
      groupSystemText(ja, systemType: 'member_left', actorName: '退会済みアカウント', targetName: '退会済みアカウント'),
      '退会済みアカウントが退会しました',
    );
    expect(
      groupSystemText(ja, systemType: 'member_removed', actorName: 'A', targetName: '不明なアカウント'),
      'Aさんが不明なアカウントを退会させました',
    );
    final en = lookupAppLocalizations(const Locale('en'));
    expect(groupSystemText(en, systemType: 'member_joined', actorName: 'A', targetName: 'B'), 'B joined');
  });

  test('システムメッセージと失敗の文言', () {
    final l10n = lookupAppLocalizations(const Locale('ja'));
    expect(groupSystemText(l10n, systemType: 'organizer_added', actorName: 'A', targetName: 'B'), 'Bさんが主催チームに入りました');
    expect(groupSystemText(l10n, systemType: 'organizer_removed', actorName: 'A', targetName: 'B'), 'Bさんが主催チームから外れました');
    expect(l10n.grpRemoveFromOrganizersConfirm(groupPersonName(l10n, 'B')), 'Bさんを主催チームから外しますか？');
    expect(GroupFailure.fromValue('last-organizer'), GroupFailure.lastOrganizer);
    expect(
      groupFailureMessage(l10n, GroupFailure.lastOrganizer, fallback: 'x'),
      '主催チームがあなただけのため抜けられません。先にほかのメンバーを主催チームに入れてください。',
    );
    expect(groupFailureMessage(l10n, GroupFailure.notOrganizer, fallback: 'x'), 'x');
  });
}
