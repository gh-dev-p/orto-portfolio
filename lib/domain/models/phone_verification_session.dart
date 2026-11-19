import 'phone_verification_purpose.dart';

// ============================================================
// ドメインモデル
// ============================================================

/// SMS認証の手続き中の状態（画面から見える部分）
/// AUT-02・AUT-04で送信を始めてから、AUT-03で確認し終わるまで、[AuthRepository]が持つ
class PhoneVerificationSession {
  const PhoneVerificationSession({
    required this.purpose,
    required this.phoneNumber,
    required this.codeSent,
    this.resendAvailableAt,
  });

  /// 何のための認証か
  final PhoneVerificationPurpose purpose;

  /// 送信先の電話番号（E.164形式）
  final String phoneNumber;

  /// SMSを送信済みか
  /// trueなら認証コードを確認できる
  final bool codeSent;

  /// 再送できるようになる日時
  /// SMSを送信するたびに、そこから60秒後になる（未送信ならnull）
  final DateTime? resendAvailableAt;
}
