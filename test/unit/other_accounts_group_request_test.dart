import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/data/repositories/account/active_account_repository.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/passcode/view_models/passcode_providers.dart';

class _FakeActiveAccountRepository implements ActiveAccountRepository {
  @override
  String? read() => 'active';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Account _account(String id) =>
    Account(id: id, displayName: id);

const _request = GroupRequest(chatRoomId: 'room', invitedBy: 'someone', name: 'group', memberCount: 2);

void main() {
  var locked = <String>{};
  late Map<String, StreamController<List<GroupRequest>>> streams;
  late ProviderContainer container;

  setUp(() async {
    locked = {};
    streams = {
      for (final id in ['active', 'other']) id: StreamController<List<GroupRequest>>.broadcast(),
    };
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        activeAccountRepositoryProvider.overrideWithValue(_FakeActiveAccountRepository()),
        accountsProvider.overrideWithValue(AsyncData([_account('active'), _account('other')])),
        groupRequestsForAccountProvider.overrideWith((ref, accountId) => streams[accountId]!.stream),
        passcodeEnabledProvider.overrideWith((ref, accountId) => Stream.value(locked.contains(accountId))),
      ],
    );
    addTearDown(container.dispose);
    container.listen(otherAccountsHaveGroupRequestProvider, (_, _) {});
    await pumpEventQueue();
  });

  test('ほかのアカウントに招待が届くとtrueになり、無くなるとfalseに戻る', () async {
    expect(container.read(otherAccountsHaveGroupRequestProvider), isFalse);

    streams['other']!.add(const [_request]);
    await pumpEventQueue();
    expect(container.read(otherAccountsHaveGroupRequestProvider), isTrue);

    streams['other']!.add(const []);
    await pumpEventQueue();
    expect(container.read(otherAccountsHaveGroupRequestProvider), isFalse);
  });

  test('ロック中のアカウントの招待は数えない', () async {
    locked = {'other'};
    container.invalidate(passcodeEnabledProvider);
    await pumpEventQueue();

    streams['other']!.add(const [_request]);
    await pumpEventQueue();
    expect(container.read(otherAccountsHaveGroupRequestProvider), isFalse);
  });

  test('使用中のアカウントの招待は数えず、監視もしない', () async {
    expect(streams['active']!.hasListener, isFalse);
    expect(streams['other']!.hasListener, isTrue);
  });
}
