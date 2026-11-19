import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/reserved_account_ids.dart';

void main() {
  test('予約IDは大文字小文字・記号の違いを無視して判定する', () {
    expect(isReservedAccountId('support'), isTrue);
    expect(isReservedAccountId('Sup.port'), isTrue);
    expect(isReservedAccountId('ORTO_official'), isTrue);
    expect(isReservedAccountId(' admin '), isTrue);
  });

  test('予約IDを部分的に含むだけのIDは使用できる', () {
    expect(isReservedAccountId('badminton'), isFalse);
    expect(isReservedAccountId('support_fan'), isFalse);
    expect(isReservedAccountId('disney'), isFalse);
  });
}
