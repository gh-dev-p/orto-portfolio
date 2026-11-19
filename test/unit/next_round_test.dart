// 次の回のオフ会グループ（機能仕様書4.7.8.13、データ設計書8.21）
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/group/widgets/group_failure_message.dart';
import 'package:multi_id_msg/ui/group/widgets/next_round_screen.dart';

// ignore: subtype_of_sealed_class
class _FakeDoc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this.id, this._data);

  @override
  final String id;

  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic>? data() => _data;
}

void main() {
  final closesAt = DateTime(2026, 11, 20, 12);

  GroupRoom meetup({Map<String, dynamic> extra = const {}}) => GroupRoom.fromMap('room', {
    'groupKind': 'meetup',
    'organizerIds': ['alice', 'bob'],
    'participantIds': ['alice', 'bob', 'carol'],
    'closesAt': Timestamp.fromDate(closesAt),
    ...extra,
  });

  group('次の回を作れるか', () {
    test('主催チームの人が、閉じてから30日のあいだだけ作れる', () {
      final room = meetup();
      expect(room.canCreateNextRound('alice', closesAt.subtract(const Duration(minutes: 1))), isFalse);
      expect(room.canCreateNextRound('alice', closesAt), isTrue);
      expect(room.canCreateNextRound('bob', closesAt.add(const Duration(days: 29))), isTrue);
      expect(room.canCreateNextRound('alice', closesAt.add(const Duration(days: 30))), isFalse);
    });

    test('主催チームでないメンバー・普通のグループは作れない', () {
      expect(meetup().canCreateNextRound('carol', closesAt), isFalse);
      final standard = GroupRoom.fromMap('room', {
        'organizerIds': ['alice'],
        'closesAt': Timestamp.fromDate(closesAt),
      });
      expect(standard.canCreateNextRound('alice', closesAt), isFalse);
    });

    test('次の回のIDを読む（普通のグループでは読まない）', () {
      expect(meetup(extra: {'nextChatRoomId': 'next'}).nextChatRoomId, 'next');
      expect(meetup().nextChatRoomId, isNull);
      expect(GroupRoom.fromMap('room', {'nextChatRoomId': 'next'}).nextChatRoomId, isNull);
    });
  });

  group('次の回の招待', () {
    test('前の回の名前と主催チームの印を読む', () {
      final request = GroupRequest.fromFirestore(
        _FakeDoc('next', {
          'invitedBy': 'alice',
          'name': 'ボドゲ会 11月',
          'memberCount': 1,
          'previousChatRoomId': 'room',
          'previousName': 'ボドゲ会 10月',
          'asOrganizer': true,
        }),
      );
      expect(request.previousName, 'ボドゲ会 10月');
      expect(request.asOrganizer, isTrue);
    });

    test('普通の招待には前の回が無い', () {
      final request = GroupRequest.fromFirestore(
        _FakeDoc('group', {'invitedBy': 'alice', 'name': '友だち', 'memberCount': 2}),
      );
      expect(request.previousName, isNull);
      expect(request.asOrganizer, isFalse);
    });

    test('招待の行の2行目に前の回の名前を出す', () {
      final ja = lookupAppLocalizations(const Locale('ja'));
      expect(ja.grpRequestNextRound('ボドゲ会 10月', 'あきこ'), '「ボドゲ会 10月」の次の回・あきこからの招待');
    });
  });

  group('招待の候補', () {
    test('自分を除き、主催チームの人を先に並べる', () {
      final members = [
        const GroupMember(accountId: 'carol'),
        const GroupMember(accountId: 'alice'),
        const GroupMember(accountId: 'bob'),
      ];
      expect(nextRoundCandidates(members, room: meetup(), myAccountId: 'alice'), ['bob', 'carol']);
    });
  });

  group('失敗の文言', () {
    test('次の回があるとき・記録が消えたとき', () {
      final ja = lookupAppLocalizations(const Locale('ja'));
      expect(GroupFailure.fromValue('next-round-exists'), GroupFailure.nextRoundExists);
      expect(GroupFailure.fromValue('group-not-closed'), GroupFailure.groupNotClosed);
      expect(nextRoundFailureMessage(ja, GroupFailure.nextRoundExists), '次の回はすでに作られています');
      expect(nextRoundFailureMessage(ja, GroupFailure.groupDeleted), '記録が消えたため、次の回を作れません');
      expect(nextRoundFailureMessage(ja, GroupFailure.groupClosed), 'このグループは閉じています');
      expect(groupFailureMessage(ja, GroupFailure.groupNotClosed, fallback: 'x'), 'x');
    });
  });
}
