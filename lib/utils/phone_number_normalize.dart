import 'package:phone_numbers_parser/phone_numbers_parser.dart';

// ============================================================
// 関数
// ============================================================

/// 電話番号をE.164形式に正規化する
/// 入力を選んだ国・地域（[isoCountryCode]）の番号として解釈して作成（番号が正しくない場合はnull）
///
/// - 国内形式の番号は、[isoCountryCode]（ISO 3166-1 alpha-2。AUT-02で選んだ国・地域）の番号として解釈する。
///   先頭の`0`（国内でかけるときに付ける数字）の有無は国ごとのルールで処理される
///   （例：JPで`090-1234-5678`・`9012345678` → `+819012345678`。イタリアのように`0`が番号の一部の国では残す）
/// - `+`始まりの番号は、選んだ国・地域より入力された国番号を優先する
/// - 番号として正しくない場合、パーサーは先頭の`0`を除かないまま結果を返すため、必ず[PhoneNumber.isValid]で確かめる。
///   固定電話でもSMSを受け取れる国があるため、携帯番号かどうかは判定しない
String? normalizePhoneNumberToE164(String input, {required String isoCountryCode}) {
  final trimmed = input.trim();
  final isoCode = IsoCode.values.asNameMap()[isoCountryCode.toUpperCase()];
  if (trimmed.isEmpty || isoCode == null) return null;
  try {
    // destinationCountryは`+`始まりの番号にも選んだ国の国番号を付けてしまうため、callerCountryを使う。
    final phoneNumber = PhoneNumber.parse(trimmed, callerCountry: isoCode);
    return phoneNumber.isValid() ? phoneNumber.international : null;
  } on PhoneNumberException {
    return null;
  }
}
