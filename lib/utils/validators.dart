/// アカウントIDの形式：半角英数字及び記号（`.` `-` `_`）のみ、4〜20文字（機能仕様書4.2.1・データ設計書4章、
/// LINE ID仕様を参考）。予約IDかどうかは別に`isReservedAccountId`（reserved_account_ids.dart）で確かめる。
final _accountIdFormat = RegExp(r'^[a-zA-Z0-9._-]{4,20}$');

bool isValidAccountIdFormat(String id) => _accountIdFormat.hasMatch(id);

/// 前後の空白を除いた文字列の長さが[minLength]〜[maxLength]の範囲内か判定する。
/// 表示名（1〜20文字）・ひとこと（0〜100文字）・ニックネーム（0〜20文字）等、画面をまたいで
/// 共通の文字数バリデーションに使う。
bool isValidTrimmedLength(String value, {required int minLength, required int maxLength}) {
  final length = value.trim().length;
  return length >= minLength && length <= maxLength;
}
