import 'package:cloud_firestore/cloud_firestore.dart';

import 'meetup_lifecycle.dart';
import 'settlement.dart';

/// グループの人数の上限（自分を含む。機能仕様書4.7）
const groupMaxMembers = 100;

/// 参加時の質問の数の上限（機能仕様書4.7.8.5）
const groupMaxJoinQuestions = 3;

/// 参加時の質問・答えの1問あたりの文字数の上限
const groupJoinTextMaxLength = 100;

/// オフ会グループの定員の下限（機能仕様書4.7.8.10）。上限は[groupMaxMembers]
const groupMinCapacity = 2;

/// 主催チームの出欠の催促の間隔（機能仕様書4.7.8.9）
const attendanceReminderInterval = Duration(hours: 6);

/// グループの種類（機能仕様書4.7.8、データ設計書8.14）。作成後は変えられない
enum GroupKind {
  /// 普通のグループ（`groupKind`を持たない。全員が同じ権限）
  standard('standard'),

  /// オフ会グループ（主催チームがメンバーの管理をする）
  meetup('meetup');

  const GroupKind(this.value);

  /// Firestore・Cloud Functionsでの値
  final String value;

  /// `groupKind`の値から作る。無い・知らない値は普通のグループ
  static GroupKind fromValue(Object? value) => value == meetup.value ? meetup : standard;
}

/// 友だち選択の招待の方式（機能仕様書4.7.1.1）。作成後は変えられない
enum GroupJoinPolicy {
  auto('auto'),
  approval('approval');

  const GroupJoinPolicy(this.value);

  /// Firestore・Cloud Functionsでの値
  final String value;
}

/// グループの操作に失敗した理由（Cloud Functionsのエラーの`message`、データ設計書8.5）
enum GroupFailure {
  readOnly('read-only'),
  groupFull('group-full'),
  joinLimit('join-limit'),
  createLimit('create-limit'),
  membersExceeded('members-exceeded'),
  groupDeleted('group-deleted'),
  inviteInvalid('invite-invalid'),
  notMember('not-member'),

  /// オフ会グループで、主催チームでない人の操作（機能仕様書4.7.8.2）
  notOrganizer('not-organizer'),

  /// 主催チームの最後の1人が、主催チームやグループから抜けようとした
  lastOrganizer('last-organizer'),

  /// 主催チームへの誘いが無くなっている
  organizerInviteNotFound('organizer-invite-not-found'),

  /// オフ会グループのリンクから、申請を通さずに参加しようとした（機能仕様書4.7.8.5）
  approvalRequired('approval-required'),

  /// 普通のグループに参加の申請をしようとした
  approvalNotRequired('approval-not-required'),

  /// 参加の申請が無くなっている（取り消された・ほかの主催チームの人が先に答えた）
  joinRequestNotFound('join-request-not-found'),

  /// 申請した人が今は参加できない状態（読み取り専用・参加の上限。中身は主催チームに見せない）
  applicantUnavailable('applicant-unavailable'),

  /// 答えの数・長さが質問に合わない（質問が変わった直後など）
  invalidAnswers('invalid-answers'),

  /// 質問の数・長さが決まりに合わない
  invalidQuestions('invalid-questions'),

  /// お知らせが上限（20件）に達している（機能仕様書4.7.8.4）
  announcementLimit('announcement-limit'),

  /// 直そうとしたお知らせが消えている
  announcementNotFound('announcement-not-found'),

  /// 会の日時が選べる範囲（今より後から1年後まで）の外
  invalidEventAt('invalid-event-at'),

  /// 出欠の締切が選べる範囲（今より後から、会の日時か1年後まで）の外（機能仕様書4.7.8.9）
  invalidDeadline('invalid-deadline'),

  /// 出欠の催促を6時間以内にもう一度押した
  reminderTooSoon('reminder-too-soon'),

  /// 出欠の答えが参加・不参加でない
  invalidResponse('invalid-response'),

  /// オフ会グループでない（出欠はオフ会グループだけ）
  notMeetup('not-meetup'),

  /// 定員が2〜100人でない（機能仕様書4.7.8.10）
  invalidCapacity('invalid-capacity'),

  /// 閉じる日が範囲（会の1〜14日後）の外か、閉じる日時が今から1時間以内（機能仕様書4.7.8.6）
  invalidCloseDays('invalid-close-days'),

  /// オフ会グループが閉じている（機能仕様書4.7.8.6）
  groupClosed('group-closed'),

  /// 精算の値（合計・端数の単位・区分・対象）が決まりに合わない（機能仕様書4.7.8.12）
  invalidSettlement('invalid-settlement'),

  /// 精算が始まっていない（ほかの主催チームの人がやめた直後など）
  settlementNotFound('settlement-not-found'),

  /// 精算の対象でないか、払う額が無い
  notSettlementTarget('not-settlement-target'),

  /// 主催チームが確定したあとに、本人が「払った」を取り消そうとした
  paymentConfirmed('payment-confirmed'),

  /// 払い方の値が正しくない
  invalidPayment('invalid-payment'),

  /// 送金リンクが決まりに合わない（PayPayのリンクでない・httpsでない など）
  invalidLink('invalid-link'),

  /// 送金リンクが上限（5件）に達している
  linkLimit('link-limit'),

  /// 閉じる前のオフ会グループから次の回を作ろうとした（機能仕様書4.7.8.13）
  groupNotClosed('group-not-closed'),

  /// 次の回がすでに作られている（ほかの主催チームの人が先に作ったなど）
  nextRoundExists('next-round-exists'),
  unknown('');

  const GroupFailure(this.value);

  final String value;

  static GroupFailure fromValue(String? value) =>
      values.firstWhere((failure) => failure.value == value, orElse: () => unknown);
}

/// グループの操作の失敗（リポジトリが投げる）
class GroupException implements Exception {
  const GroupException(this.failure);

  final GroupFailure failure;
}

/// `accounts/{accountId}/groupRequests/{chatRoomId}` ドキュメント（届いている招待、データ設計書8.2）
/// 招待された側はルームを読めないため、招待した時点のグループの情報を持つ
class GroupRequest {
  const GroupRequest({
    required this.chatRoomId,
    required this.invitedBy,
    required this.name,
    this.photoURL,
    required this.memberCount,
    this.createdAt,
    this.previousName,
    this.asOrganizer = false,
  });

  final String chatRoomId;

  /// 招待したアカウントのID
  final String invitedBy;

  /// 次の回の招待（機能仕様書4.7.8.13）なら、前の回のグループ名。普通の招待はnull
  final String? previousName;

  /// 前の回の主催チームの人への、次の回の招待か（承諾すると主催チームにも入る）
  final bool asOrganizer;

  final String name;
  final String? photoURL;
  final int memberCount;
  final DateTime? createdAt;

  factory GroupRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GroupRequest(
      chatRoomId: doc.id,
      invitedBy: data['invitedBy'] as String? ?? '',
      name: data['name'] as String? ?? '',
      photoURL: data['photoURL'] as String?,
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      previousName: data['previousChatRoomId'] is String ? data['previousName'] as String? ?? '' : null,
      asOrganizer: data['asOrganizer'] == true,
    );
  }
}

/// 招待トークンの確認内容（`previewGroupInvite`の結果。メンバーの一覧は含まない）
class GroupInvitePreview {
  const GroupInvitePreview({
    required this.chatRoomId,
    required this.name,
    this.photoURL,
    required this.memberCount,
    required this.isMember,
    this.isMeetup = false,
    this.joinQuestions = const [],
    this.applicationStatus,
    this.capacity,
    this.isFull = false,
  });

  final String chatRoomId;
  final String name;
  final String? photoURL;
  final int memberCount;

  /// 定員（オフ会グループで決まっているときだけ。機能仕様書4.7.8.10）
  final int? capacity;

  /// 満員かキャンセル待ちがあり、申請するとキャンセル待ちになるか
  final bool isFull;

  /// このアカウントがすでに参加しているか
  final bool isMember;

  /// オフ会グループか（参加の申請をする。機能仕様書4.7.8.5）
  final bool isMeetup;

  /// 参加時の質問（オフ会グループだけ。無ければ空）
  final List<String> joinQuestions;

  /// このアカウントが出している申請の状態（無ければnull）
  final JoinStatus? applicationStatus;

  factory GroupInvitePreview.fromMap(Map<String, dynamic> map) {
    final questions = map['joinQuestions'];
    return GroupInvitePreview(
      chatRoomId: map['chatRoomId'] as String,
      name: map['name'] as String? ?? '',
      photoURL: map['photoURL'] as String?,
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 0,
      isMember: map['isMember'] == true,
      isMeetup: map['isMeetup'] == true,
      joinQuestions: questions is List ? questions.whereType<String>().toList() : const [],
      applicationStatus: JoinStatus.fromValue(map['applicationStatus']),
      capacity: (map['capacity'] as num?)?.toInt(),
      isFull: map['isFull'] == true,
    );
  }
}

/// 参加の申請の状態（データ設計書8.16）
enum JoinStatus {
  /// 承認待ち
  pending('pending'),

  /// キャンセル待ち（満員のため。申請した順に並ぶ）
  waitlisted('waitlisted'),

  /// 承認して参加した（主催チームの記録だけ）
  approved('approved'),

  /// 断られた
  declined('declined'),

  /// 答えが出ないままグループが閉じた
  closed('closed');

  const JoinStatus(this.value);

  /// Firestore・Cloud Functionsでの値
  final String value;

  /// 答えを待っている（承認待ち・キャンセル待ち）か
  bool get isOpen => this == pending || this == waitlisted;

  /// 値から作る。無い・知らない値はnull
  static JoinStatus? fromValue(Object? value) => values.where((status) => status.value == value).firstOrNull;
}

/// 参加の申請の、質問と答えの1組
typedef JoinAnswer = ({String question, String answer});

/// `chatRooms/{chatRoomId}/joinRequests/{accountId}` ドキュメント（参加の申請と答え、データ設計書8.16）
/// 主催チームの人だけが読める
class GroupJoinRequest {
  const GroupJoinRequest({
    required this.accountId,
    required this.status,
    this.answers = const [],
    this.createdAt,
    this.promotedAt,
  });

  /// 申請したアカウントのID
  final String accountId;
  final JoinStatus status;

  /// 申請した時点の質問と答え
  final List<JoinAnswer> answers;

  /// 申請日時（キャンセル待ちの順番にも使う）
  final DateTime? createdAt;

  /// キャンセル待ちから繰り上がった日時（機能仕様書4.7.8.10。繰り上がったことのある申請だけ）
  final DateTime? promotedAt;

  /// キャンセル待ちから繰り上がった承認待ちか（GRP-09の印「繰り上がり」）
  bool get isPromoted => status == JoinStatus.pending && promotedAt != null;

  /// 読めない状態の値はnull（一覧から外す）
  static GroupJoinRequest? fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = JoinStatus.fromValue(data?['status']);
    if (data == null || status == null) return null;
    final answers = data['answers'];
    return GroupJoinRequest(
      accountId: doc.id,
      status: status,
      answers: [
        if (answers is List)
          for (final item in answers.whereType<Map<String, dynamic>>())
            (question: item['question'] as String? ?? '', answer: item['answer'] as String? ?? ''),
      ],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      promotedAt: (data['promotedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// GRP-09の並び（画面設計書5.10.9）
/// 承認待ちとキャンセル待ちに分け、それぞれ申請した順（古い順）にする。答え済みの申請は出さない
({List<GroupJoinRequest> pending, List<GroupJoinRequest> waitlisted}) joinRequestSections(
  List<GroupJoinRequest> requests,
) {
  int byCreatedAt(GroupJoinRequest a, GroupJoinRequest b) {
    final aAt = a.createdAt;
    final bAt = b.createdAt;
    // 書き込み直後でサーバー時刻が未確定のものは最後
    if (aAt == null || bAt == null) return aAt == null ? (bAt == null ? 0 : 1) : -1;
    return aAt.compareTo(bAt);
  }

  return (
    pending: requests.where((request) => request.status == JoinStatus.pending).toList()..sort(byCreatedAt),
    waitlisted: requests.where((request) => request.status == JoinStatus.waitlisted).toList()..sort(byCreatedAt),
  );
}

/// `accounts/{accountId}/joinApplications/{chatRoomId}` ドキュメント（出した参加の申請、データ設計書8.16）
/// 申請した人はルームを読めないため、申請した時点のグループの情報を持つ
class JoinApplication {
  const JoinApplication({
    required this.chatRoomId,
    required this.status,
    required this.name,
    this.photoURL,
    this.updatedAt,
  });

  final String chatRoomId;
  final JoinStatus status;
  final String name;
  final String? photoURL;

  /// 状態が変わった日時
  final DateTime? updatedAt;

  /// 読めない状態の値はnull（一覧から外す）
  static JoinApplication? fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = JoinStatus.fromValue(data?['status']);
    if (data == null || status == null) return null;
    return JoinApplication(
      chatRoomId: doc.id,
      status: status,
      name: data['name'] as String? ?? '',
      photoURL: data['photoURL'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 申請を承認した結果（`respondToJoinRequest`の`result`）
enum JoinResponseResult {
  /// 参加した
  approved,

  /// 満員のため、キャンセル待ちに回した
  waitlisted,

  /// 断った
  declined;

  static JoinResponseResult fromValue(Object? value) =>
      values.where((result) => result.name == value).firstOrNull ?? approved;
}

/// `chatRooms/{chatRoomId}/members/{accountId}` ドキュメント（データ設計書8.2）
class GroupMember {
  const GroupMember({required this.accountId, this.joinedAt, this.lastReadAt, this.organizerInvitedBy});

  final String accountId;
  final DateTime? joinedAt;

  /// 最後にトークを開いた時刻
  final DateTime? lastReadAt;

  /// 主催チームに誘ったアカウントID（オフ会グループで誘われているときだけ。データ設計書8.14）
  final String? organizerInvitedBy;

  /// 主催チームに誘われているか
  bool get isInvitedToOrganizers => organizerInvitedBy != null;

  factory GroupMember.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GroupMember(
      accountId: doc.id,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
      lastReadAt: (data['lastReadAt'] as Timestamp?)?.toDate(),
      organizerInvitedBy: data['organizerInvitedBy'] as String?,
    );
  }
}

/// `chatRooms/{chatRoomId}`（グループ）のうち、種類と主催チーム（データ設計書8.14）
/// 参加者は読める。書くのはCloud Functionsのみ
class GroupRoom {
  const GroupRoom({
    required this.chatRoomId,
    this.kind = GroupKind.standard,
    this.organizerIds = const [],
    this.joinQuestions = const [],
    this.eventAt,
    this.eventPlace,
    this.participantIds = const [],
    this.capacity,
    this.attendanceDeadline,
    this.closeAfterDays = meetupDefaultCloseAfterDays,
    this.closesAt,
    this.closedAt,
    this.settlement,
    this.nextChatRoomId,
  });

  final String chatRoomId;
  final GroupKind kind;

  /// この回から作った次の回のチャットルームID（機能仕様書4.7.8.13）。まだ作っていなければnull
  final String? nextChatRoomId;

  /// 参加中のアカウントID（出欠の未回答を数えるのに使う）
  final List<String> participantIds;

  /// 定員（オフ会グループで決まっているときだけ。機能仕様書4.7.8.10）。無ければ人数の上限
  final int? capacity;

  /// 出欠の締切（オフ会グループで決まっているときだけ。機能仕様書4.7.8.9）
  final DateTime? attendanceDeadline;

  /// 主催チームのアカウントID（オフ会グループだけ。普通のグループは空）
  final List<String> organizerIds;

  /// 参加時の質問（オフ会グループだけ。機能仕様書4.7.8.5）
  final List<String> joinQuestions;

  /// 会の日時（オフ会グループで決まっているときだけ。機能仕様書4.7.8.4、データ設計書8.15）
  /// 一度決まったらnullに戻らない。期限・知らせはこれが決まってから動く
  final DateTime? eventAt;

  /// 会の場所（店名か住所。未定ならnull）
  final String? eventPlace;

  /// グループを閉じる日（会の日時の何日後か。機能仕様書4.7.8.6）。無ければ初期値の3
  final int closeAfterDays;

  /// 閉じる日時（会の日時が決まるまでnull）
  final DateTime? closesAt;

  /// 閉じる処理をした日時
  final DateTime? closedAt;

  /// 精算の設定（オフ会グループで主催チームが始めたときだけ。機能仕様書4.7.8.12、データ設計書8.20）
  final Settlement? settlement;

  /// 閉じたか（期限を過ぎたら、閉じる処理の前でも閉じたものとして扱う）
  bool isClosedAt(DateTime now) => isMeetup && isMeetupClosed(closesAt: closesAt, closedAt: closedAt, now: now);

  bool get isMeetup => kind == GroupKind.meetup;

  /// [accountId]が主催チームか
  bool isOrganizer(String accountId) => isMeetup && organizerIds.contains(accountId);

  /// 当日の定型連絡のボタンを出す間（機能仕様書4.7.8.11）。オフ会グループで会の日時が決まっていなければnull
  MeetupDay? get meetupDay => isMeetup ? meetupDayOf(eventAt) : null;

  factory GroupRoom.fromMap(String chatRoomId, Map<String, dynamic> data) {
    final kind = GroupKind.fromValue(data['groupKind']);
    final organizers = data['organizerIds'];
    final questions = data['joinQuestions'];
    final participants = data['participantIds'];
    final isMeetup = kind == GroupKind.meetup;
    return GroupRoom(
      chatRoomId: chatRoomId,
      kind: kind,
      organizerIds: isMeetup && organizers is List ? organizers.whereType<String>().toList() : const [],
      joinQuestions: isMeetup && questions is List ? questions.whereType<String>().toList() : const [],
      eventAt: kind == GroupKind.meetup ? (data['eventAt'] as Timestamp?)?.toDate() : null,
      eventPlace: kind == GroupKind.meetup ? data['eventPlace'] as String? : null,
      participantIds: participants is List ? participants.whereType<String>().toList() : const [],
      capacity: isMeetup ? (data['capacity'] as num?)?.toInt() : null,
      attendanceDeadline: isMeetup ? (data['attendanceDeadline'] as Timestamp?)?.toDate() : null,
      closeAfterDays: isMeetup ? _closeAfterDays(data['closeAfterDays']) : meetupDefaultCloseAfterDays,
      closesAt: isMeetup ? (data['closesAt'] as Timestamp?)?.toDate() : null,
      closedAt: isMeetup ? (data['closedAt'] as Timestamp?)?.toDate() : null,
      settlement: isMeetup ? Settlement.fromMap(data['settlement']) : null,
      nextChatRoomId: isMeetup ? data['nextChatRoomId'] as String? : null,
    );
  }

  /// 次の回を作れるか（機能仕様書4.7.8.13）。主催チームの人が、閉じてから記録が消えるまで（閉じる日時の30日後まで）
  /// 次の回がすでにあっても出す（全員の退会で消えていれば作り直せる。判定はサーバー）
  bool canCreateNextRound(String accountId, DateTime now) {
    final closes = closesAt;
    if (!isOrganizer(accountId) || !isClosedAt(now)) return false;
    return closes == null || now.isBefore(meetupPurgeAt(closes));
  }

  static int _closeAfterDays(Object? value) {
    return value is int && value >= 1 && value <= meetupMaxCloseAfterDays ? value : meetupDefaultCloseAfterDays;
  }
}

/// 当日の定型連絡のボタンを出す間（機能仕様書4.7.8.11）。[start]を含み、[end]を含まない
typedef MeetupDay = ({DateTime start, DateTime end});

/// 会の日時[eventAt]から、当日の定型連絡のボタンを出す間を求める（端末の時計の日付で数える）
/// 会の日付の0時から、その日の24時と会の時刻の6時間後の遅いほうまで（夜遅くに始まって日付をまたぐ会でも、始まってから6時間は出す）
/// サーバーは会の時刻の前後24時間だけ受け付ける（firestore.rules）。この間はいつもその内側に入る
MeetupDay? meetupDayOf(DateTime? eventAt) {
  if (eventAt == null) return null;
  final local = eventAt.toLocal();
  final start = DateTime(local.year, local.month, local.day);
  final endOfDay = DateTime(local.year, local.month, local.day + 1);
  final afterEvent = local.add(meetupDayAfterEvent);
  return (start: start, end: afterEvent.isAfter(endOfDay) ? afterEvent : endOfDay);
}

/// 会の時刻のあと、当日の定型連絡のボタンを出しておく長さ（機能仕様書4.7.8.11）
const meetupDayAfterEvent = Duration(hours: 6);

/// 友だちを選んで招待できるか（機能仕様書4.7.8.5）
/// 普通のグループは全員。オフ会グループは主催チームの人だけ。ルームを読めていない（[room]がnull）ときは出さない
bool canInviteFriends(GroupRoom? room, String myAccountId) {
  if (room == null) return false;
  return !room.isMeetup || room.isOrganizer(myAccountId);
}

/// 主催チームがメンバー一覧で見る、その人の申請の答え（機能仕様書4.7.8.5）
/// 承認されて入った申請で、答えがあるときだけ返す。無ければ空（何も出さない）
List<JoinAnswer> memberJoinAnswers(GroupJoinRequest? request) {
  if (request == null || request.status != JoinStatus.approved) return const [];
  return request.answers;
}

/// GRP-03のメンバー一覧の並び（機能仕様書4.7.8.2）
/// オフ会グループは主催チーム（[organizers]）とそのほか（[others]）に分け、それぞれ自分を先頭にする。
/// 普通のグループは全員を[others]に入れる
({List<GroupMember> organizers, List<GroupMember> others}) groupMemberSections(
  List<GroupMember> members, {
  required GroupRoom? room,
  required String myAccountId,
}) {
  int meFirst(GroupMember a, GroupMember b) => a.accountId == myAccountId ? -1 : (b.accountId == myAccountId ? 1 : 0);
  final isOrganizer = room?.isOrganizer ?? (String _) => false;
  final organizers = members.where((member) => isOrganizer(member.accountId)).toList()..sort(meFirst);
  final others = members.where((member) => !isOrganizer(member.accountId)).toList()..sort(meFirst);
  return (organizers: organizers, others: others);
}

/// [createdAt]のメッセージを読んだ人数（自分を除く。機能仕様書4.7.3.3）
/// 参加者のうち、そのメッセージの後にトークを開いた人を数える
int groupReadCount(List<GroupMember> members, DateTime? createdAt, {required String myAccountId}) {
  if (createdAt == null) return 0;
  return members.where((member) {
    final lastReadAt = member.lastReadAt;
    return member.accountId != myAccountId && lastReadAt != null && !lastReadAt.isBefore(createdAt);
  }).length;
}

/// 出欠の答え（機能仕様書4.7.8.9）
enum AttendanceResponse {
  /// 参加
  yes('yes'),

  /// 不参加
  no('no');

  const AttendanceResponse(this.value);

  /// Firestore・Cloud Functionsでの値
  final String value;

  /// 値から作る。無い・知らない値はnull
  static AttendanceResponse? fromValue(Object? value) =>
      values.where((response) => response.value == value).firstOrNull;
}

/// `chatRooms/{chatRoomId}/attendance/{accountId}` ドキュメント（メンバーの出欠、データ設計書8.18）
/// メンバー全員が読める。書くのはCloud Functionsのみ
class GroupAttendance {
  const GroupAttendance({required this.accountId, required this.response, this.updatedAt});

  final String accountId;
  final AttendanceResponse response;
  final DateTime? updatedAt;

  /// 読めない値はnull（一覧から外す）
  static GroupAttendance? fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final response = AttendanceResponse.fromValue(doc.data()?['response']);
    if (response == null) return null;
    return GroupAttendance(
      accountId: doc.id,
      response: response,
      updatedAt: (doc.data()?['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 出欠の集計（CHA-02の出欠の行・GRP-11）。メンバー（[participantIds]）だけを数える
class AttendanceSummary {
  const AttendanceSummary({required this.yes, required this.no, required this.unanswered});

  /// 参加と答えた人
  final List<String> yes;

  /// 不参加と答えた人
  final List<String> no;

  /// まだ答えていない人
  final List<String> unanswered;

  /// [accountId]の答え（未回答ならnull）
  AttendanceResponse? responseOf(String accountId) {
    if (yes.contains(accountId)) return AttendanceResponse.yes;
    if (no.contains(accountId)) return AttendanceResponse.no;
    return null;
  }

  /// メンバー[participantIds]と答え[answers]から作る。抜けた人の答え（残っていたとき）は数えない。
  /// それぞれ[myAccountId]を先頭にする
  factory AttendanceSummary.of(
    List<String> participantIds,
    List<GroupAttendance> answers, {
    required String myAccountId,
  }) {
    final byId = {for (final answer in answers) answer.accountId: answer.response};
    List<String> pick(AttendanceResponse? response) =>
        participantIds.where((id) => byId[id] == response).toList()
          ..sort((a, b) => a == myAccountId ? -1 : (b == myAccountId ? 1 : 0));
    return AttendanceSummary(
      yes: pick(AttendanceResponse.yes),
      no: pick(AttendanceResponse.no),
      unanswered: pick(null),
    );
  }
}

/// 出欠の締切を過ぎたか（[now]の時点）
bool isAttendanceDeadlinePassed(DateTime? deadline, DateTime now) => deadline != null && !now.isBefore(deadline);

/// 出欠の締切に選べる最も遅い日時（機能仕様書4.7.8.9）。会の日時があればそこまで、無ければ1年後まで
DateTime attendanceDeadlineLatest(DateTime? eventAt, DateTime now) {
  final yearLater = now.add(const Duration(days: 365));
  return eventAt != null && eventAt.isBefore(yearLater) ? eventAt : yearLater;
}

/// GRP-03の人数の文言に使う定員（オフ会グループで決まっているときだけ）
int? displayedCapacity(GroupRoom? room) => room != null && room.isMeetup ? room.capacity : null;
