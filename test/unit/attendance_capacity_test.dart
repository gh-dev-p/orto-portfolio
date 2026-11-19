// オフ会グループの出欠（機能仕様書4.7.8.9、データ設計書8.18）と、
// 定員・キャンセル待ち（4.7.8.10、8.19）
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/domain/models/notification_target.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/group/widgets/capacity_dialog.dart';
import 'package:multi_id_msg/ui/group/widgets/group_failure_message.dart';
import 'package:multi_id_msg/ui/group/widgets/group_system_text.dart';

// ignore: subtype_of_sealed_class
class _FakeDoc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this.id, this._data);

  @override
  final String id;

  final Map<String, dynamic>? _data;

  @override
  Map<String, dynamic>? data() => _data;
}

GroupAttendance _answer(String id, AttendanceResponse response) => GroupAttendance(accountId: id, response: response);

void main() {
  test('出欠の答えを読む。参加・不参加のほかは読まない', () {
    expect(AttendanceResponse.fromValue('yes'), AttendanceResponse.yes);
    expect(AttendanceResponse.fromValue('no'), AttendanceResponse.no);
    expect(AttendanceResponse.fromValue('maybe'), isNull);
    final doc = GroupAttendance.fromFirestore(
      _FakeDoc('bob', {'response': 'no', 'updatedAt': Timestamp.fromDate(DateTime(2026, 11, 16))}),
    )!;
    expect(doc.accountId, 'bob');
    expect(doc.response, AttendanceResponse.no);
    expect(GroupAttendance.fromFirestore(_FakeDoc('bob', {'response': 'later'})), isNull);
  });

  test('集計は今のメンバーだけを数え、それぞれ自分を先頭にする', () {
    final summary = AttendanceSummary.of(
      ['alice', 'bob', 'carol', 'dave', 'me'],
      [
        _answer('bob', AttendanceResponse.yes),
        _answer('me', AttendanceResponse.yes),
        _answer('carol', AttendanceResponse.no),
        // 抜けた人の答えが残っていても数えない
        _answer('left', AttendanceResponse.yes),
      ],
      myAccountId: 'me',
    );
    expect(summary.yes, ['me', 'bob']);
    expect(summary.no, ['carol']);
    expect(summary.unanswered, ['alice', 'dave']);
    expect(summary.responseOf('me'), AttendanceResponse.yes);
    expect(summary.responseOf('carol'), AttendanceResponse.no);
    expect(summary.responseOf('alice'), isNull);
  });

  test('締切を過ぎたか。締切なしは過ぎない', () {
    final deadline = DateTime(2026, 11, 20, 21);
    expect(isAttendanceDeadlinePassed(null, DateTime(2030)), isFalse);
    expect(isAttendanceDeadlinePassed(deadline, DateTime(2026, 11, 20, 20, 59)), isFalse);
    expect(isAttendanceDeadlinePassed(deadline, deadline), isTrue);
  });

  test('締切に選べる最も遅い日時は、会の日時か1年後の早いほう', () {
    final now = DateTime(2026, 11, 16, 10);
    expect(attendanceDeadlineLatest(null, now), now.add(const Duration(days: 365)));
    final eventAt = DateTime(2026, 11, 22, 19);
    expect(attendanceDeadlineLatest(eventAt, now), eventAt);
    expect(attendanceDeadlineLatest(DateTime(2028), now), now.add(const Duration(days: 365)));
  });

  test('ルームから参加者・定員・締切を読む。普通のグループは定員・締切を持たない', () {
    final meetup = GroupRoom.fromMap('g1', {
      'groupKind': 'meetup',
      'organizerIds': ['alice'],
      'participantIds': ['alice', 'bob'],
      'capacity': 10,
      'attendanceDeadline': Timestamp.fromDate(DateTime(2026, 11, 20, 21)),
    });
    expect(meetup.participantIds, ['alice', 'bob']);
    expect(meetup.capacity, 10);
    expect(meetup.attendanceDeadline, DateTime(2026, 11, 20, 21));
    expect(displayedCapacity(meetup), 10);
    final standard = GroupRoom.fromMap('g2', {
      'participantIds': ['alice'],
      'capacity': 10,
      'attendanceDeadline': Timestamp.fromDate(DateTime(2026, 11, 20)),
    });
    expect(standard.capacity, isNull);
    expect(standard.attendanceDeadline, isNull);
    expect(displayedCapacity(standard), isNull);
    expect(displayedCapacity(null), isNull);
  });

  test('招待のプレビューから定員と満員を読む。古いサーバーの値は定員なし・満員でない', () {
    final full = GroupInvitePreview.fromMap({
      'chatRoomId': 'g1',
      'name': 'ボドゲ会',
      'memberCount': 10,
      'isMember': false,
      'isMeetup': true,
      'capacity': 10,
      'isFull': true,
    });
    expect(full.capacity, 10);
    expect(full.isFull, isTrue);
    final old = GroupInvitePreview.fromMap({'chatRoomId': 'g1', 'name': 'ボドゲ会', 'memberCount': 1, 'isMember': false});
    expect(old.capacity, isNull);
    expect(old.isFull, isFalse);
  });

  test('キャンセル待ちから繰り上がった承認待ちを見分ける', () {
    final promoted = GroupJoinRequest.fromFirestore(
      _FakeDoc('carol', {
        'status': 'pending',
        'answers': <Object>[],
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 16)),
        'promotedAt': Timestamp.fromDate(DateTime(2026, 11, 17)),
      }),
    )!;
    expect(promoted.isPromoted, isTrue);
    final waiting = GroupJoinRequest.fromFirestore(
      _FakeDoc('dave', {'status': 'waitlisted', 'promotedAt': Timestamp.fromDate(DateTime(2026, 11, 17))}),
    )!;
    expect(waiting.isPromoted, isFalse);
    final plain = GroupJoinRequest.fromFirestore(_FakeDoc('erin', {'status': 'pending'}))!;
    expect(plain.isPromoted, isFalse);
  });

  test('定員の入力は2〜100の整数だけ', () {
    expect(parseCapacity('2'), 2);
    expect(parseCapacity(' 100 '), 100);
    expect(parseCapacity('1'), isNull);
    expect(parseCapacity('101'), isNull);
    expect(parseCapacity(''), isNull);
    expect(parseCapacity('十'), isNull);
  });

  test('出欠の催促・繰り上げの通知を読む。開く先は今の種類と同じ', () {
    final reminder = NotificationTarget.fromData({
      'type': 'attendance_reminder',
      'accountId': 'bob',
      'chatRoomId': 'g1',
    })!;
    expect(reminder.isAttendanceReminder, isTrue);
    expect(reminder.isJoinRequest, isFalse);
    expect(reminder == NotificationTarget.fromData({'accountId': 'bob', 'chatRoomId': 'g1'}), isTrue);

    final organizers = NotificationTarget.fromData({
      'type': 'join_request',
      'promoted': 'true',
      'accountId': 'alice',
      'chatRoomId': 'g1',
    })!;
    expect(organizers.isWaitlistPromoted, isTrue);
    expect(organizers.isJoinRequest, isTrue);

    final applicant = NotificationTarget.fromData({
      'type': 'join_result',
      'status': 'pending',
      'groupName': 'ボドゲ会',
      'accountId': 'carol',
      'chatRoomId': 'g1',
    })!;
    expect(applicant.joinResult, JoinStatus.pending);
    expect(applicant.opensJoinApplications, isTrue);
  });

  test('失敗の文言とシステムメッセージ', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    expect(groupFailureMessage(l10n, GroupFailure.fromValue('invalid-deadline'), fallback: 'x'), contains('締切'));
    expect(groupFailureMessage(l10n, GroupFailure.fromValue('reminder-too-soon'), fallback: 'x'), contains('6時間'));
    expect(groupFailureMessage(l10n, GroupFailure.fromValue('invalid-capacity'), fallback: 'x'), '定員は2〜100人にしてください');
    expect(groupFailureMessage(l10n, GroupFailure.fromValue('invalid-response'), fallback: 'x'), 'x');
    expect(groupFailureMessage(l10n, GroupFailure.fromValue('not-meetup'), fallback: 'x'), 'x');
    expect(
      groupSystemText(l10n, systemType: 'attendance_deadline_updated', actorName: '太郎', targetName: ''),
      '太郎さんが出欠の締切を更新しました',
    );
    expect(groupSystemText(l10n, systemType: 'capacity_updated', actorName: '太郎', targetName: ''), '太郎さんが定員を変更しました');
  });
}
