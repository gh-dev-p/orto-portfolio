import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../domain/models/auth_error_code.dart';
import '../../../domain/models/auth_user.dart';
import '../../../domain/models/phone_verification_purpose.dart';
import '../../../domain/models/phone_verification_session.dart';
import '../../../domain/models/transfer_password_error.dart';
import '../../../domain/models/transfer_password_status.dart';
import '../../../domain/models/verification_start.dart';
import '../../services/common/cloud_functions_service.dart';
import '../../services/auth/firebase_auth_service.dart';

export '../../../domain/models/auth_error_code.dart';
export '../../../domain/models/auth_user.dart';
export '../../../domain/models/phone_verification_purpose.dart';
export '../../../domain/models/phone_verification_session.dart';
export '../../../domain/models/transfer_password_status.dart';
export '../../../domain/models/verification_start.dart';

// ============================================================
// リポジトリ
// ============================================================

/// ログイン（認証）のリポジトリ
/// 電話番号（SMS認証）でのサインイン・再認証・電話番号の変更と、引き継ぎパスワードを扱う
///
/// SMS認証の手続き中の状態（送信先・verificationId・再送の待ち時間など）は、複数の画面（AUT-02〜AUT-04）の
/// ViewModelで共有するため、本クラスが持つ
///
/// 機能仕様書4.1.1「ユーザログイン／サインアップ」：電話番号でUserを作成またはログインする
/// Firebase Authentication・Cloud Functionsの結果をドメインモデルに、エラーを[AuthErrorCode]・[TransferPasswordError]に変換して返す
class AuthRepository {
  AuthRepository(this._authService, this._functionsService, {this.legalConsentRetryDelay = const Duration(seconds: 3)});

  // ---- 状態・初期化 ----

  /// Firebase Authenticationのサービス
  final FirebaseAuthService _authService;

  /// Cloud Functionsのサービス
  final CloudFunctionsService _functionsService;

  /// 再送できるようになるまでの待ち時間
  static const resendCooldown = Duration(seconds: 60);

  /// 同意の記録を試す回数
  static const _legalConsentAttempts = 3;

  /// 同意の記録に失敗したときに、次に試すまでの待ち時間
  final Duration legalConsentRetryDelay;

  /// SMS認証の手続き中の状態
  /// 送信を始めるたびに作り直す（手続きをしていなければnull）
  _VerificationSession? _session;

  // ---- ログイン状態 ----

  /// ログイン状態の変化
  /// サインイン・サインアウトのときに流れる
  Stream<AuthUser?> get authStateChanges => _authService.authStateChanges().map(_toAuthUser);

  /// ログイン中のユーザの情報の変化
  /// ログイン状態に加え、電話番号の変更などユーザの情報が変わったときにも流れる
  Stream<AuthUser?> get userChanges => _authService.userChanges().map(_toAuthUser);

  /// ログイン中のユーザ
  /// ログインしていなければnull
  AuthUser? get currentUser => _toAuthUser(_authService.currentUser);

  /// サインアウトする
  /// 同一ユーザ（uid）に紐づく全Accountがまとめて使えなくなり、再ログインには電話番号のSMS認証が必要
  ///
  /// 退会（機能仕様書4.1.5）、AUT-05から電話番号の入力に戻るとき（4.1.4.2）、管理者のログアウト（4.1.7）で使う
  /// iOSでは、Firebase SDKがKeychainに保存しているログイン情報もここで消える（Keychainはアプリを削除しても残るため、消さない限り再インストール後も自動でログインする）
  Future<void> signOut() => _authService.signOut();

  /// ログイン中のユーザが管理者か（機能仕様書4.1.7）
  /// IDトークンのカスタムクレーム`admin`から読む（サーバーでしか設定できず、画面の操作では変えられない）。ログインしていなければfalse
  Future<bool> isAdmin() async => (await _authService.idTokenClaims())?['admin'] == true;

  /// Firebase Authenticationの`User`を、ドメインモデルに変換する
  /// nullならnull
  static AuthUser? _toAuthUser(User? user) => user == null ? null : AuthUser(uid: user.uid, phoneNumber: user.phoneNumber);

  // ---- SMS認証の手続き ----

  /// SMS認証の手続き中の状態
  /// 手続きをしていなければnull
  PhoneVerificationSession? get verificationSession {
    final session = _session;
    if (session == null) return null;
    return PhoneVerificationSession(
      purpose: session.purpose,
      phoneNumber: session.phoneNumber,
      codeSent: session.verificationId != null,
      resendAvailableAt: session.resendAvailableAt,
    );
  }

  /// [phoneNumber]宛に、[purpose]の目的でSMS認証の手続きを始める
  /// SMSを送信できたら[VerificationStart.codeSent]、端末の自動検証で目的の処理まで完了したら[VerificationStart.verified]（失敗したら[AuthException]を投げる）
  ///
  /// 再認証・電話番号の変更では、始める前のIDトークンを取っておく（引き継ぎパスワードの確認済みの状態の引き継ぎに使う）
  Future<VerificationStart> startVerification({
    required PhoneVerificationPurpose purpose,
    required String phoneNumber,
  }) async {
    final previousIdToken = purpose == PhoneVerificationPurpose.signIn ? null : await _tryCurrentIdToken();
    _session = _VerificationSession(purpose: purpose, phoneNumber: phoneNumber, previousIdToken: previousIdToken);
    return _send(resend: false);
  }

  /// 手続き中の電話番号宛に、SMS認証コードを再送する
  /// 結果は[startVerification]と同じ（手続きをしていなければ[AuthErrorCode.signInFailed]の[AuthException]を投げる）
  Future<VerificationStart> resendCode() {
    if (_session == null) throw const AuthException(AuthErrorCode.signInFailed);
    return _send(resend: true);
  }

  /// 認証コードを確認し、手続きの目的の処理（サインイン・再認証・電話番号の差し替え）を行う
  /// 失敗したら[AuthException]を投げる（SMSを送信していなければ[AuthErrorCode.signInFailed]）
  Future<void> confirmCode(String smsCode) async {
    final session = _session;
    final verificationId = session?.verificationId;
    if (session == null || verificationId == null) throw const AuthException(AuthErrorCode.signInFailed);
    try {
      await _complete(
        session.purpose,
        _authService.credentialFromCode(verificationId: verificationId, smsCode: smsCode),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthRepository] confirmCode failed: code=${e.code} message=${e.message}');
      throw AuthException(_errorCodeFor(e));
    }
  }

  /// 手続き中の電話番号宛に、SMS認証コードを送る（初回・再送共通）
  /// 結果はFirebase Authenticationのコールバックで受け取って返す
  ///
  /// 注意：`verifyPhoneNumber()`のFutureは送信要求を出した直後に完了し、実際の送信完了（コールバック）を待たない
  /// そのため、await後に強制的に完了させない（コールバックより先に失敗扱いになり、AUT-03へ遷移しない不具合の原因だったため）
  Future<VerificationStart> _send({required bool resend}) async {
    final session = _session!;
    final completer = Completer<VerificationStart>();

    void fail(FirebaseAuthException e) {
      debugPrint('[AuthRepository] sendCode failed: code=${e.code} message=${e.message}');
      if (!completer.isCompleted) completer.completeError(AuthException(_errorCodeFor(e)));
    }

    await _authService.verifyPhoneNumber(
      phoneNumber: session.phoneNumber,
      forceResendingToken: resend ? session.resendToken : null,
      verificationCompleted: (credential) async {
        try {
          await _complete(session.purpose, credential);
          if (!completer.isCompleted) completer.complete(VerificationStart.verified);
        } on FirebaseAuthException catch (e) {
          fail(e);
        }
      },
      verificationFailed: fail,
      codeSent: (verificationId, resendToken) {
        session
          ..verificationId = verificationId
          ..resendToken = resendToken
          ..resendAvailableAt = DateTime.now().add(resendCooldown);
        if (!completer.isCompleted) completer.complete(VerificationStart.codeSent);
      },
    );
    return completer.future;
  }

  /// 確認できた認証情報で、[purpose]ごとの処理を行う
  /// コードの確認（[confirmCode]）・端末の自動検証（[sendCode]）の両方から呼ぶ
  Future<void> _complete(PhoneVerificationPurpose purpose, PhoneAuthCredential credential) async {
    switch (purpose) {
      case PhoneVerificationPurpose.signIn:
        final user = await _authService.signInWithCredential(credential);
        if (user == null) throw FirebaseAuthException(code: 'user-not-found');
        // ここの結果でサインインを止めない（失敗しても、案内を見て進んだ事実は変わらないため）
        unawaited(recordLegalConsent());
      case PhoneVerificationPurpose.reauthentication:
        await _authService.reauthenticate(credential);
      case PhoneVerificationPurpose.phoneNumberChange:
        // 電話番号を差し替え、IDトークンを取り直す（firestore.rulesが`users.phoneNumber`の更新を、
        // 認証トークンの電話番号と一致する値に限って許可するため）。
        await _authService.updatePhoneNumber(credential);
    }
  }

  /// 利用規約とプライバシーポリシーへの同意を、サーバーに記録する（AUT-02の案内を見てサインインしたとき）
  /// 失敗しても投げない。サインイン直後の通信の失敗に備えて、[legalConsentRetryDelay]をあけて最大3回まで試す
  @visibleForTesting
  Future<void> recordLegalConsent() async {
    for (var attempt = 1; attempt <= _legalConsentAttempts; attempt++) {
      try {
        await _functionsService.call('recordLegalConsent');
        return;
      } catch (e) {
        debugPrint('[AuthRepository] recordLegalConsent failed: attempt=$attempt $e');
        if (attempt < _legalConsentAttempts) await Future<void>.delayed(legalConsentRetryDelay);
      }
    }
  }

  @visibleForTesting
  static AuthErrorCode errorCodeForTesting(FirebaseAuthException exception) => _errorCodeFor(exception);

  /// [FirebaseAuthException]を、画面に出すエラー種別に変換する
  /// 画面設計書5.1.2/5.1.3の異常系に対応（不明なエラーは通信エラーとして扱う）
  static AuthErrorCode _errorCodeFor(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-phone-number':
        return AuthErrorCode.invalidPhoneNumber;
      case 'too-many-requests':
        return AuthErrorCode.tooManyRequests;
      case 'network-request-failed':
        return AuthErrorCode.network;
      case 'invalid-verification-code':
        return AuthErrorCode.invalidVerificationCode;
      case 'session-expired':
      case 'code-expired':
        return AuthErrorCode.codeExpired;
      case 'user-not-found':
        return AuthErrorCode.signInFailed;
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return AuthErrorCode.phoneNumberInUse;
      // FirebaseのSMS地域ポリシーで、その国・地域宛てのSMSを許可していない。
      case 'operation-not-allowed':
        return AuthErrorCode.unsupportedRegion;
      // 運営者がFirebase Authのユーザーを無効にした
      case 'user-disabled':
        return AuthErrorCode.accountSuspended;
      // 運営者が再登録を止めた電話番号を、Authのブロッキング関数が断った（データ設計書3.11）。
      // Authのブロッキング関数は止めた電話番号の照合だけなので、コードで判定し、Android向けにmessageでも見る。
      case 'blocking-cloud-function-error':
        return AuthErrorCode.accountSuspended;
      default:
        if (exception.message?.contains('PHONE_BANNED') ?? false) return AuthErrorCode.accountSuspended;
        return AuthErrorCode.network;
    }
  }

  // ---- IDトークン・引き継ぎパスワード ----

  /// 今のIDトークン
  /// 取得できなかった場合はnull（SMS再認証・電話番号の変更の前に取っておき、確認済みの状態の引き継ぎに使う）
  Future<String?> _tryCurrentIdToken() async {
    try {
      return await _authService.idToken();
    } catch (_) {
      return null;
    }
  }

  /// 引き継ぎパスワードの状態を読む
  /// IDトークンのカスタムクレームから読む（[forceRefresh]がtrueなら、Cloud Functionsでクレームを変えた直後の値を取り直す）
  Future<TransferPasswordStatus> transferPasswordStatus({bool forceRefresh = false}) async {
    final claims = await _authService.idTokenClaims(forceRefresh: forceRefresh);
    if (claims == null) return const TransferPasswordStatus(registered: false, sessionVerified: true);
    final registered = claims['tp'] == true;
    final authTime = claims['auth_time'];
    final verifiedSessions = claims['va'];
    return TransferPasswordStatus(
      registered: registered,
      sessionVerified: !registered || (verifiedSessions is List && verifiedSessions.contains(authTime)),
    );
  }

  /// 引き継ぎパスワードを登録・変更する（SET-05）
  /// 成功後、呼び出し元でIDトークンを取り直す（失敗したら[TransferPasswordException]を投げる）
  Future<void> registerTransferPassword(String password) => _callTransferPassword('setTransferPassword', password);

  /// 新しい端末でのログイン後に、引き継ぎパスワードを確認する（AUT-05）
  /// 成功後、呼び出し元でIDトークンを取り直す（失敗したら[TransferPasswordException]を投げる）
  Future<void> verifyTransferPassword(String password) => _callTransferPassword('verifyTransferPassword', password);

  /// 手続き前のセッションの、引き継ぎパスワードの確認済みの状態を、新しいセッションへ引き継ぐ
  /// SMS再認証・電話番号の変更でログイン時刻が新しくなると未確認のセッション扱いになるため、手続き前のIDトークンをCloud Functionsで検証してもらう
  ///
  /// 引き継いだらtrue（呼び出し元でIDトークンを取り直す）。手続き前のIDトークンがない・既に確認済み（パスワード未登録を含む）ならfalse
  Future<bool> carryOverTransferVerificationIfNeeded() async {
    final previousIdToken = _session?.previousIdToken;
    if (previousIdToken == null) return false;
    final status = await transferPasswordStatus(forceRefresh: true);
    if (status.sessionVerified) return false;
    await _functionsService.call('carryOverTransferVerification', {'previousIdToken': previousIdToken});
    return true;
  }

  /// 引き継ぎパスワードの再設定の申請の状態を返す（機能仕様書4.1.4.3）
  /// 申請が無ければnull、あれば前のデータを削除する日時
  Future<DateTime?> transferResetStatus() => _callTransferReset('status');

  /// 引き継ぎパスワードの再設定を申請する（AUT-05、確認前のセッションから）
  /// 猶予の後に前のデータを削除する日時を返す。申請済みなら前の申請の日時
  Future<DateTime?> requestTransferReset() => _callTransferReset('request');

  /// 引き継ぎパスワードの再設定の申請を取り消す（確認前・確認済みのどちらのセッションからも）
  Future<void> cancelTransferReset() => _callTransferReset('cancel');

  /// 再設定のCloud Functions（`transferReset`）を[action]で呼び、削除の日時を返す
  Future<DateTime?> _callTransferReset(String action) async {
    final result = await _functionsService.callForResult('transferReset', {'action': action});
    final resetAt = result['resetAt'];
    return resetAt is int ? DateTime.fromMillisecondsSinceEpoch(resetAt) : null;
  }

  /// 引き継ぎパスワードのCloud Functions（[name]）を呼ぶ
  /// 失敗したら、エラーコードを[TransferPasswordError]に変換して[TransferPasswordException]を投げる
  Future<void> _callTransferPassword(String name, String password) async {
    try {
      await _functionsService.call(name, {'password': password});
    } on FirebaseFunctionsException catch (e) {
      throw TransferPasswordException(switch (e.code) {
        'permission-denied' => TransferPasswordError.wrong,
        'resource-exhausted' => TransferPasswordError.locked,
        'invalid-argument' => TransferPasswordError.invalid,
        _ => TransferPasswordError.network,
      });
    }
  }
}

// ============================================================
// 状態クラス
// ============================================================

/// SMS認証の手続き中の状態（[AuthRepository]の中だけで使う）
class _VerificationSession {
  _VerificationSession({required this.purpose, required this.phoneNumber, required this.previousIdToken});

  /// 何のための認証か
  final PhoneVerificationPurpose purpose;

  /// 送信先の電話番号（E.164形式）
  final String phoneNumber;

  /// 手続き前のIDトークン
  /// 再認証・電話番号の変更のときだけ持つ（引き継ぎパスワードの確認済みの状態の引き継ぎに使う）
  final String? previousIdToken;

  /// 送信したSMSの受付番号
  /// 認証コードの確認に使う（未送信ならnull）
  String? verificationId;

  /// 再送用のトークン
  /// 再送時にFirebaseへ渡す
  int? resendToken;

  /// 再送できるようになる日時
  DateTime? resendAvailableAt;
}
