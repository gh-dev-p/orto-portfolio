import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/blocked_account.dart';
import '../../../domain/models/chat_room.dart';
import '../../services/common/firestore_paths.dart';

// ============================================================
// リポジトリ
// ============================================================

/// ブロックのリポジトリ
/// ブロック（`accounts/{accountId}/blockedAccounts`、データ設計書3.2.3）の読み書きと、ブロック関係の確認を扱う
class BlockRepository {
  BlockRepository(this._paths);

  // ---- 状態・初期化 ----

  /// Firestoreのパス（接続先）
  final FirestorePaths _paths;

  // ---- ブロック ----

  /// アカウント[accountId]がブロックした相手の一覧を、ブロックした日時の新しい順に監視する（SET-02）
  Stream<List<BlockedAccount>> watchBlockedAccounts(String accountId) {
    return _paths.blockedAccounts(accountId).snapshots().asyncMap((snap) async {
      final dates = await _paths.blockedAccountDates(accountId).get();
      final dateById = {for (final doc in dates.docs) doc.id: (doc.data()['blockedAt'] as Timestamp?)?.toDate()};
      return snap.docs.map((doc) => BlockedAccount.fromFirestore(doc, blockedAt: dateById[doc.id])).toList()
        ..sort((a, b) => b.blockedAt.compareTo(a.blockedAt));
    });
  }

  /// 相手[targetAccountId]をブロックする
  /// ブロックの記録と、双方向の友だち関係の解除を1回のバッチで行う（相手側の友だちの削除は、firestore.rulesが`existsAfter`でこのバッチ内のブロックの記録を確かめて許可する）
  ///
  /// 相手とのトークが自分の一覧（chatList）にある場合は、未読数（未読のリアクションを含む）を0に戻す（ブロック後はそのルームが一覧から見えなくなるため、未読バッジだけが残らないように）
  /// あわせてブロックした日時（`blockedAt`）を書き、解除後にブロック前のやり取りだけでトークリクエストに出さないようにする（`partitionChatRooms`）
  Future<void> blockAccount({required String accountId, required String targetAccountId}) async {
    final batch = _paths.batch();
    batch.set(_paths.blockedAccounts(accountId).doc(targetAccountId), {'blockedAccountId': targetAccountId});
    batch.set(_paths.blockedAccountDates(accountId).doc(targetAccountId), {
      'blockedAccountId': targetAccountId,
      'blockedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(_paths.friends(accountId).doc(targetAccountId));
    batch.delete(_paths.friends(targetAccountId).doc(accountId));
    // 相手から届いている友だち申請も消す（機能仕様書4.3.4。ルールはこのバッチのブロックの記録を見て許可する）
    batch.delete(_paths.friendRequests(accountId).doc(targetAccountId));

    final chatListRef = _paths.chatList(accountId).doc(buildChatRoomId(accountId, targetAccountId));
    final chatListDoc = await chatListRef.get();
    if (chatListDoc.exists) {
      batch.update(chatListRef, {
        'unreadCount': 0,
        'unreadReactions': FieldValue.delete(),
        'blockedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// 相手[targetAccountId]のブロックを解除する
  /// 元の友だち関係には戻らず、相手とは新しく友だち追加する扱いになる
  /// トークは一覧に出ないまま（解除後に相手から新しいメッセージが届いたら、トークリクエストに出る）
  Future<void> unblockAccount({required String accountId, required String targetAccountId}) {
    final batch = _paths.batch();
    batch.delete(_paths.blockedAccounts(accountId).doc(targetAccountId));
    batch.delete(_paths.blockedAccountDates(accountId).doc(targetAccountId));
    return batch.commit();
  }

  // ---- ブロック関係の確認 ----

  /// [peerAccountId]が[accountId]をブロックしているか
  /// ブロックされた側は、firestore.rulesの「ブロック対象のアカウントの持ち主にだけ、自分宛てのブロックのgetを許可する」ルールで確かめられる（相手のブロックリスト自体は読めない）
  ///
  /// 表示上の除外（検索結果・トーク一覧）に使うだけで、実際の拒否はfirestore.rulesがサーバー側で行う。そのため取得に失敗したら「ブロックされていない」として扱い、一覧全体が取得エラーになるのを避ける
  Future<bool> isBlockedBy({required String accountId, required String peerAccountId}) async {
    try {
      final doc = await _paths.blockedAccounts(peerAccountId).doc(accountId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// 2つのアカウントの間に、どちらか向きのブロック関係があるか
  /// ID検索・QR読み取りの除外に使う（失敗時の扱いは[isBlockedBy]と同じ）
  Future<bool> isBlockedEitherWay(String accountIdA, String accountIdB) async {
    try {
      final results = await Future.wait([
        _paths.blockedAccounts(accountIdA).doc(accountIdB).get(),
        _paths.blockedAccounts(accountIdB).doc(accountIdA).get(),
      ]);
      return results.any((doc) => doc.exists);
    } catch (_) {
      return false;
    }
  }
}
