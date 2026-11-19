import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../config/account_plan_limits.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/account_id_taken_exception.dart';
import '../../services/common/firestore_paths.dart';
import '../../services/profile/profile_storage_service.dart';

export '../../../domain/models/account_id_taken_exception.dart';

// ============================================================
// リポジトリ
// ============================================================

/// アカウント（データ設計書3.2 `accounts`）と、ユーザが保有するアカウントの一覧（3.1.1 `ownedAccounts`）のリポジトリ
/// プロフィール画像のアップロード（Cloud Storage）も扱う。ユーザ（3.1 `users`）は[UserRepository]、友だちは[FriendRepository]、ブロックは[BlockRepository]が扱う
///
/// 例外として、[createAccount]は`users/{uid}`もアカウントと同じバッチで作成・更新する
/// （アカウント数の上限を、firestore.rulesが同一リクエスト内で検証するため）
class AccountRepository {
  AccountRepository(this._paths, this._profileStorageService);

  // ---- 状態・初期化 ----

  /// Firestoreのパス（接続先）
  final FirestorePaths _paths;

  /// プロフィール画像のアップロードのサービス
  final ProfileStorageService _profileStorageService;

  // ---- 読み取り ----

  /// 指定ユーザ（uid）が保有するアカウントの一覧を監視する（データ設計書3.1.1）
  /// 保有した順に流す（`ownedAccounts`にあるのに`accounts`が読めないものは出さない。データ設計書3.2【補足】）
  ///
  /// `users/{uid}/ownedAccounts`を作成日時順に監視し、そのaccountIdごとに`accounts/{accountId}`を監視して、そろった分を流す
  Stream<List<Account>> watchAccountsForUser(String uid) {
    late final StreamController<List<Account>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ownedSub;
    final accountSubs = <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    final accounts = <String, Account?>{};
    var order = <String>[];

    void emit() {
      // 全アカウントの初回取得がそろうまでは流さない（一覧が1件ずつ増えて見えるのを避ける）。
      if (!order.every(accounts.containsKey)) return;
      controller.add([for (final id in order) ?accounts[id]]);
    }

    controller = StreamController<List<Account>>(
      onListen: () {
        ownedSub = _paths.ownedAccounts(uid).orderBy('createdAt').snapshots().listen((snap) {
          order = snap.docs.map((doc) => doc.id).toList();
          for (final id in accountSubs.keys.where((id) => !order.contains(id)).toList()) {
            accountSubs.remove(id)?.cancel();
            accounts.remove(id);
          }
          for (final id in order) {
            accountSubs[id] ??= _paths.account(id).snapshots().listen((doc) {
              accounts[id] = doc.exists ? Account.fromFirestore(doc) : null;
              emit();
            }, onError: controller.addError);
          }
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await ownedSub?.cancel();
        await Future.wait(accountSubs.values.map((sub) => sub.cancel()));
        accountSubs.clear();
      },
    );
    return controller.stream;
  }

  /// 指定したアカウントを監視する
  /// 存在しない場合はnullを流す（相手の表示名・画像・退会の状態の変化を画面に反映するため）
  Stream<Account?> watchAccount(String accountId) {
    return _paths.account(accountId).snapshots().map((doc) => doc.exists ? Account.fromFirestore(doc) : null);
  }

  /// 指定したアカウントを1回取得する
  /// 存在しない場合はnull
  Future<Account?> getAccount(String accountId) async {
    final doc = await _paths.account(accountId).get();
    if (!doc.exists) return null;
    return Account.fromFirestore(doc);
  }

  /// アカウント作成画面での「使用可能か確認」の事前確認
  /// 使えるならtrue（画面での使い勝手のためだけ。最終的な一意性の保証は[createAccount]のFirestoreルールの`!exists(...)`検証による）
  Future<bool> isAccountIdAvailable(String accountId) async {
    final doc = await _paths.account(accountId).get();
    return !doc.exists;
  }

  // ---- 作成 ----

  /// アカウントを作成する（機能仕様書4.2.1）
  /// アカウントIDは画面で入力したものをドキュメントIDとしてそのまま使う（既に使われていたら[AccountIdTakenException]を投げる）
  ///
  /// アカウント数の上限をすり抜けられないよう、アカウントの作成と`users/{uid}.accountCount`の+1を1回のバッチで行う（データ設計書3.1）
  /// firestore.rulesが「作成後のカウンタ＝作成前＋1」かつ「プランの上限以内」をこのバッチ内で検証する
  Future<Account> createAccount({
    required String accountId,
    required String uid,
    required String displayName,
    String? phoneNumber,
    String? bio,
    String? photoURL,
  }) async {
    final ref = _paths.account(accountId);
    final existing = await ref.get();
    if (existing.exists) throw const AccountIdTakenException();

    final draft = Account(
      id: accountId,
      displayName: displayName,
      photoURL: photoURL,
      bio: bio,
    );
    final userRef = _paths.user(uid);
    final user = await userRef.get();
    final blockedUntil = user.data()?['accountCreateBlockedUntil'] as Timestamp?;
    if (blockedUntil != null && blockedUntil.toDate().isAfter(DateTime.now())) {
      throw const AccountCreationBlockedException();
    }
    // accounts・ownedAccounts・usersを1リクエストで書く（データ設計書3.2【補足】）。firestore.rulesが
    // 同一リクエスト内のownedAccountsの作成と、accountCountの+1・上限を検証する。lastCreatedAccountIdは、
    // 1回の+1で1件だけ作っていることの確認に使う。
    final batch = _paths.batch();
    batch.set(ref, draft.toFirestore());
    batch.set(_paths.ownedAccounts(uid).doc(accountId), {
      'accountId': accountId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (user.exists) {
      batch.update(userRef, {'accountCount': FieldValue.increment(1), 'lastCreatedAccountId': accountId});
    } else {
      batch.set(userRef, {
        'uid': uid,
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'accountCount': 1,
        'plan': AccountPlanLimits.freePlan,
        'lastCreatedAccountId': accountId,
      });
    }
    await batch.commit();
    final created = await ref.get();
    return Account.fromFirestore(created);
  }

  // ---- 更新 ----

  /// プロフィールを更新する（PRO-03、機能仕様書4.5.1）
  /// 渡した項目だけを更新する（photoURL・backgroundURLは画像を変更した場合のみ渡し、未指定なら既存の値のまま）
  Future<void> updateProfile({
    required String accountId,
    String? displayName,
    String? photoURL,
    String? backgroundURL,
    bool? allowIdSearch,
    String? bio,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (photoURL != null) data['photoURL'] = photoURL;
    if (backgroundURL != null) data['backgroundURL'] = backgroundURL;
    if (allowIdSearch != null) data['allowIdSearch'] = allowIdSearch;
    if (bio != null) data['bio'] = bio;
    if (data.isEmpty) return;
    await _paths.account(accountId).update(data);
  }

  /// プロフィール画像をアップロードし、アカウントの画像に設定する
  /// 失敗したらアップロードの例外をそのまま投げる（ACC-02のアカウントの作成後・PRO-03の画像の変更で使う）
  Future<void> updateProfileImage({required String accountId, required File image}) async {
    final photoURL = await _profileStorageService.uploadProfileImage(accountId, image);
    await updateProfile(accountId: accountId, photoURL: photoURL);
  }

  /// 背景画像をアップロードし、アカウントの背景に設定する（PRO-03）
  /// 失敗したらアップロードの例外をそのまま投げる
  Future<void> updateBackgroundImage({required String accountId, required File image}) async {
    final backgroundURL = await _profileStorageService.uploadBackgroundImage(accountId, image);
    await updateProfile(accountId: accountId, backgroundURL: backgroundURL);
  }

  // ---- 削除 ----

  /// アカウントを削除する（ACC-03、機能仕様書4.2.3）
  /// 物理削除ではなく`isDeleted`フラグを立てるソフトデリート（データ設計書3.2。ドキュメントIDの再利用防止のため、ドキュメント自体は残す）
  Future<void> softDeleteAccount(String accountId) {
    return _paths.account(
      accountId,
    ).update({'isDeleted': true});
  }
}
