// ============================================================
// ドメインモデル
// ============================================================

/// ログイン中のユーザ（uid）
/// Firebase Authenticationの`User`のうち、アプリで使う項目だけを持つ（[AuthRepository]が変換する）
class AuthUser {
  const AuthUser({required this.uid, this.phoneNumber});

  /// ユーザの内部ID（Firebase AuthenticationのUID）
  /// 他人には見せない
  final String uid;

  /// ログインに使っている電話番号（E.164形式）
  final String? phoneNumber;
}
