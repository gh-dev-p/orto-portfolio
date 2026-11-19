import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/utils/phone_number_format.dart';

void main() {
  test('日本の携帯番号は国内形式にし、中央4桁を伏せる', () {
    expect(formatMaskedPhoneNumber('+819012345678'), '090-****-5678');
  });

  test('日本の10桁の番号は先頭2桁と末尾4桁以外を伏せる', () {
    expect(formatMaskedPhoneNumber('+81312345678'), '03****5678');
  });

  test('日本以外の番号はE.164のまま、先頭3文字と末尾4桁以外を伏せる', () {
    expect(formatMaskedPhoneNumber('+14155552671'), '+14*****2671');
  });

  test('短すぎる番号はそのまま表示する', () {
    expect(formatMaskedPhoneNumber('+1234'), '+1234');
  });
}
