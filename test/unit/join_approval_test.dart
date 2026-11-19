// オフ会グループの参加の承認と参加時の質問（機能仕様書4.7.8.5、データ設計書8.16）
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/domain/models/notification_target.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/group/widgets/group_failure_message.dart';

// ignore: subtype_of_sealed_class
class _FakeDoc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this.id, this._data);

  @override
  final String id;

  final Map<String, dynamic>? _data;

  @override
  Map<String, dynamic>? data() => _data;
}

GroupJoinRequest _request(String id, JoinStatus status, int minute) =>
    GroupJoinRequest(accountId: id, status: status, createdAt: DateTime(2026, 11, 16, 10, minute));

void main() {
  test('申請の状態を読み取る。知らない値はnull', () {
    expect(JoinStatus.fromValue('pending'), JoinStatus.pending);
    expect(JoinStatus.fromValue('waitlisted'), JoinStatus.waitlisted);
    expect(JoinStatus.fromValue('closed'), JoinStatus.closed);
    expect(JoinStatus.fromValue('other'), isNull);
    expect(JoinStatus.fromValue(null), isNull);
    expect(JoinStatus.pending.isOpen, isTrue);
    expect(JoinStatus.waitlisted.isOpen, isTrue);
    expect(JoinStatus.declined.isOpen, isFalse);
  });

  test('ルームから参加時の質問を読む。普通のグループは持たない', () {
    final meetup = GroupRoom.fromMap('g1', {
      'groupKind': 'meetup',
      'organizerIds': ['alice'],
      'joinQuestions': ['XのIDは？', 1, 'どこで知りましたか'],
    });
    expect(meetup.joinQuestions, ['XのIDは？', 'どこで知りましたか']);
    final standard = GroupRoom.fromMap('g1', {
      'joinQuestions': ['Q'],
    });
    expect(standard.joinQuestions, isEmpty);
  });

  test('招待のプレビューから、種類・質問・申請の状態を読む。古いサーバーの値は普通のグループ扱い', () {
    final meetup = GroupInvitePreview.fromMap({
      'chatRoomId': 'g1',
      'name': 'ボドゲ会',
      'memberCount': 3,
      'isMember': false,
      'isMeetup': true,
      'joinQuestions': ['Q1'],
      'applicationStatus': 'waitlisted',
    });
    expect(meetup.isMeetup, isTrue);
    expect(meetup.joinQuestions, ['Q1']);
    expect(meetup.applicationStatus, JoinStatus.waitlisted);
    final old = GroupInvitePreview.fromMap({'chatRoomId': 'g1', 'name': 'グループ', 'memberCount': 1});
    expect(old.isMeetup, isFalse);
    expect(old.joinQuestions, isEmpty);
    expect(old.applicationStatus, isNull);
  });

  test('申請のドキュメントを読む。状態が読めなければ外す', () {
    final request = GroupJoinRequest.fromFirestore(
      _FakeDoc('bob', {
        'status': 'pending',
        'answers': [
          {'question': 'XのIDは？', 'answer': '@bob'},
          'broken',
        ],
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 16)),
      }),
    )!;
    expect(request.accountId, 'bob');
    expect(request.status, JoinStatus.pending);
    expect(request.answers, [(question: 'XのIDは？', answer: '@bob')]);
    expect(request.createdAt, DateTime(2026, 11, 16));
    expect(GroupJoinRequest.fromFirestore(_FakeDoc('bob', {'status': 'unknown'})), isNull);
    expect(GroupJoinRequest.fromFirestore(_FakeDoc('bob', null)), isNull);
  });

  test('出した申請のドキュメントを読む', () {
    final application = JoinApplication.fromFirestore(
      _FakeDoc('g1', {'status': 'declined', 'name': 'ボドゲ会', 'photoURL': 'https://example.com/a.jpg'}),
    )!;
    expect(application.chatRoomId, 'g1');
    expect(application.status, JoinStatus.declined);
    expect(application.name, 'ボドゲ会');
    expect(JoinApplication.fromFirestore(_FakeDoc('g1', {'name': 'x'})), isNull);
  });

  test('GRP-09の並び：承認待ちとキャンセル待ちに分け、申請した順。答え済みは出さない', () {
    final sections = joinRequestSections([
      _request('c', JoinStatus.pending, 3),
      _request('a', JoinStatus.waitlisted, 5),
      _request('b', JoinStatus.pending, 1),
      _request('d', JoinStatus.approved, 0),
      _request('e', JoinStatus.waitlisted, 2),
      const GroupJoinRequest(accountId: 'f', status: JoinStatus.pending),
    ]);
    expect([for (final r in sections.pending) r.accountId], ['b', 'c', 'f']);
    expect([for (final r in sections.waitlisted) r.accountId], ['e', 'a']);
  });

  test('承認の結果を読む。知らない値は参加したものとする', () {
    expect(JoinResponseResult.fromValue('waitlisted'), JoinResponseResult.waitlisted);
    expect(JoinResponseResult.fromValue('declined'), JoinResponseResult.declined);
    expect(JoinResponseResult.fromValue('approved'), JoinResponseResult.approved);
    expect(JoinResponseResult.fromValue(null), JoinResponseResult.approved);
  });

  test('申請の通知・結果の通知を読み分ける', () {
    final request = NotificationTarget.fromData({'type': 'join_request', 'accountId': 'alice', 'chatRoomId': 'g1'})!;
    expect(request.isJoinRequest, isTrue);
    expect(request.joinResult, isNull);
    expect(request.opensJoinApplications, isFalse);

    final approved = NotificationTarget.fromData({
      'type': 'join_result',
      'accountId': 'bob',
      'chatRoomId': 'g1',
      'status': 'approved',
      'groupName': 'ボドゲ会',
    })!;
    expect(approved.joinResult, JoinStatus.approved);
    expect(approved.groupName, 'ボドゲ会');
    expect(approved.opensJoinApplications, isFalse);

    for (final status in ['declined', 'waitlisted', 'closed']) {
      final target = NotificationTarget.fromData({
        'type': 'join_result',
        'accountId': 'bob',
        'chatRoomId': 'g1',
        'status': status,
      })!;
      expect(target.opensJoinApplications, isTrue, reason: status);
    }
    // 開く先が違えば別の通知として扱う
    expect(request == NotificationTarget.fromData({'accountId': 'alice', 'chatRoomId': 'g1'}), isFalse);
  });

  test('失敗の理由を読み、文言にする（申請した人の状態の中身は出さない）', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    expect(GroupFailure.fromValue('approval-required'), GroupFailure.approvalRequired);
    expect(GroupFailure.fromValue('join-request-not-found'), GroupFailure.joinRequestNotFound);
    expect(groupFailureMessage(l10n, GroupFailure.applicantUnavailable, fallback: 'x'), 'この人は今は参加できません。時間をおいてお試しください');
    expect(groupFailureMessage(l10n, GroupFailure.invalidAnswers, fallback: 'x'), contains('質問が変わった'));
    expect(groupFailureMessage(l10n, GroupFailure.approvalRequired, fallback: 'x'), 'x');
    expect(groupFailureMessage(l10n, GroupFailure.invalidQuestions, fallback: 'x'), 'x');
  });

  test('本人が決めた文言（2026-11-16）', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    expect(l10n.grpApplyDeclined('ボドゲ会'), 'ボドゲ会への参加は承認されませんでした');
    expect(l10n.grpApplyClosed('ボドゲ会'), 'ボドゲ会に参加できませんでした');
    expect(l10n.grpJoinRequestBanner(3), '参加の申請 3件');
    expect(l10n.pushJoinWaitlistedBanner('ボドゲ会'), contains('キャンセル待ちになりました'));
  });

  test('友だちを選んで招待できるのは、普通のグループは全員、オフ会グループは主催チームだけ', () {
    const meetup = GroupRoom(chatRoomId: 'g1', kind: GroupKind.meetup, organizerIds: ['alice']);
    expect(canInviteFriends(meetup, 'alice'), isTrue);
    expect(canInviteFriends(meetup, 'bob'), isFalse);
    expect(canInviteFriends(const GroupRoom(chatRoomId: 'g1'), 'bob'), isTrue);
    expect(canInviteFriends(null, 'alice'), isFalse);
  });

  test('メンバーの答えは、承認されて入った申請の答えだけを出す。無ければ何も出さない', () {
    const answers = [(question: 'Q', answer: 'A')];
    expect(
      memberJoinAnswers(const GroupJoinRequest(accountId: 'b', status: JoinStatus.approved, answers: answers)),
      answers,
    );
    expect(memberJoinAnswers(const GroupJoinRequest(accountId: 'b', status: JoinStatus.approved)), isEmpty);
    expect(
      memberJoinAnswers(const GroupJoinRequest(accountId: 'b', status: JoinStatus.declined, answers: answers)),
      isEmpty,
    );
    expect(memberJoinAnswers(null), isEmpty);
  });
}
