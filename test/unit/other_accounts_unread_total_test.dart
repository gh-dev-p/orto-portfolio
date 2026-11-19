import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/data/repositories/account/active_account_repository.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/passcode/view_models/passcode_providers.dart';

class _FakeActiveAccountRepository implements ActiveAccountRepository {
  @override
  String? read() => 'active';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Account _account(String id) => Account(id: id, displayName: id);

void main() {
  test('ロック中のアカウントの未読も合計に含め、使用中のアカウントの未読は含めない', () async {
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        activeAccountRepositoryProvider.overrideWithValue(_FakeActiveAccountRepository()),
        accountsProvider.overrideWithValue(AsyncData([_account('active'), _account('open'), _account('locked')])),
        chatListForAccountProvider.overrideWith(
          (ref, accountId) => Stream.value([
            ChatListEntry(
              chatRoomId: 'room',
              peerAccountId: 'peer',
              unreadCount: const {'active': 1, 'open': 2, 'locked': 4}[accountId]!,
            ),
          ]),
        ),
        passcodeEnabledProvider.overrideWith((ref, accountId) => Stream.value(accountId == 'locked')),
      ],
    );
    addTearDown(container.dispose);
    container.listen(otherAccountsUnreadTotalProvider, (_, _) {});
    await pumpEventQueue();

    expect(container.read(otherAccountsUnreadTotalProvider), 6);
  });
}
