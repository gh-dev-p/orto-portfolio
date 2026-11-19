import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/friend.dart';
import '../../services/common/cloud_functions_service.dart';
import '../../services/common/firestore_paths.dart';

// ============================================================
// リポジトリ
// ============================================================

/// 友だちのリポジトリ
/// 友だち（`accounts/{accountId}/friends`、データ設計書3.2.1）を読み書きする（友だち関係は片方向で、追加した側のアカウントの下にだけ作る。機能仕様書4.3.1）
class FriendRepository {
  FriendRepository(this._paths, this._functions);

  // ---- 状態・初期化 ----

  /// Firestoreのパス（接続先）
  final FirestorePaths _paths;

  /// Cloud Functionsのサービス
  final CloudFunctionsService _functions;

  // ---- 友だち ----

  /// アカウント[accountId]が追加した友だちの一覧を、新しい順に監視する（機能仕様書4.3.2）
  Stream<List<Friend>> watchFriends(String accountId) {
    return _paths
        .friends(accountId)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Friend.fromFirestore).toList());
  }

  /// [peerAccountId]を[myAccountId]の友だちに追加する（機能仕様書4.3.1：片方向）
  /// ルームは作らない（最初の送信時に作る。データ設計書3.3）
  /// 相手のマイQRコード・招待リンクから来たときは、その招待キー[inviteKey]を添える（IDによる友だち追加を許可していない相手は、
  /// これが無いとFirestoreのルールで断られる。機能仕様書4.3.1.4）
  Future<void> addFriend({required String myAccountId, required String peerAccountId, String? inviteKey}) {
    return _paths.friends(myAccountId).doc(peerAccountId).set({
      'friendAccountId': peerAccountId,
      'addedAt': FieldValue.serverTimestamp(),
      'inviteKey': ?inviteKey,
    });
  }

  /// 自分のアカウント[accountId]の招待キーを取る（無ければサーバーが作る。データ設計書3.14）
  /// マイQRコード・招待リンクに入れる。失敗したら[FirebaseFunctionsException]等を投げる
  Future<String> fetchInviteKey(String accountId) async {
    final result = await _functions.callForResult('getFriendInviteKey', {'accountId': accountId});
    final key = result['key'];
    if (key is! String || key.isEmpty) throw StateError('invite key missing');
    return key;
  }

  /// 友だちのメモを設定・解除する（機能仕様書4.3.7・データ設計書3.2.1）
  /// 空文字なら未設定として、ピン留めごと項目を消す
  Future<void> updateFriendMemo({
    required String accountId,
    required String friendAccountId,
    required String memo,
  }) {
    final trimmed = memo.trim();
    return _paths.friends(accountId).doc(friendAccountId).update({
      'memo': trimmed.isEmpty ? FieldValue.delete() : trimmed,
      if (trimmed.isEmpty) 'memoPinned': FieldValue.delete(),
    });
  }

  /// 友だちのメモのピン留めを切り替える（機能仕様書4.3.7）
  Future<void> updateFriendMemoPinned({
    required String accountId,
    required String friendAccountId,
    required bool pinned,
  }) {
    return _paths.friends(accountId).doc(friendAccountId).update({'memoPinned': pinned});
  }

  /// 友だちのニックネームを設定・解除する（機能仕様書4.3.3・データ設計書3.2.1）
  /// 空文字なら未設定として、項目自体を消す
  Future<void> updateFriendNickname({
    required String accountId,
    required String friendAccountId,
    required String? nickname,
  }) {
    final trimmed = nickname?.trim();
    return _paths.friends(accountId).doc(friendAccountId).update({
      'nickname': trimmed == null || trimmed.isEmpty ? FieldValue.delete() : trimmed,
    });
  }
}
