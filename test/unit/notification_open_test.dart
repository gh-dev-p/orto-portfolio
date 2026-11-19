import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/data/services/passcode/passcode_store.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
import 'package:multi_id_msg/ui/notification/view_models/notification_open_provider.dart';
import 'package:multi_id_msg/ui/passcode/view_models/passcode_providers.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStorage implements PasscodeStorage {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

Account _account(String id) =>
    Account(id: id, displayName: id);

const _toLocked = NotificationTarget(accountId: 'locked', chatRoomId: 'locked~peer', peerAccountId: 'peer');
const _toOpen = NotificationTarget(accountId: 'open', chatRoomId: 'open~peer', peerAccountId: 'peer');

void main() {
  group('通知のデータの読み取り', () {
    test('宛先・チャットルーム・相手が揃っていれば読み取る', () {
      expect(
        NotificationTarget.fromData({'accountId': 'locked', 'chatRoomId': 'locked~peer', 'peerAccountId': 'peer'}),
        _toLocked,
      );
    });

    test('typeがreactionならリアクションの通知として読み取る', () {
      final data = {'accountId': 'locked', 'chatRoomId': 'locked~peer', 'peerAccountId': 'peer'};
      expect(NotificationTarget.fromData({...data, 'type': 'reaction'})!.isReaction, isTrue);
      expect(NotificationTarget.fromData({...data, 'type': 'message'})!.isReaction, isFalse);
      expect(NotificationTarget.fromData(data)!.isReaction, isFalse);
    });

    test('値が欠けている・空の通知（古いサーバーからの通知等）は無視する', () {
      expect(NotificationTarget.fromData({}), isNull);
      expect(NotificationTarget.fromData({'accountId': 'locked', 'chatRoomId': 'locked~peer'}), isNull);
      expect(NotificationTarget.fromData({'accountId': '', 'chatRoomId': 'locked~peer', 'peerAccountId': 'peer'}), isNull);
    });
  });

  group('通知のタップでトークを開く（機能仕様書4.4.6.1）', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = _MemoryStorage();
      await PasscodeStore(storage).save('locked', '1234');
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          accountsProvider.overrideWith((ref) => Stream.value([_account('locked'), _account('open')])),
          passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
        ],
      );
      // 状態の変化を受け取れるよう、購読しておく。
      container.listen(readyNotificationTargetProvider, (_, _) {});
      // アプリでは_AccountGateがアカウント一覧を監視し続けている。Riverpod 3では、誰も監視していないStreamProviderは
      // 一時停止して値を流さないため、テストでも監視しておく。
      container.listen(accountsProvider, (_, _) {});
      // パスコードの有無もStreamProviderのため、アプリのガードと同じく監視しておく。
      container.listen(passcodeEnabledProvider('locked'), (_, _) {});
      container.listen(passcodeEnabledProvider('open'), (_, _) {});
      await container.read(passcodeEnabledProvider('locked').future);
      await container.read(passcodeEnabledProvider('open').future);
    });

    tearDown(() => container.dispose());

    NotificationTarget? ready() => container.read(readyNotificationTargetProvider);

    test('パスコードの無いアカウント宛てなら、そのアカウントに切り替えてすぐに開ける', () async {
      await container.read(activeAccountIdProvider.notifier).setActive('locked');
      container.read(unlockedAccountIdProvider.notifier).unlock('locked');

      await container.read(notificationOpenerProvider).open(_toOpen);

      expect(container.read(activeAccountIdProvider), 'open');
      expect(ready(), _toOpen);
    });

    test('パスコードを設定したアカウント宛ては、ロックを解除するまで開かない', () async {
      await container.read(activeAccountIdProvider.notifier).setActive('open');

      await container.read(notificationOpenerProvider).open(_toLocked);

      expect(container.read(activeAccountIdProvider), 'locked');
      expect(container.read(passcodeGuardStatusProvider), PasscodeGuardStatus.locked);
      expect(ready(), isNull);

      container.read(unlockedAccountIdProvider.notifier).unlock('locked');
      expect(ready(), _toLocked);
    });

    test('通知先がすでに解除済みのアクティブなアカウントでも、必ずロック画面を通す', () async {
      await container.read(activeAccountIdProvider.notifier).setActive('locked');
      container.read(unlockedAccountIdProvider.notifier).unlock('locked');
      expect(container.read(passcodeGuardStatusProvider), PasscodeGuardStatus.open);

      await container.read(notificationOpenerProvider).open(_toLocked);

      expect(container.read(passcodeGuardStatusProvider), PasscodeGuardStatus.locked);
      expect(ready(), isNull);
    });

    test('使用中のアカウントが変わるときだけ、切り替えの案内の印を立てる', () async {
      await container.read(activeAccountIdProvider.notifier).setActive('open');
      await container.read(notificationOpenerProvider).open(_toOpen);
      expect(container.read(pendingNotificationTargetProvider.notifier).switched, isFalse);

      await container.read(notificationOpenerProvider).open(_toLocked);
      expect(container.read(pendingNotificationTargetProvider.notifier).switched, isTrue);
    });

    test('自分のアカウント宛てでない通知は無視する', () async {
      await container.read(activeAccountIdProvider.notifier).setActive('open');

      await container
          .read(notificationOpenerProvider)
          .open(const NotificationTarget(accountId: 'someone-else', chatRoomId: 'room-3', peerAccountId: 'peer'));

      expect(container.read(activeAccountIdProvider), 'open');
      expect(container.read(pendingNotificationTargetProvider), isNull);
    });

    test('ロック中に別のアカウントへ切り替えたら、開く予定を取り消す', () async {
      await container.read(notificationOpenerProvider).open(_toLocked);
      expect(container.read(pendingNotificationTargetProvider), _toLocked);

      await container.read(activeAccountIdProvider.notifier).setActive('open');

      expect(container.read(pendingNotificationTargetProvider), isNull);
      expect(ready(), isNull);
    });
  });
}
