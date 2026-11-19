import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/services/passcode/passcode_store.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
import 'package:multi_id_msg/ui/account/view_models/invite_account_choice_provider.dart';
import 'package:multi_id_msg/ui/friend/view_models/invite_link_provider.dart';
import 'package:multi_id_msg/ui/group/view_models/group_invite_providers.dart';
import 'package:multi_id_msg/ui/passcode/view_models/passcode_providers.dart';
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

Account _account(String id) => Account(id: id, displayName: id);

const _token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ';

void main() {
  group('外部から届いた招待で使うアカウントの決め方', () {
    final accounts = [_account('daily'), _account('event'), _account('old')];

    test('選べるアカウントが2つ以上なら、使用中のアカウントを選んだ状態でシートを出す', () {
      final decision = decideInviteAccount(accounts: accounts, readOnlyIds: const {}, activeAccountId: 'event');
      expect(decision, isA<InviteAccountAsk>());
      final ask = decision as InviteAccountAsk;
      expect(ask.initialAccountId, 'event');
      expect(ask.accounts.map((account) => account.id), ['daily', 'event', 'old']);
    });

    test('読み取り専用のアカウントも並べるが、選べるものとしては数えない', () {
      final decision = decideInviteAccount(accounts: accounts, readOnlyIds: const {'old'}, activeAccountId: 'daily');
      expect(decision, isA<InviteAccountAsk>());
      expect((decision as InviteAccountAsk).readOnlyIds, {'old'});
    });

    test('使用中のアカウントが読み取り専用なら、選べる最初のアカウントを選んだ状態にする', () {
      final decision = decideInviteAccount(accounts: accounts, readOnlyIds: const {'daily'}, activeAccountId: 'daily');
      expect((decision as InviteAccountAsk).initialAccountId, 'event');
    });

    test('選べるアカウントが1つなら、シートを出さずにそのアカウントを使う', () {
      expect(
        (decideInviteAccount(accounts: [_account('daily')], readOnlyIds: const {}, activeAccountId: 'daily')
                as InviteAccountUse)
            .accountId,
        'daily',
      );
      // 読み取り専用を除いて1つ（使用中が読み取り専用）なら、選べる方を使う。
      expect(
        (decideInviteAccount(accounts: accounts, readOnlyIds: const {'daily', 'old'}, activeAccountId: 'daily')
                as InviteAccountUse)
            .accountId,
        'event',
      );
    });

    test('選べるアカウントが無ければ、使用中のアカウントのまま（追加・参加のときに読み取り専用と知らせる）', () {
      final decision = decideInviteAccount(
        accounts: [_account('daily')],
        readOnlyIds: const {'daily'},
        activeAccountId: 'daily',
      );
      expect((decision as InviteAccountUse).accountId, 'daily');
    });
  });

  group('選んだアカウントへ切り替えてから招待を開く', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = _MemoryStorage();
      await PasscodeStore(storage).save('locked', '1234');
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          accountsProvider.overrideWith(
            (ref) => Stream.value([_account('daily'), _account('event'), _account('locked')]),
          ),
          passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
          userPlanProvider.overrideWith((ref) => Stream.value(null)),
          keptAccountsProvider.overrideWith((ref) => Stream.value((ids: const <String>[], chosen: false))),
        ],
      );
      container.listen(readyInviteProvider, (_, _) {});
      container.listen(readyGroupInviteProvider, (_, _) {});
      container.listen(accountsProvider, (_, _) {});
      for (final id in ['daily', 'event', 'locked']) {
        container.listen(passcodeEnabledProvider(id), (_, _) {});
      }
      await container.read(accountsProvider.future);
      for (final id in ['daily', 'event', 'locked']) {
        await container.read(passcodeEnabledProvider(id).future);
      }
      await container.read(activeAccountIdProvider.notifier).setActive('daily');
    });

    tearDown(() => container.dispose());

    Future<void> choose(String accountId) async {
      container.read(inviteAccountChoiceProvider.notifier).choose(accountId);
      await container.read(activeAccountIdProvider.notifier).setActive(accountId);
    }

    test('アカウントを選ぶ前は、使用中のアカウントで開ける', () {
      container.read(pendingInviteProvider.notifier).set('friend');
      container.read(pendingGroupInviteProvider.notifier).set(_token);
      expect(container.read(readyInviteProvider), 'friend');
      expect(container.read(readyGroupInviteProvider), _token);
      expect(container.read(inviteAccountDecisionProvider), isA<InviteAccountAsk>());
    });

    test('選んだアカウントが使用中になるまでは開かず、なったら開ける', () async {
      container.read(pendingGroupInviteProvider.notifier).set(_token);
      container.read(inviteAccountChoiceProvider.notifier).choose('event');
      expect(container.read(readyGroupInviteProvider), isNull);

      await container.read(activeAccountIdProvider.notifier).setActive('event');
      expect(container.read(readyGroupInviteProvider), _token);
      expect(container.read(inviteAccountChoiceProvider), 'event');
    });

    test('パスコードを設定したアカウントを選んだら、解除するまで開かない', () async {
      container.read(pendingInviteProvider.notifier).set('friend');
      await choose('locked');
      expect(container.read(readyInviteProvider), isNull);

      container.read(unlockedAccountIdProvider.notifier).unlock('locked');
      expect(container.read(readyInviteProvider), 'friend');
    });

    test('解除せずに別のアカウントに切り替えたら、選んだ記録を消す（選び直しになる）', () async {
      container.read(pendingInviteProvider.notifier).set('friend');
      await choose('locked');
      // AUT-04を閉じると、使用中のアカウントが未選択に戻る。この間は選んだ記録を残す。
      await container.read(activeAccountIdProvider.notifier).clear();
      expect(container.read(inviteAccountChoiceProvider), 'locked');

      await container.read(activeAccountIdProvider.notifier).setActive('event');
      expect(container.read(inviteAccountChoiceProvider), isNull);
      expect(container.read(readyInviteProvider), 'friend');
    });
  });
}
