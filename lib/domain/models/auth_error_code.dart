// ============================================================
// enum
// ============================================================

/// SMS認証（AUT-02・AUT-03）のエラー種別
/// 表示文言は持たず、View側でAppLocalizations経由に変換する（ViewModel・Model層はBuildContextに依存しないため。architecture-design.md 2章）
enum AuthErrorCode {
  /// 電話番号の形式が正しくない
  invalidPhoneNumber,
  /// 送信・確認の回数が多すぎる
  tooManyRequests,
  /// 通信エラー
  /// 種類の分からないエラーもこれとして扱う
  network,
  /// 認証コードが違う
  invalidVerificationCode,
  /// 認証コードの有効期限が切れた
  codeExpired,
  /// サインイン（再認証）に失敗した
  /// ログイン中のUserを取得できない等
  signInFailed,
  /// 電話番号の変更：新しい番号が既に別のユーザ（uid）に使われている
  phoneNumberInUse,
  /// 電話番号の変更：現在と同じ番号が入力された
  samePhoneNumber,
  /// SMSを送れない国・地域の電話番号が入力された
  /// FirebaseのSMS地域ポリシーによる
  unsupportedRegion,
  /// 運営者が利用を停止した電話番号でログインした
  accountSuspended,
}

// ============================================================
// 例外クラス
// ============================================================

/// SMS認証の失敗を表す例外
/// 失敗の種類を[code]に持つ（[AuthRepository]がFirebaseのエラーから変換する）
class AuthException implements Exception {
  const AuthException(this.code);

  /// 失敗の種類
  final AuthErrorCode code;
}
