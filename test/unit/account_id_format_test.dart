import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/utils/validators.dart';

void main() {
  group('アカウントIDの形式（機能仕様書4.2.1）', () {
    test('半角英数字と . - _ の4〜20文字は使える（大文字も可）', () {
      for (final id in ['abcd', 'Alice_01', 'a.b-c_d', '12345678901234567890']) {
        expect(isValidAccountIdFormat(id), isTrue, reason: id);
      }
    });

    test('3文字以下・21文字以上・それ以外の文字を含むものは使えない', () {
      for (final id in ['abc', '123456789012345678901', 'ab cd', 'ab~cd', 'あいうえお', 'ab@cd', '']) {
        expect(isValidAccountIdFormat(id), isFalse, reason: id);
      }
    });
  });
}
