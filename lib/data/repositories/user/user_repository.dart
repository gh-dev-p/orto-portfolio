import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/common/cloud_functions_service.dart';
import '../../services/common/firestore_paths.dart';

// ============================================================
// 状態クラス
// ============================================================

/// 使い続けるアカウント（機能仕様書4.2.1.3）
/// [ids]は`users/{uid}.keptAccountIds`、[chosen]は画面から選び終えているか
typedef KeptAccounts = ({List<String> ids, bool chosen});

// ============================================================
// リポジトリ
// ============================================================

/// ユーザ（データ設計書3.1 `users`）のリポジトリ
/// `users/{uid}`の読み書きと、退会を扱う
///
/// 例外として、初回アカウント作成時の`users/{uid}`の作成・更新は、アカウント数の上限の検証のため
/// [AccountRepository.createAccount]がアカウントと同じバッチで行う（firestore.rules）
class UserRepository {
  UserRepository(this._paths, this._functionsService);

  // ---- 状態・初期化 ----

  /// Firestoreのパス（接続先）
  final FirestorePaths _paths;

  /// Cloud Functionsのサービス
  final CloudFunctionsService _functionsService;

  // ---- 読み取り ----

  /// 指定ユーザ（uid）のプラン（`users/{uid}.plan`）を監視する
  /// `users/{uid}`は初回アカウント作成時に作られるため、それまではnullを流す
  Stream<String?> watchUserPlan(String uid) {
    return _paths.user(uid).snapshots().map((doc) => doc.data()?['plan'] as String?);
  }

  /// 指定ユーザ（uid）の使い続けるアカウント（`users/{uid}.keptAccountIds`）を監視する
  Stream<KeptAccounts> watchKeptAccounts(String uid) {
    return _paths.user(uid).snapshots().map((doc) {
      final data = doc.data();
      return (
        ids: (data?['keptAccountIds'] as List<dynamic>? ?? const []).cast<String>(),
        chosen: data?['keptAccountsChosenAt'] != null,
      );
    });
  }

  /// 指定ユーザ（uid）の、引き継ぎパスワードの再設定の申請（`users/{uid}.transferResetAt`）を監視する
  /// 申請が無ければnull、あれば前のデータを削除する日時。書くのはCloud Functionsだけ
  Stream<DateTime?> watchTransferResetAt(String uid) {
    return _paths.user(uid).snapshots().map((doc) => (doc.data()?['transferResetAt'] as Timestamp?)?.toDate());
  }

  /// 指定ユーザ（uid）が、[version]以降の版の利用規約とプライバシーポリシーに同意しているか
  /// 同意の記録（`users/{uid}/legalConsents/{版}`）は、版（最終改定日）をIDにしてCloud Functionsが書く
  Future<bool> hasLegalConsentSince(String uid, String version) async {
    final snap = await _paths
        .user(uid)
        .collection('legalConsents')
        .where('version', isGreaterThanOrEqualTo: version)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// 利用規約とプライバシーポリシーの今の版への同意を記録する（改定の再同意）
  /// 失敗したら[FirebaseFunctionsException]を投げる
  Future<void> recordLegalConsent() => _functionsService.call('recordLegalConsent');

  // ---- 更新 ----

  /// `users/{uid}.phoneNumber`を、電話番号の変更後の番号にする
  /// `users`が未作成なら何もしない（firestore.rulesは、認証トークンの電話番号と一致する値への更新だけを許可する）
  Future<void> updateUserPhoneNumber(String uid, String phoneNumber) async {
    final ref = _paths.user(uid);
    final doc = await ref.get();
    if (!doc.exists) return;
    await ref.update({'phoneNumber': phoneNumber});
  }

  // ---- 退会 ----

  /// 退会する
  /// 保有する全アカウントの個人情報・`users/{uid}`・Firebase AuthenticationのUserをCloud Functions（`withdrawUser`）が削除する（端末側のサインアウト等は呼び出し元で行う）
  ///
  /// `withdrawUser`の制限時間（300秒）まで待つ（既定の60秒では、サーバーの処理中に失敗の扱いになるため）
  Future<void> withdraw() => _functionsService.call('withdrawUser', null, const Duration(seconds: 300));
}
