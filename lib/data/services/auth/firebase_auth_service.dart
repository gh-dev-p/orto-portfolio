import 'package:firebase_auth/firebase_auth.dart';

// ============================================================
// サービス
// ============================================================

/// Firebase Authenticationを包むサービス
/// 状態を持たず、Firebase Authenticationの結果・エラーをそのまま返す（ドメインモデルへの変換・エラーの変換は[AuthRepository]が行う）
class FirebaseAuthService {
  FirebaseAuthService(this._auth);

  // ---- 状態・初期化 ----

  /// Firebase Authenticationのインスタンス
  final FirebaseAuth _auth;

  // ---- ログイン状態 ----

  /// ログイン状態の変化
  /// サインイン・サインアウトのときに流れる
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// ログイン中のUserの情報の変化
  /// ログイン状態に加え、電話番号の変更などUserの情報が変わったときにも流れる
  Stream<User?> userChanges() => _auth.userChanges();

  /// ログイン中のUser
  /// ログインしていなければnull
  User? get currentUser => _auth.currentUser;

  /// サインアウトする
  Future<void> signOut() => _auth.signOut();

  // ---- IDトークン ----

  /// ログイン中のUserのIDトークン
  /// ログインしていなければnull
  Future<String?> idToken() async => _auth.currentUser?.getIdToken();

  /// ログイン中のUserのIDトークンのクレーム
  /// ログインしていなければnull（[forceRefresh]がtrueなら、トークンを取り直してから読む）
  Future<Map<String, dynamic>?> idTokenClaims({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final result = await user.getIdTokenResult(forceRefresh);
    return result.claims ?? const {};
  }

  // ---- 電話番号認証 ----

  /// [phoneNumber]宛にSMS認証コードを送る
  /// 結果はFirebase Authenticationのコールバックでそのまま知らせる
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required int? forceResendingToken,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(FirebaseAuthException exception) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// verificationIdとSMSコードから認証情報を作る
  PhoneAuthCredential credentialFromCode({required String verificationId, required String smsCode}) =>
      PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);

  /// 認証情報でサインインする
  /// サインインしたUserを返す（取得できなければnull）
  Future<User?> signInWithCredential(PhoneAuthCredential credential) async {
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  /// ログイン中のUserを、認証情報で再認証する
  /// ログインしていなければ`user-not-found`のエラーを投げる
  Future<void> reauthenticate(PhoneAuthCredential credential) => _requireUser().reauthenticateWithCredential(credential);

  /// ログイン中のUserの電話番号を、認証情報の番号に差し替える
  /// 差し替えた後、Userの情報とIDトークンを取り直す（ログインしていなければ`user-not-found`のエラーを投げる）
  Future<void> updatePhoneNumber(PhoneAuthCredential credential) async {
    final user = _requireUser();
    await user.updatePhoneNumber(credential);
    await user.reload();
    await user.getIdToken(true);
  }

  /// ログイン中のUserを取得する
  /// ログインしていなければ`user-not-found`のエラーを投げる
  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'user-not-found');
    return user;
  }
}
