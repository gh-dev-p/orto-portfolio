import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../domain/models/friend_request.dart';
import '../../services/common/cloud_functions_service.dart';
import '../../services/common/firestore_paths.dart';

// ============================================================
// リポジトリ
// ============================================================

/// 友だち申請のリポジトリ
/// 送る・承認する・断るはCloud Functionsで行い、アプリは届いた申請・送った申請を読むだけ（データ設計書3.2.5・3.2.6）
///
/// 機能仕様書：4.3.8 / データ設計書：3.2.5・3.2.6
class FriendRequestRepository {
  FriendRequestRepository(this._paths, this._functions);

  // ---- 状態・初期化 ----

  /// Firestoreのパス（接続先）
  final FirestorePaths _paths;

  /// Cloud Functionsのサービス
  final CloudFunctionsService _functions;

  // ---- 読み取り ----

  /// アカウント[accountId]に届いた申請を、新しい順に監視する（期限切れも含む。表示する側で除く）
  Stream<List<FriendRequest>> watchReceived(String accountId) {
    return _paths
        .friendRequests(accountId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(FriendRequest.fromFirestore).toList());
  }

  /// アカウント[accountId]が送った申請を監視する（期限切れも含む。表示する側で除く）
  Stream<List<SentFriendRequest>> watchSent(String accountId) {
    return _paths
        .sentFriendRequests(accountId)
        .snapshots()
        .map((snap) => snap.docs.map(SentFriendRequest.fromFirestore).toList());
  }

  // ---- 操作 ----

  /// グループ[chatRoomId]のメンバー[targetAccountId]に申請を送る（機能仕様書4.3.8.1）
  /// 相手から申請が届いていて、送る代わりに承認になったらtrue
  Future<bool> send({required String accountId, required String chatRoomId, required String targetAccountId}) async {
    final result = await _run(
      () => _functions.callForResult('sendFriendRequest', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'targetAccountId': targetAccountId,
      }),
    );
    return result['accepted'] == true;
  }

  /// [senderAccountId]からの申請を承認する（[accept]がtrue）・断る（機能仕様書4.3.8.2）
  Future<void> respond({required String accountId, required String senderAccountId, required bool accept}) {
    return _run(
      () => _functions.call('respondToFriendRequest', {
        'accountId': accountId,
        'senderAccountId': senderAccountId,
        'accept': accept,
      }),
    );
  }

  // ---- 内部処理 ----

  /// Cloud Functionsのエラーを[FriendRequestException]に変える
  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseFunctionsException catch (error) {
      throw FriendRequestException(FriendRequestFailure.fromValue(error.message));
    } on FirebaseException {
      throw const FriendRequestException(FriendRequestFailure.unknown);
    }
  }
}
