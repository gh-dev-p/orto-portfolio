import 'package:cloud_firestore/cloud_firestore.dart';

/// データ設計書 2章「コレクション構成一覧」に対応するコレクション参照ヘルパー。
/// 接続先の[FirebaseFirestore]は外から渡す（service_providers.dart。テストでは差し替えられる）。
class FirestorePaths {
  const FirestorePaths(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> user(String uid) => _db.collection('users').doc(uid);

  /// ユーザが保有するアカウント（データ設計書3.1.1）。本人しか読めない。
  CollectionReference<Map<String, dynamic>> ownedAccounts(String uid) => user(uid).collection('ownedAccounts');

  /// 送信の回数制限のカウンター（データ設計書3.1.2）。本人しか読めない。
  DocumentReference<Map<String, dynamic>> sendCounter(String uid) =>
      user(uid).collection('sendCounters').doc('current');

  CollectionReference<Map<String, dynamic>> get accounts => _db.collection('accounts');

  DocumentReference<Map<String, dynamic>> account(String accountId) => accounts.doc(accountId);

  CollectionReference<Map<String, dynamic>> friends(String accountId) => account(accountId).collection('friends');

  /// 届いた友だち申請（データ設計書3.2.5）。保有ユーザが読める
  CollectionReference<Map<String, dynamic>> friendRequests(String accountId) =>
      account(accountId).collection('friendRequests');

  /// 送った友だち申請（データ設計書3.2.6）。保有ユーザが読める
  CollectionReference<Map<String, dynamic>> sentFriendRequests(String accountId) =>
      account(accountId).collection('sentFriendRequests');

  CollectionReference<Map<String, dynamic>> blockedAccounts(String accountId) =>
      account(accountId).collection('blockedAccounts');

  CollectionReference<Map<String, dynamic>> blockedAccountDates(String accountId) =>
      account(accountId).collection('blockedAccountDates');

  CollectionReference<Map<String, dynamic>> fcmTokens(String accountId) => account(accountId).collection('fcmTokens');

  /// アカウントから見たトーク一覧（データ設計書3.2.4）。
  CollectionReference<Map<String, dynamic>> chatList(String accountId) => account(accountId).collection('chatList');

  CollectionReference<Map<String, dynamic>> get chatRooms => _db.collection('chatRooms');

  DocumentReference<Map<String, dynamic>> chatRoom(String chatRoomId) => chatRooms.doc(chatRoomId);

  CollectionReference<Map<String, dynamic>> messages(String chatRoomId) => chatRoom(chatRoomId).collection('messages');

  /// `accounts/{accountId}/groupRequests`（届いているグループへの招待）
  CollectionReference<Map<String, dynamic>> groupRequests(String accountId) =>
      account(accountId).collection('groupRequests');

  /// `accounts/{accountId}/joinApplications`（オフ会グループに出した参加の申請、データ設計書8.16）
  CollectionReference<Map<String, dynamic>> joinApplications(String accountId) =>
      account(accountId).collection('joinApplications');

  /// `chatRooms/{chatRoomId}/joinRequests`（参加の申請と答え。主催チームだけが読める）
  CollectionReference<Map<String, dynamic>> chatRoomJoinRequests(String chatRoomId) =>
      chatRoom(chatRoomId).collection('joinRequests');

  /// `chatRooms/{chatRoomId}/attendance`（オフ会グループの出欠。メンバー全員が読める）
  CollectionReference<Map<String, dynamic>> chatRoomAttendance(String chatRoomId) =>
      chatRoom(chatRoomId).collection('attendance');

  /// `chatRooms/{chatRoomId}/settlementShares`（オフ会グループの精算の一人ひとりの額と払った記録）
  /// 主催チームの人は全員の分、そのほかのメンバーは自分の分だけ読める
  CollectionReference<Map<String, dynamic>> chatRoomSettlementShares(String chatRoomId) =>
      chatRoom(chatRoomId).collection('settlementShares');

  /// `chatRooms/{chatRoomId}/members`（グループの参加者ごとの情報）
  CollectionReference<Map<String, dynamic>> chatRoomMembers(String chatRoomId) =>
      chatRoom(chatRoomId).collection('members');

  /// `chatRooms/{chatRoomId}/albums`（トークのアルバム、データ設計書3.13）
  CollectionReference<Map<String, dynamic>> albums(String chatRoomId) => chatRoom(chatRoomId).collection('albums');

  /// `chatRooms/{chatRoomId}/albums/{albumId}/items`（アルバムの画像・動画）
  CollectionReference<Map<String, dynamic>> albumItems(String chatRoomId, String albumId) =>
      albums(chatRoomId).doc(albumId).collection('items');

  /// 通報。アプリからは作成のみ
  CollectionReference<Map<String, dynamic>> get reports => _db.collection('reports');

  /// 動かせる最低のアプリのバージョン（データ設計書3.7）。ログイン前でも読める
  DocumentReference<Map<String, dynamic>> get appConfigVersion => _db.collection('appConfig').doc('version');

  /// スタンプのパック（データ設計書3.9）
  CollectionReference<Map<String, dynamic>> get stickerPacks => _db.collection('stickerPacks');

  /// バッチ書き込みの起点。呼び出し側が[FirebaseFirestore]を直接参照しなくて済むように、
  /// 他のパス解決と同じくここに集約する。
  WriteBatch batch() => _db.batch();
}
