import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../domain/models/announcement.dart';
import '../../../domain/models/chat_room.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/settlement.dart';
import '../../services/common/cloud_functions_service.dart';
import '../../services/common/firestore_paths.dart';
import '../../services/profile/profile_storage_service.dart';

// ============================================================
// リポジトリ
// ============================================================

/// グループのリポジトリ
/// 参加者の増減・情報の変更はすべてCloud Functionsで行い、アプリは届いている招待を読むだけ（データ設計書8.1）
///
/// 機能仕様書：4.7 / データ設計書：8章
class GroupRepository {
  GroupRepository(this._paths, this._functions, this._storage);

  // ---- 状態・初期化 ----

  /// Firestoreのパス（接続先）
  final FirestorePaths _paths;

  /// Cloud Functionsのサービス
  final CloudFunctionsService _functions;

  /// グループの画像を置くサービス
  final ProfileStorageService _storage;

  // ---- 参加中のグループ ----

  /// アカウント[accountId]のこのグループの`chatList`の行を監視する（機能仕様書4.7.4.2）
  /// 退会すると行が消えるため、サーバーで確定して行が無ければnullを流す（端末のキャッシュに無いだけのときは流さない）
  Stream<ChatListEntry?> watchEntry({required String accountId, required String chatRoomId}) {
    return _paths
        .chatList(accountId)
        .doc(chatRoomId)
        .snapshots(includeMetadataChanges: true)
        .where((doc) => doc.exists || !doc.metadata.isFromCache)
        .map((doc) => doc.exists ? ChatListEntry.fromFirestore(doc) : null);
  }

  /// 参加者を取得する（既読の人数・GRP-03に使う。データ設計書8.6）
  /// 1通ごとの更新が全員に届かないよう、監視せず必要なときに読む
  Future<List<GroupMember>> fetchMembers(String chatRoomId) async {
    final snap = await _paths.chatRoomMembers(chatRoomId).get();
    return snap.docs.map(GroupMember.fromFirestore).toList();
  }

  /// グループの種類と主催チームを監視する（機能仕様書4.7.8、データ設計書8.14）
  /// 参加者・主催チームが変わったときだけ流れる（メッセージの送信では変わらない）。読めない（退会後など）ときはnull
  Stream<GroupRoom?> watchRoom(String chatRoomId) {
    return _paths
        .chatRoom(chatRoomId)
        .snapshots()
        .map((doc) => doc.exists ? GroupRoom.fromMap(chatRoomId, doc.data()!) : null)
        .handleError((Object _) {}, test: (error) => error is FirebaseException && error.code == 'permission-denied');
  }

  /// 自分の`members`の1件を監視する（主催チームへの誘いのカード、機能仕様書4.7.8.2）
  /// 1件だけなので、ほかの参加者の既読の更新は届かない
  Stream<GroupMember?> watchMember({required String chatRoomId, required String accountId}) {
    return _paths
        .chatRoomMembers(chatRoomId)
        .doc(accountId)
        .snapshots()
        .map((doc) => doc.exists ? GroupMember.fromFirestore(doc) : null)
        .handleError((Object _) {}, test: (error) => error is FirebaseException && error.code == 'permission-denied');
  }

  /// 主催チームに誘う（機能仕様書4.7.8.2）
  Future<void> inviteToOrganizers({
    required String accountId,
    required String chatRoomId,
    required String targetAccountId,
  }) {
    return _run(
      () => _functions.call('inviteToOrganizers', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'targetAccountId': targetAccountId,
      }),
    );
  }

  /// 主催チームへの誘いに答える（[accept]がfalseなら断る）
  Future<void> respondToOrganizerInvite({required String accountId, required String chatRoomId, required bool accept}) {
    return _run(
      () => _functions.call('respondToOrganizerInvite', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'accept': accept,
      }),
    );
  }

  /// 主催チームから外す。[targetAccountId]が自分なら、主催チームから抜ける
  Future<void> removeFromOrganizers({
    required String accountId,
    required String chatRoomId,
    required String targetAccountId,
  }) {
    return _run(
      () => _functions.call('removeFromOrganizers', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'targetAccountId': targetAccountId,
      }),
    );
  }

  // ---- お知らせと会の日時（機能仕様書4.7.8.4、データ設計書8.15） ----

  /// オフ会グループのお知らせを、新しい順に監視する。読めない（退会後など）ときは空
  Stream<List<Announcement>> watchAnnouncements(String chatRoomId) {
    return _paths
        .chatRoom(chatRoomId)
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Announcement.fromFirestore).toList())
        .handleError((Object _) {}, test: (error) => error is FirebaseException && error.code == 'permission-denied');
  }

  /// お知らせを出す。[notify]がtrueならほかのメンバーに通知する
  Future<void> postAnnouncement({
    required String accountId,
    required String chatRoomId,
    required String text,
    String? place,
    required bool notify,
  }) {
    return _run(
      () => _functions.call('postAnnouncement', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'text': text,
        'place': place ?? '',
        'notify': notify,
      }),
    );
  }

  /// お知らせを直す。[place]が空なら場所を消す
  Future<void> updateAnnouncement({
    required String accountId,
    required String chatRoomId,
    required String announcementId,
    required String text,
    String? place,
    required bool notify,
  }) {
    return _run(
      () => _functions.call('updateAnnouncement', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'announcementId': announcementId,
        'text': text,
        'place': place ?? '',
        'notify': notify,
      }),
    );
  }

  /// お知らせを消す
  Future<void> deleteAnnouncement({
    required String accountId,
    required String chatRoomId,
    required String announcementId,
  }) {
    return _run(
      () => _functions.call('deleteAnnouncement', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'announcementId': announcementId,
      }),
    );
  }

  /// 会の日時と場所、グループを閉じる日（会の[closeAfterDays]日後。機能仕様書4.7.8.6）を決める・変える。
  /// [place]が空なら場所を未定にする。[closeAfterDays]がnullなら今の値のまま
  Future<void> updateMeetupEvent({
    required String accountId,
    required String chatRoomId,
    required DateTime eventAt,
    String? place,
    int? closeAfterDays,
    required bool notify,
  }) {
    return _run(
      () => _functions.call('updateMeetupEvent', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'eventAt': eventAt.millisecondsSinceEpoch,
        'place': place ?? '',
        'closeAfterDays': ?closeAfterDays,
        'notify': notify,
      }),
    );
  }

  /// グループから退会する（機能仕様書4.7.4.1）
  Future<void> leave({required String accountId, required String chatRoomId}) {
    return _run(() => _functions.call('leaveGroup', {'accountId': accountId, 'chatRoomId': chatRoomId}));
  }

  /// 他の参加者を退会させる（機能仕様書4.7.4.2）
  Future<void> removeMember({required String accountId, required String chatRoomId, required String targetAccountId}) {
    return _run(
      () => _functions.call('removeGroupMember', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'targetAccountId': targetAccountId,
      }),
    );
  }

  /// グループ名を変更する（機能仕様書4.7.5.1）
  Future<void> updateName({required String accountId, required String chatRoomId, required String name}) {
    return _run(
      () => _functions.call('updateGroupProfile', {'accountId': accountId, 'chatRoomId': chatRoomId, 'name': name}),
    );
  }

  /// グループの画像を変更する（機能仕様書4.7.5.1）
  Future<void> updatePhoto({required String accountId, required String chatRoomId, required File file}) {
    return _uploadPhoto(accountId: accountId, chatRoomId: chatRoomId, file: file, isInitialPhoto: false);
  }

  // ---- 招待 ----

  /// アカウント[accountId]に届いている招待を、新しい順に監視する（機能仕様書4.7.2.2）
  Stream<List<GroupRequest>> watchRequests(String accountId) {
    return _paths
        .groupRequests(accountId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(GroupRequest.fromFirestore).toList());
  }

  /// 招待に参加する（[accept]がtrue）・拒否する
  Future<void> respondToRequest({required String accountId, required String chatRoomId, required bool accept}) {
    return _run(
      () => _functions.call('respondToGroupRequest', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'accept': accept,
      }),
    );
  }

  /// 友だちを招待する（機能仕様書4.7.2.1）。結果は宛先ごとに分けない
  Future<void> invite({required String accountId, required String chatRoomId, required List<String> targetAccountIds}) {
    return _run(
      () => _functions.call('inviteToGroup', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'targetAccountIds': targetAccountIds,
      }),
    );
  }

  // ---- 招待リンク・QRコード ----

  /// グループの招待トークンを取得する（無ければ作られる）
  Future<String> fetchInviteToken({required String accountId, required String chatRoomId}) async {
    final result = await _run(
      () => _functions.callForResult('getGroupInviteLink', {'accountId': accountId, 'chatRoomId': chatRoomId}),
    );
    return result['token'] as String;
  }

  /// 招待トークンを作り直す（古いリンク・QRコードは無効になる。機能仕様書4.7.2.4）
  Future<void> reissueInviteToken({required String accountId, required String chatRoomId}) {
    return _run(() => _functions.call('reissueGroupInviteLink', {'accountId': accountId, 'chatRoomId': chatRoomId}));
  }

  /// 招待トークンの確認内容を取得する（機能仕様書4.7.2.5）
  Future<GroupInvitePreview> previewInvite({required String accountId, required String token}) async {
    final result = await _run(
      () => _functions.callForResult('previewGroupInvite', {'accountId': accountId, 'token': token}),
    );
    return GroupInvitePreview.fromMap(result);
  }

  /// 招待リンク・QRコードで参加し、チャットルームIDを返す
  Future<String> joinByLink({required String accountId, required String token}) async {
    final result = await _run(
      () => _functions.callForResult('joinGroupByLink', {'accountId': accountId, 'token': token}),
    );
    return result['chatRoomId'] as String;
  }

  // ---- 参加の承認（オフ会グループ、機能仕様書4.7.8.5） ----

  /// 招待リンク・QRコードから参加を申請し、申請の状態を返す（満員ならキャンセル待ち）
  /// [answers]は質問の順の答え。承認待ち・キャンセル待ちの申請があれば、答えを変えずにその状態を返す
  Future<JoinStatus> applyToJoin({
    required String accountId,
    required String token,
    required List<String> answers,
  }) async {
    final result = await _run(
      () => _functions.callForResult('applyToJoinGroup', {'accountId': accountId, 'token': token, 'answers': answers}),
    );
    return JoinStatus.fromValue(result['status']) ?? JoinStatus.pending;
  }

  /// 出した申請を取り消す。結果（断られた・閉じた）を見終えたときは、それを消す
  Future<void> cancelApplication({required String accountId, required String chatRoomId}) {
    return _run(() => _functions.call('cancelJoinApplication', {'accountId': accountId, 'chatRoomId': chatRoomId}));
  }

  /// アカウント[accountId]が出した申請を、状態が変わった新しい順に監視する
  Stream<List<JoinApplication>> watchApplications(String accountId) {
    return _paths
        .joinApplications(accountId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(JoinApplication.fromFirestore).nonNulls.toList());
  }

  /// 答えを待っている申請（承認待ち・キャンセル待ち）を監視する（主催チームだけが読める）
  /// 並べ替えは[joinRequestSections]で行う（状態と日時の複合インデックスを作らないため）
  Stream<List<GroupJoinRequest>> watchJoinRequests(String chatRoomId) {
    return _paths
        .chatRoomJoinRequests(chatRoomId)
        .where('status', whereIn: [JoinStatus.pending.value, JoinStatus.waitlisted.value])
        .snapshots()
        .map((snap) => snap.docs.map(GroupJoinRequest.fromFirestore).nonNulls.toList());
  }

  /// メンバー[accountId]の申請の答えを取得する（主催チームだけが読める。機能仕様書4.7.8.5）
  /// 承認されて入った申請で答えがあるときだけ返し、無い・読めないときは空
  Future<List<JoinAnswer>> fetchMemberJoinAnswers({required String chatRoomId, required String accountId}) async {
    try {
      final doc = await _paths.chatRoomJoinRequests(chatRoomId).doc(accountId).get();
      return memberJoinAnswers(doc.exists ? GroupJoinRequest.fromFirestore(doc) : null);
    } on FirebaseException {
      return const [];
    }
  }

  /// 申請を承認する（[accept]がtrue）・断る
  Future<JoinResponseResult> respondToJoinRequest({
    required String accountId,
    required String chatRoomId,
    required String applicantAccountId,
    required bool accept,
  }) async {
    final result = await _run(
      () => _functions.callForResult('respondToJoinRequest', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'applicantAccountId': applicantAccountId,
        'accept': accept,
      }),
    );
    return JoinResponseResult.fromValue(result['result']);
  }

  /// 参加時の質問を決める（空なら質問なし）
  Future<void> updateJoinQuestions({
    required String accountId,
    required String chatRoomId,
    required List<String> questions,
  }) {
    return _run(
      () => _functions.call('updateJoinQuestions', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'questions': questions,
      }),
    );
  }

  // ---- 出欠（機能仕様書4.7.8.9、データ設計書8.18） ----

  /// メンバーの出欠を監視する（メンバー全員が読める。100人でも監視して読める件数）
  Stream<List<GroupAttendance>> watchAttendance(String chatRoomId) {
    return _paths
        .chatRoomAttendance(chatRoomId)
        .snapshots()
        .map((snap) => snap.docs.map(GroupAttendance.fromFirestore).nonNulls.toList())
        .handleError((Object _) {}, test: (error) => error is FirebaseException && error.code == 'permission-denied');
  }

  /// 出欠に答える・変える
  Future<void> setAttendance({
    required String accountId,
    required String chatRoomId,
    required AttendanceResponse response,
  }) {
    return _run(
      () => _functions.call('setAttendance', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'response': response.value,
      }),
    );
  }

  /// 出欠の締切を決める・変える。[deadline]がnullなら締切なし（主催チームだけ）
  Future<void> updateAttendanceDeadline({
    required String accountId,
    required String chatRoomId,
    required DateTime? deadline,
  }) {
    return _run(
      () => _functions.call('updateAttendanceDeadline', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'deadline': deadline?.millisecondsSinceEpoch,
      }),
    );
  }

  /// 未回答の人に催促し、送った人数を返す（主催チームだけ、6時間に1回まで）
  Future<int> remindAttendance({required String accountId, required String chatRoomId}) async {
    final result = await _run(
      () => _functions.callForResult('remindAttendance', {'accountId': accountId, 'chatRoomId': chatRoomId}),
    );
    return (result['count'] as num?)?.toInt() ?? 0;
  }

  // ---- 精算（機能仕様書4.7.8.12、データ設計書8.20） ----

  /// 全員の額と払った記録を監視する（主催チームの人だけ読める。読めなければ何も流さない）
  Stream<List<SettlementShare>> watchSettlementShares(String chatRoomId) {
    return _paths
        .chatRoomSettlementShares(chatRoomId)
        .snapshots()
        .map((snap) => snap.docs.map(SettlementShare.fromFirestore).nonNulls.toList())
        .handleError((Object _) {}, test: (error) => error is FirebaseException && error.code == 'permission-denied');
  }

  /// 自分の額と払った記録を監視する（対象でなければnull）
  Stream<SettlementShare?> watchMySettlementShare({required String accountId, required String chatRoomId}) {
    return _paths
        .chatRoomSettlementShares(chatRoomId)
        .doc(accountId)
        .snapshots()
        .map((doc) => doc.exists ? SettlementShare.fromFirestore(doc) : null)
        .handleError((Object _) {}, test: (error) => error is FirebaseException && error.code == 'permission-denied');
  }

  /// 精算を始める・直す（主催チームだけ）。額が変わって払った記録を消した人数を返す
  Future<int> saveSettlement({
    required String accountId,
    required String chatRoomId,
    required int totalAmount,
    required int roundingUnit,
    required List<SettlementTier> tiers,
    required List<({String accountId, String tierId})> shares,
  }) async {
    final result = await _run(
      () => _functions.callForResult('saveSettlement', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'totalAmount': totalAmount,
        'roundingUnit': roundingUnit,
        'tiers': [for (final tier in tiers) tier.toMap()],
        'shares': [
          for (final share in shares) {'accountId': share.accountId, 'tierId': share.tierId},
        ],
      }),
    );
    return (result['resetCount'] as num?)?.toInt() ?? 0;
  }

  /// 精算をやめる（主催チームだけ。全員の額と払った記録も消える）
  Future<void> deleteSettlement({required String accountId, required String chatRoomId}) {
    return _run(() => _functions.call('deleteSettlement', {'accountId': accountId, 'chatRoomId': chatRoomId}));
  }

  /// 送金リンク・PayPay IDを足す（主催チームだけ）
  Future<void> addSettlementLink({
    required String accountId,
    required String chatRoomId,
    required SettlementLinkService service,
    required SettlementLinkKind kind,
    required String value,
    String? label,
  }) {
    return _run(
      () => _functions.call('addSettlementLink', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'service': service.value,
        'kind': kind.value,
        'value': value,
        'label': ?label,
      }),
    );
  }

  /// 送金リンクを外す（主催チームだけ）
  Future<void> removeSettlementLink({required String accountId, required String chatRoomId, required String linkId}) {
    return _run(
      () =>
          _functions.call('removeSettlementLink', {'accountId': accountId, 'chatRoomId': chatRoomId, 'linkId': linkId}),
    );
  }

  /// 自分の「払った」を付ける（[paid]がtrue、払い方[method]）・取り消す（false）
  Future<void> reportSettlementPayment({
    required String accountId,
    required String chatRoomId,
    required bool paid,
    PaymentMethod? method,
  }) {
    return _run(
      () => _functions.call('reportSettlementPayment', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'paid': paid,
        'method': ?method?.value,
      }),
    );
  }

  /// 主催チームが[targetAccountId]の払ったことを確定する（[confirmed]がtrue）・未払いに戻す（false）
  Future<void> confirmSettlementPayment({
    required String accountId,
    required String chatRoomId,
    required String targetAccountId,
    required bool confirmed,
    PaymentMethod? method,
  }) {
    return _run(
      () => _functions.call('confirmSettlementPayment', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'targetAccountId': targetAccountId,
        'confirmed': confirmed,
        'method': ?method?.value,
      }),
    );
  }

  /// 未払いの人に催促し、送った人数を返す（主催チームだけ、6時間に1回まで）
  Future<int> remindSettlement({required String accountId, required String chatRoomId}) async {
    final result = await _run(
      () => _functions.callForResult('remindSettlement', {'accountId': accountId, 'chatRoomId': chatRoomId}),
    );
    return (result['count'] as num?)?.toInt() ?? 0;
  }

  // ---- 定員（機能仕様書4.7.8.10、データ設計書8.19） ----

  /// 定員を決める・変える。[capacity]がnullなら定員なし（主催チームだけ）
  Future<void> updateCapacity({required String accountId, required String chatRoomId, required int? capacity}) {
    return _run(
      () => _functions.call('updateGroupCapacity', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'capacity': capacity,
      }),
    );
  }

  // ---- 作成 ----

  /// グループを作成し、チャットルームIDを返す（機能仕様書4.7.1.1）
  Future<String> createGroup({
    required String accountId,
    required String name,
    required GroupJoinPolicy joinPolicy,
    required List<String> friendAccountIds,
    GroupKind kind = GroupKind.standard,
  }) async {
    final result = await _run(
      () => _functions.callForResult('createGroup', {
        'accountId': accountId,
        'name': name,
        'joinPolicy': joinPolicy.value,
        'groupKind': kind.value,
        'friendAccountIds': friendAccountIds,
      }),
    );
    return result['chatRoomId'] as String;
  }

  /// 閉じたオフ会グループ[chatRoomId]から次の回を作り、そのチャットルームIDを返す（機能仕様書4.7.8.13）
  /// [inviteAccountIds]は招待を送る前の回のメンバー（承諾した人だけが入る）。[name]がnullなら前の回の名前
  Future<String> createNextRound({
    required String accountId,
    required String chatRoomId,
    required List<String> inviteAccountIds,
    String? name,
  }) async {
    final result = await _run(
      () => _functions.callForResult('createNextRound', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'inviteAccountIds': inviteAccountIds,
        'name': ?name,
      }),
    );
    return result['chatRoomId'] as String;
  }

  /// 作成の続きでグループの画像を付ける
  /// 作成の前にはStorageへ置けないため、作成の後に行う（システムメッセージは出ない）
  Future<void> setInitialPhoto({required String accountId, required String chatRoomId, required File file}) {
    return _uploadPhoto(accountId: accountId, chatRoomId: chatRoomId, file: file, isInitialPhoto: true);
  }

  // ---- 内部処理 ----

  /// 画像をStorageへ上げて、グループの画像にする
  /// URLはCloud Functionsが作るため、ファイル名を渡す
  Future<void> _uploadPhoto({
    required String accountId,
    required String chatRoomId,
    required File file,
    required bool isInitialPhoto,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _storage.uploadGroupPhoto(chatRoomId, fileName, file);
    await _run(
      () => _functions.call('updateGroupProfile', {
        'accountId': accountId,
        'chatRoomId': chatRoomId,
        'photoFileName': fileName,
        'isInitialPhoto': isInitialPhoto,
      }),
    );
  }

  /// Cloud Functionsのエラーを[GroupException]に変える
  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseFunctionsException catch (error) {
      throw GroupException(GroupFailure.fromValue(error.message));
    } on FirebaseException {
      throw const GroupException(GroupFailure.unknown);
    }
  }
}
