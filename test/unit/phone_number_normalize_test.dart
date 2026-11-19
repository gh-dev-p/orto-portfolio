import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/utils/phone_number_normalize.dart';

String? normalize(String input, String country) => normalizePhoneNumberToE164(input, isoCountryCode: country);

void main() {
  group('日本を選んだ場合', () {
    test('先頭の0・ハイフンの有無にかかわらずE.164に正規化する', () {
      expect(normalize('090-1234-5678', 'JP'), '+819012345678');
      expect(normalize('09012345678', 'JP'), '+819012345678');
      expect(normalize('9012345678', 'JP'), '+819012345678');
      expect(normalize(' 090 1234 5678 ', 'JP'), '+819012345678');
    });

    test('+81の後ろに0を残した書き方も、同じ番号に正規化する', () {
      expect(normalize('+8109012345678', 'JP'), '+819012345678');
    });

    test('固定電話の番号も受け付ける', () {
      expect(normalize('03-1234-5678', 'JP'), '+81312345678');
    });

    test('桁数が足りない番号は受け付けない', () {
      expect(normalize('090123', 'JP'), isNull);
    });
  });

  group('日本以外を選んだ場合', () {
    test('国ごとのルールで先頭の0を処理する', () {
      expect(normalize('010-1234-5678', 'KR'), '+821012345678');
      expect(normalize('0912 345 678', 'TW'), '+886912345678');
      expect(normalize('07400 123456', 'GB'), '+447400123456');
      expect(normalize('(415) 555-2671', 'US'), '+14155552671');
    });

    test('0が番号の一部の国（イタリア）では0を残す', () {
      expect(normalize('06 1234 5678', 'IT'), '+390612345678');
    });

    test('番号として正しくない場合は受け付けない（先頭の0が残った結果を返さない）', () {
      expect(normalize('07911 123456', 'GB'), isNull);
    });
  });

  test('+始まりの番号は、選んだ国・地域より入力された国番号を優先する', () {
    expect(normalize('+14155552671', 'JP'), '+14155552671');
    expect(normalize('+81 90 1234 5678', 'US'), '+819012345678');
  });

  test('空文字・数字でない入力・未知の国コードは受け付けない', () {
    expect(normalize('', 'JP'), isNull);
    expect(normalize('abc', 'JP'), isNull);
    expect(normalize('09012345678', 'ZZ'), isNull);
  });
}
