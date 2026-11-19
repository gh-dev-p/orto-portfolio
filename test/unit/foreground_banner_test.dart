import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/notification/view_models/notification_open_provider.dart';

NotificationTarget _target({String accountId = 'me', String chatRoomId = 'me~peer'}) =>
    NotificationTarget(accountId: accountId, chatRoomId: chatRoomId, peerAccountId: 'peer');

void main() {
  group('アプリを開いているときの新着のバナー（機能仕様書4.4.6.2）', () {
    const open = (accountId: 'me', chatRoomId: 'me~peer');

    test('いま見ているトーク宛ての新着では、バナーを出さない', () {
      expect(shouldShowForegroundBanner(_target(), open), isFalse);
    });

    test('別のトーク・別のアカウント宛ての新着では、バナーを出す', () {
      expect(shouldShowForegroundBanner(_target(chatRoomId: 'me~other'), open), isTrue);
      expect(shouldShowForegroundBanner(_target(accountId: 'sub'), open), isTrue);
    });

    test('トークを見ていないとき・トークのデータが無い通知では、バナーを出す', () {
      expect(shouldShowForegroundBanner(_target(), null), isTrue);
      expect(shouldShowForegroundBanner(null, open), isTrue);
    });
  });

  group('いま見ているトーク（openChatProvider）', () {
    test('見るのをやめたトークだけを外し、別のトークに切り替わった後なら何もしない', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(openChatProvider.notifier);
      const first = (accountId: 'me', chatRoomId: 'me~a');
      const second = (accountId: 'me', chatRoomId: 'me~b');

      notifier.open(first);
      notifier.open(second);
      notifier.close(first);
      expect(container.read(openChatProvider), second);

      notifier.close(second);
      expect(container.read(openChatProvider), isNull);
    });
  });
}
