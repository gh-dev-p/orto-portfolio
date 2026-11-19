import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_room.dart';

/// `accounts/{accountId}/friends/{friendAccountId}` ドキュメント。
/// データ設計書 3.2.1 参照。片方向の友達関係（追加した側にのみ作成される）。
/// 相手とのチャットルームIDは2人のaccountIdから決まるため持たない（[buildChatRoomId]）。
class Friend {
  const Friend({
    required this.friendAccountId,
    required this.addedAt,
    this.nickname,
    this.memo,
    this.memoPinned = false,
  });

  final String friendAccountId;
  final DateTime addedAt;

  /// 自分だけに見えるニックネーム（表示名の上書き）。未設定ならnull（機能仕様書4.3.3）。
  final String? nickname;

  /// 自分だけに見えるメモ。未設定ならnull（機能仕様書4.3.7）。
  final String? memo;

  /// [memo]をトーク（CHA-02）にピン留めしているか。
  final bool memoPinned;

  factory Friend.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Friend(
      friendAccountId: data['friendAccountId'] as String? ?? doc.id,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nickname: data['nickname'] as String?,
      memo: data['memo'] as String?,
      memoPinned: data['memoPinned'] as bool? ?? false,
    );
  }
}
