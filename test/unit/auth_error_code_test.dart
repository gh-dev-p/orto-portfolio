// Firebase Authのエラーを、画面に出すエラー種別に変換する（AuthRepository）。
// 止めた電話番号はAuthのブロッキング関数が断る（データ設計書3.11）。
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/repositories/auth/auth_repository.dart';

AuthErrorCode _codeFor(String code, [String? message]) =>
    AuthRepository.errorCodeForTesting(FirebaseAuthException(code: code, message: message));

void main() {
  test('無効にしたユーザーは停止中として出す', () {
    expect(_codeFor('user-disabled'), AuthErrorCode.accountSuspended);
  });

  test('ブロッキング関数の断り（止めた電話番号）は停止中として出す', () {
    expect(_codeFor('blocking-cloud-function-error', 'PHONE_BANNED'), AuthErrorCode.accountSuspended);
    expect(_codeFor('internal-error', 'BLOCKING_FUNCTION_ERROR_RESPONSE : PHONE_BANNED'), AuthErrorCode.accountSuspended);
  });

  test('それ以外の不明なエラーは通信エラーとして出す', () {
    expect(_codeFor('internal-error', 'something'), AuthErrorCode.network);
  });
}
