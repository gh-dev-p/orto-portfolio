import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// ドメインモデル
// ============================================================

/// `accounts/{accountId}/friendRequests/{senderAccountId}` ドキュメント（届いた友だち申請、データ設計書3.2.5）
/// 作るのはCloud Functionsだけで、アプリは読むだけ
class FriendRequest {
  const FriendRequest({
    required this.senderAccountId,
    required this.chatRoomId,
    required this.groupName,
    this.createdAt,
    this.expiresAt,
  });

  /// 申請してきた相手のアカウントID
  final String senderAccountId;

  /// 申請を送ったグループのチャットルームID
  final String chatRoomId;

  /// 送った時点のグループ名（「「{グループ名}」から」に出す）
  final String groupName;

  final DateTime? createdAt;

  /// 消す日時（普通のグループは送ってから30日）。オフ会グループはnull
  final DateTime? expiresAt;

  /// [now]の時点で期限内か（TTLの削除は遅れるため、期限を過ぎたものは無いものとして扱う）
  bool isLiveAt(DateTime now) => expiresAt == null || expiresAt!.isAfter(now);

  factory FriendRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FriendRequest(
      senderAccountId: doc.id,
      chatRoomId: data['chatRoomId'] as String? ?? '',
      groupName: data['groupName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// `accounts/{accountId}/sentFriendRequests/{receiverAccountId}` ドキュメント（送った友だち申請、データ設計書3.2.6）
/// PRO-01の「申請中」の判定に使う。相手が断っても消えない
class SentFriendRequest {
  const SentFriendRequest({required this.receiverAccountId, this.expiresAt});

  /// 申請した相手のアカウントID
  final String receiverAccountId;

  /// 消す日時（普通のグループは送ってから30日）。オフ会グループはnull
  final DateTime? expiresAt;

  /// [now]の時点で期限内か
  bool isLiveAt(DateTime now) => expiresAt == null || expiresAt!.isAfter(now);

  factory SentFriendRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SentFriendRequest(receiverAccountId: doc.id, expiresAt: (data['expiresAt'] as Timestamp?)?.toDate());
  }
}

/// 友だち申請の失敗の理由（Cloud Functionsのエラーの`message`、データ設計書3.2.6）
enum FriendRequestFailure {
  readOnly('read-only'),

  /// 自分か相手が、もうグループにいない（グループが無い）
  notMember('not-member'),

  /// 相手が退会済み
  accountNotFound('account-not-found'),

  /// すでに友だちに入れている
  alreadyFriend('already-friend'),

  /// 申請が無い・期限切れ
  requestNotFound('request-not-found'),

  /// 相手が退会済み・ブロック関係にある（申請は消える）
  requestInvalid('request-invalid'),

  /// オフ会グループが閉じていて、新しい申請を送れない（機能仕様書4.7.8.6）
  groupClosed('group-closed'),
  unknown('');

  const FriendRequestFailure(this.value);

  final String value;

  static FriendRequestFailure fromValue(String? value) =>
      values.firstWhere((failure) => failure.value == value, orElse: () => unknown);
}

/// 友だち申請の失敗
class FriendRequestException implements Exception {
  const FriendRequestException(this.failure);

  final FriendRequestFailure failure;
}
