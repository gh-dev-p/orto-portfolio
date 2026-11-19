import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/account_notification_settings.dart';

void main() {
  group('アカウントごとの通知設定の読み取り', () {
    test('ドキュメント・フィールドが無いときはオンとして扱う', () {
      expect(AccountNotificationSettings.fromData(null), AccountNotificationSettings.defaults);
      expect(AccountNotificationSettings.fromData({'accountId': 'me'}), AccountNotificationSettings.defaults);
    });

    test('falseのときだけオフにする', () {
      expect(
        AccountNotificationSettings.fromData({'notificationsEnabled': false, 'reactionNotificationsEnabled': true}),
        const AccountNotificationSettings(messages: false, reactions: true),
      );
      expect(
        AccountNotificationSettings.fromData({'reactionNotificationsEnabled': false}),
        const AccountNotificationSettings(messages: true, reactions: false),
      );
    });
  });
}
