import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/app_version_policy.dart';
import 'package:multi_id_msg/domain/models/message.dart';

void main() {
  group('AppVersionPolicy.requiresUpdate（機能仕様書4.1.6）', () {
    const policy = AppVersionPolicy(minimumVersion: '1.2.0');

    test('最低バージョンより古ければ更新が必要', () {
      expect(policy.requiresUpdate('1.1.9'), isTrue);
      expect(policy.requiresUpdate('0.9.9'), isTrue);
    });

    test('最低バージョン以上なら更新は不要', () {
      expect(policy.requiresUpdate('1.2.0'), isFalse);
      expect(policy.requiresUpdate('1.2.1'), isFalse);
      expect(policy.requiresUpdate('2.0.0'), isFalse);
    });

    test('桁は文字列ではなく数として比べる', () {
      expect(const AppVersionPolicy(minimumVersion: '1.10.0').requiresUpdate('1.9.0'), isTrue);
    });

    test('足りない桁は0として比べる', () {
      expect(const AppVersionPolicy(minimumVersion: '1.2').requiresUpdate('1.2.0'), isFalse);
    });

    test('バージョンを読み取れないときはアプリを止めない', () {
      expect(const AppVersionPolicy(minimumVersion: '').requiresUpdate('1.0.0'), isFalse);
      expect(const AppVersionPolicy(minimumVersion: 'abc').requiresUpdate('1.0.0'), isFalse);
      expect(policy.requiresUpdate('1.0.0-beta'), isFalse);
    });
  });

  group('MessageType.fromValue', () {
    test('typeが無い旧データはテキスト', () {
      expect(MessageType.fromValue(null), MessageType.text);
    });

    test('知っている種類はそのまま', () {
      expect(MessageType.fromValue('text'), MessageType.text);
      expect(MessageType.fromValue('image'), MessageType.image);
    });

    test('知らない種類はunknown', () {
      expect(MessageType.fromValue('poll'), MessageType.unknown);
    });
  });
}
