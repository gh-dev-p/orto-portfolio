import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_values.dart';
import 'group.dart';
import 'meetup_lifecycle.dart';
import 'message.dart';

class LastMessagePreview {
  const LastMessagePreview({
    required this.messageId,
    this.type = MessageType.text,
    required this.text,
    required this.senderId,
    this.createdAt,
    this.meetupStatus,
    this.systemType,
    this.targetAccountIds = const [],
    this.hoursLeft,
  });

  final String messageId;

  /// 画像メッセージは[text]を持たず、一覧には「画像」と表示する。
  final MessageType type;
  final String text;
  final String senderId;
  final DateTime? createdAt;

  /// 当日の定型連絡の中身（機能仕様書4.7.8.11）。[MessageType.meetupStatus]以外はnull
  final MeetupStatus? meetupStatus;

  /// システムメッセージ（グループのみ）の種類。[MessageType.system]以外はnull
  final String? systemType;

  /// システムメッセージの対象のアカウントID（参加した人・退会した人など）
  final List<String> targetAccountIds;

  /// 閉じる前の知らせ（`closing_soon`）の残り時間（24か1）
  final int? hoursLeft;

  factory LastMessagePreview.fromMap(Map<String, dynamic> map) => LastMessagePreview(
    messageId: stringOrNull(map['messageId']) ?? '',
    type: MessageType.fromValue(stringOrNull(map['type'])),
    text: stringOrNull(map['text']) ?? '',
    senderId: stringOrNull(map['senderId']) ?? '',
    createdAt: dateOrNull(map['createdAt']),
    meetupStatus: MeetupStatus.fromValue(stringOrNull(map['meetupStatus'])),
    systemType: stringOrNull(map['systemType']),
    targetAccountIds: stringList(map['targetAccountIds']),
    hoursLeft: intOrNull(map['hoursLeft']),
  );
}

/// `accounts/{accountId}/chatList/{chatRoomId}` ドキュメント（トーク一覧の1行）。
/// 自分の分はアプリが、相手の分はCloud Functionsが書く。データ設計書 3.2.4 参照。
class ChatListEntry {
  const ChatListEntry({
    required this.chatRoomId,
    required this.peerAccountId,
    this.isGroup = false,
    this.groupKind = GroupKind.standard,
    this.name,
    this.photoURL,
    this.memberCount = 0,
    this.closesAt,
    this.closedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.latestUnreadReactionAt,
    this.blockedAt,
  });

  final String chatRoomId;

  /// 1対1の相手のアカウントID（グループはnull）
  final String? peerAccountId;

  /// グループの行か（データ設計書8.2）
  final bool isGroup;

  /// グループの種類（データ設計書8.14。1対1は[GroupKind.standard]）
  final GroupKind groupKind;

  /// オフ会グループの行か
  bool get isMeetup => isGroup && groupKind == GroupKind.meetup;

  /// グループ名（1対1はnull）
  final String? name;

  /// グループの画像のURL
  final String? photoURL;

  /// グループの人数
  final int memberCount;

  /// オフ会グループの閉じる日時（会の日時が決まるまでnull。データ設計書8.17）
  final DateTime? closesAt;

  /// オフ会グループを閉じた日時（閉じる処理の印）
  final DateTime? closedAt;

  /// 閉じたオフ会グループか（期限を過ぎたら、閉じる処理の前でも閉じたものとして扱う）
  bool isClosedAt(DateTime now) => isMeetup && isMeetupClosed(closesAt: closesAt, closedAt: closedAt, now: now);

  final LastMessagePreview? lastMessage;
  final DateTime? lastMessageAt;

  /// 未読の数（トーク一覧・アカウント一覧等のバッジに出す数）
  /// 未読のメッセージ（`unreadCount`）と、未読のリアクション（`unreadReactions`の件数）の合計
  final int unreadCount;

  /// 未読のリアクションのうち、最も新しいものが付いた日時
  /// 未読のリアクションが無ければnull。最新メッセージより新しければ、トーク一覧のプレビューを「リアクションされました」にする
  final DateTime? latestUnreadReactionAt;

  /// トーク一覧のプレビューを、最新メッセージの代わりに「リアクションされました」にするか
  /// 未読のリアクションが、最新メッセージより後に付いたとき
  bool get showsReactionPreview {
    final reactedAt = latestUnreadReactionAt;
    if (reactedAt == null) return false;
    final messageAt = lastMessageAt;
    return messageAt == null || reactedAt.isAfter(messageAt);
  }

  /// このアカウントが相手を最後にブロックした日時（ブロックしたことが無ければnull）。
  /// ブロック解除後に、ブロック前のやり取りだけでトークリクエストに出さないために使う（chat_list_sections.dartの`partitionChatRooms`）。
  final DateTime? blockedAt;

  factory ChatListEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final lastMessageMap = data['lastMessage'];
    final isGroup = data['type'] == 'group';
    return ChatListEntry(
      chatRoomId: doc.id,
      peerAccountId: isGroup ? null : stringOrNull(data['peerAccountId']) ?? '',
      isGroup: isGroup,
      groupKind: isGroup ? GroupKind.fromValue(data['groupKind']) : GroupKind.standard,
      name: stringOrNull(data['name']),
      photoURL: stringOrNull(data['photoURL']),
      memberCount: intOrNull(data['memberCount']) ?? 0,
      closesAt: isGroup ? dateOrNull(data['closesAt']) : null,
      closedAt: isGroup ? dateOrNull(data['closedAt']) : null,
      lastMessage: lastMessageMap is Map<String, dynamic> ? LastMessagePreview.fromMap(lastMessageMap) : null,
      lastMessageAt: dateOrNull(data['lastMessageAt']),
      unreadCount: (intOrNull(data['unreadCount']) ?? 0) + unreadReactionCount(data),
      latestUnreadReactionAt: unreadReactionLatestAt(data),
      blockedAt: dateOrNull(data['blockedAt']),
    );
  }
}

/// `chatList`ドキュメントのデータにある、未読のリアクションの件数（データ設計書3.2.4）
/// `unreadReactions`は「メッセージID~リアクションした相手のアカウントID」をキー、付いた日時を値とするmapで、Cloud Functionsが書く
int unreadReactionCount(Map<String, dynamic>? data) {
  final reactions = data?['unreadReactions'];
  return reactions is Map ? reactions.length : 0;
}

/// `chatList`ドキュメントのデータにある、未読のリアクションのうち最も新しいものが付いた日時
/// 未読のリアクションが無い・日時が書かれていない（サーバー時刻の確定前等）ときはnull
DateTime? unreadReactionLatestAt(Map<String, dynamic>? data) {
  DateTime? latest;
  final reactions = data?['unreadReactions'];
  for (final value in reactions is Map ? reactions.values : const []) {
    if (value is! Timestamp) continue;
    final at = value.toDate();
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest;
}

/// グループのチャットルームIDか（データ設計書8.1）
/// 1対1のIDは2つのaccountIdを`~`で連結したもの、グループは`~`を含まない自動採番のID
bool isGroupChatRoomId(String chatRoomId) => !chatRoomId.contains('~');

/// 2つの accountId から決定的な chatRoomId を導出する（データ設計書 4章）。
/// 区切り文字はaccountIdに使えない`~`とする。`_`等のaccountIdに使える文字だと、
/// `ab_cd`+`ef`と`ab`+`cd_ef`のように別のペアが同じIDになってしまう。
String buildChatRoomId(String accountIdA, String accountIdB) {
  final sorted = [accountIdA, accountIdB]..sort();
  return '${sorted[0]}~${sorted[1]}';
}
