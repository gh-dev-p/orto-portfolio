import 'chat_room.dart';
import 'group.dart';

// ============================================================
// ドメインモデル
// ============================================================

/// プッシュ通知のタップで開くトーク（機能仕様書4.4.6.1）
/// 通知のデータ（Cloud Functionsの`onMessageCreated`・`onMessageReacted`が付ける）から作る
class NotificationTarget {
  const NotificationTarget({
    required this.accountId,
    required this.chatRoomId,
    this.peerAccountId,
    this.isReaction = false,
    this.isGroupInvite = false,
    this.isOrganizerInvite = false,
    this.isJoinRequest = false,
    this.joinResult,
    this.groupName,
    this.isFriendRequest = false,
    this.isAnnouncement = false,
    this.isWaitlistPromoted = false,
    this.isAttendanceReminder = false,
    this.isSettlementReminder = false,
    this.closingHoursLeft,
  });

  /// 通知先（受信した側）のアカウントID
  final String accountId;

  /// トークのチャットルームID
  final String chatRoomId;

  /// 送信した（リアクションした）相手のアカウントID（グループのトークはnull）
  final String? peerAccountId;

  /// リアクションの通知か（通知のデータの`type`が`reaction`）
  /// アプリを開いているときのバナーの文言を変えるために使う。開く先のトークには関係しないため、[==]では比べない
  final bool isReaction;

  /// グループへの招待の通知か（通知のデータの`type`が`group_invite`）
  /// トークではなく、トーク一覧の「グループへの招待」を開く（機能仕様書4.7.2.1）
  final bool isGroupInvite;

  /// 主催チームへの誘いの通知か（通知のデータの`type`が`organizer_invite`、機能仕様書4.7.8.2）
  /// 開く先はグループのトーク（誘いのカードが出る）。バナーの文言を変えるために使い、[==]では比べない
  final bool isOrganizerInvite;

  /// オフ会グループの参加の申請が届いた通知か（主催チーム宛て、`type`が`join_request`、機能仕様書4.7.8.5）
  /// 開く先はグループのトークと、その上のGRP-09（参加の申請）
  final bool isJoinRequest;

  /// 参加の申請の結果の通知なら、その結果（申請した人宛て、`type`が`join_result`）
  /// 承認ならグループのトーク、それ以外はトーク一覧の「参加の申請」を開く。
  /// [JoinStatus.pending]はキャンセル待ちから繰り上がった知らせ（機能仕様書4.7.8.10）
  final JoinStatus? joinResult;

  /// キャンセル待ちから繰り上がった人がいる通知か（主催チーム宛て、`type`が`join_request`で`promoted`が`"true"`）
  /// 開く先は[isJoinRequest]と同じ。バナーの文言を変えるために使い、[==]では比べない
  final bool isWaitlistPromoted;

  /// 出欠の催促の通知か（`type`が`attendance_reminder`、機能仕様書4.7.8.9）
  /// 開く先はグループのトーク。バナーの文言を変えるために使い、[==]では比べない
  final bool isAttendanceReminder;

  /// 精算の未払いの催促の通知か（`type`が`settlement_reminder`、機能仕様書4.7.8.12）
  /// 開く先はグループのトーク。バナーの文言を変えるために使い、[==]では比べない
  final bool isSettlementReminder;

  /// 申請の結果の通知のグループ名（アプリ内バナーの文言に使う）
  final String? groupName;

  /// トーク一覧の「参加の申請」を開く通知か（承認されなかった・キャンセル待ち・閉じた）
  bool get opensJoinApplications => joinResult != null && joinResult != JoinStatus.approved;

  /// 友だち申請の通知か（通知のデータの`type`が`friend_request`、機能仕様書4.3.8.2）
  /// トークではなく、FRI-01の「友だち申請」を開く。[chatRoomId]は申請を送ったグループ（開く先には使わない）
  final bool isFriendRequest;

  /// オフ会グループのお知らせの通知か（通知のデータの`type`が`announcement`、機能仕様書4.7.8.4）
  /// 開く先はグループのトーク。バナーの文言を変えるために使い、[==]では比べない
  final bool isAnnouncement;

  /// オフ会グループの閉じる前の知らせなら、残り時間（24か1。`type`が`group_closing`、機能仕様書4.7.8.7）
  /// 開く先はグループのトーク。バナーの文言を変えるために使い、[==]では比べない
  final int? closingHoursLeft;

  /// 通知のデータから作る
  /// 必要な値が揃っていない（古いサーバーからの通知等）場合はnull
  static NotificationTarget? fromData(Map<String, dynamic> data) {
    final accountId = data['accountId'];
    final chatRoomId = data['chatRoomId'];
    final peerAccountId = data['peerAccountId'];
    if (accountId is! String || chatRoomId is! String) return null;
    if (accountId.isEmpty || chatRoomId.isEmpty) return null;
    final isGroup = isGroupChatRoomId(chatRoomId);
    if (!isGroup && (peerAccountId is! String || peerAccountId.isEmpty)) return null;
    return NotificationTarget(
      accountId: accountId,
      chatRoomId: chatRoomId,
      peerAccountId: isGroup ? null : peerAccountId as String,
      isReaction: data['type'] == 'reaction',
      isGroupInvite: data['type'] == 'group_invite',
      isOrganizerInvite: data['type'] == 'organizer_invite',
      isJoinRequest: data['type'] == 'join_request',
      joinResult: data['type'] == 'join_result' ? JoinStatus.fromValue(data['status']) : null,
      groupName: data['groupName'] is String ? data['groupName'] as String : null,
      isFriendRequest: data['type'] == 'friend_request',
      isAnnouncement: data['type'] == 'announcement',
      isWaitlistPromoted: data['type'] == 'join_request' && data['promoted'] == 'true',
      isAttendanceReminder: data['type'] == 'attendance_reminder',
      isSettlementReminder: data['type'] == 'settlement_reminder',
      closingHoursLeft: data['type'] == 'group_closing' ? int.tryParse('${data['hoursLeft']}') : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationTarget &&
      other.accountId == accountId &&
      other.chatRoomId == chatRoomId &&
      other.peerAccountId == peerAccountId &&
      other.isGroupInvite == isGroupInvite &&
      other.isJoinRequest == isJoinRequest &&
      other.opensJoinApplications == opensJoinApplications &&
      other.isFriendRequest == isFriendRequest;

  @override
  int get hashCode => Object.hash(
    accountId,
    chatRoomId,
    peerAccountId,
    isGroupInvite,
    isJoinRequest,
    opensJoinApplications,
    isFriendRequest,
  );
}
