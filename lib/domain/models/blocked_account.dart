import 'package:cloud_firestore/cloud_firestore.dart';

/// `accounts/{accountId}/blockedAccounts/{blockedAccountId}` ドキュメント。
/// 自分（accountId）がブロックした相手を表す。ブロックは自分側にのみ記録され、
/// 相手側のドキュメントは作られない（友だち関係と同じ片方向モデル）。
/// ブロックした日時は本人だけが読める`blockedAccountDates`に置く（ブロックされた側もこのドキュメントを読めるため）。
class BlockedAccount {
  const BlockedAccount({required this.blockedAccountId, required this.blockedAt});

  final String blockedAccountId;
  final DateTime blockedAt;

  /// [blockedAt]は`blockedAccountDates`の日時。無ければ、以前のドキュメントが持っている日時を使う
  factory BlockedAccount.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, {DateTime? blockedAt}) {
    final data = doc.data()!;
    return BlockedAccount(
      blockedAccountId: data['blockedAccountId'] as String? ?? doc.id,
      blockedAt: blockedAt ?? (data['blockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
