// 友だちの招待キー（機能仕様書4.3.1.4、データ設計書3.14）
// 招待リンク・マイQRコードにキーを入れ、受け取ったキーを友だち追加まで覚えておくことを確かめる。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/app_flavor.dart';
import 'package:multi_id_msg/config/invite_links.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/friend/friend_repository.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/models/friend.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/friend/view_models/friend_invite_key_providers.dart';
import 'package:multi_id_msg/ui/friend/view_models/friend_providers.dart';
import 'package:multi_id_msg/ui/profile/view_models/friend_profile_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => currentFlavor = AppFlavor.prod);

  final key = 'A' * 42 + 'b';
  final otherKey = 'z' * 43;

  group('招待リンクの招待キー', () {
    test('キーを付けて組み立て、IDとキーの両方を読み取れる', () {
      final link = InviteLinks.forAccount('alice', AppFlavor.prod, inviteKey: key);
      expect(link, 'https://orto.example.com/invite/alice?k=$key');
      final uri = Uri.parse(link);
      expect(InviteLinks.accountIdFrom(uri, AppFlavor.prod), 'alice');
      expect(InviteLinks.inviteKeyFrom(uri), key);
    });

    test('キーが無ければ、今までと同じリンクにする', () {
      expect(InviteLinks.forAccount('alice', AppFlavor.prod), 'https://orto.example.com/invite/alice');
      expect(InviteLinks.inviteKeyFrom(Uri.parse('https://orto.example.com/invite/alice')), isNull);
    });

    test('形式に合わないキーは読み取らない', () {
      String? read(String query) => InviteLinks.inviteKeyFrom(Uri.parse('https://orto.example.com/invite/alice?$query'));
      expect(read('k=short'), isNull);
      expect(read('k=${'a' * 44}'), isNull);
      expect(read('k=${'a' * 42}%2F'), isNull);
      expect(read('key=$key'), isNull);
    });

    test('マイQRコードにキーを入れ、スキャナーで読むとキーも取り出す', () {
      final data = InviteLinks.friendQrData('alice', AppFlavor.prod, inviteKey: key);
      final invite = InviteLinks.qrInviteFrom(data, AppFlavor.prod) as FriendQrInvite;
      expect(invite.accountId, 'alice');
      expect(invite.inviteKey, key);
    });

    test('キーの無い（以前の）QRコードは、IDだけを読む', () {
      final invite = InviteLinks.qrInviteFrom('https://orto.example.com/invite/alice', AppFlavor.prod) as FriendQrInvite;
      expect(invite.accountId, 'alice');
      expect(invite.inviteKey, isNull);
      final legacy = InviteLinks.qrInviteFrom('orto://friend/alice', AppFlavor.prod) as FriendQrInvite;
      expect(legacy.inviteKey, isNull);
    });
  });

  group('受け取った招待キー', () {
    late SharedPreferences preferences;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(preferences)]);
    });

    tearDown(() => container.dispose());

    ReceivedInviteKeysNotifier notifier() => container.read(receivedInviteKeysProvider.notifier);

    test('覚えたキーをアカウントIDで引け、新しいキーで上書きする', () {
      notifier().remember('alice', key);
      expect(container.read(receivedInviteKeysProvider)['alice'], key);
      notifier().remember('alice', otherKey);
      expect(container.read(receivedInviteKeysProvider)['alice'], otherKey);
    });

    test('端末に保存し、作り直しても残る（SMS認証を挟んでも友だち追加に使える）', () {
      notifier().remember('alice', key);
      final next = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(preferences)]);
      addTearDown(next.dispose);
      expect(next.read(receivedInviteKeysProvider)['alice'], key);
    });

    test('招待リンクにキーがあれば覚え、無ければ何もしない', () {
      notifier().rememberFromLink(Uri.parse(InviteLinks.forAccount('alice', currentFlavor, inviteKey: key)));
      notifier().rememberFromLink(Uri.parse(InviteLinks.forAccount('bob', currentFlavor)));
      expect(container.read(receivedInviteKeysProvider), {'alice': key});
    });

    test('上限の20件を超えたら、古いものから捨てる', () {
      for (var i = 0; i < 21; i++) {
        notifier().remember('account$i', key);
      }
      final keys = container.read(receivedInviteKeysProvider);
      expect(keys.length, 20);
      expect(keys.containsKey('account0'), isFalse);
      expect(keys.containsKey('account20'), isTrue);
    });

    test('保存した値が壊れていれば、空から始める', () async {
      SharedPreferences.setMockInitialValues({'receivedFriendInviteKeys': 'not json'});
      final broken = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance())],
      );
      addTearDown(broken.dispose);
      expect(broken.read(receivedInviteKeysProvider), isEmpty);
    });
  });

  group('PRO-01の友だち追加で招待キーを添える', () {
    late _RecordingFriendRepository repository;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = _RecordingFriendRepository();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          friendRepositoryProvider.overrideWithValue(repository),
          accountByIdProvider.overrideWith((ref, id) => Stream.value(Account(id: id, displayName: id))),
          friendsProvider.overrideWith((ref) => Stream.value(const <Friend>[])),
        ],
      );
    });

    tearDown(() => container.dispose());

    Future<void> add(String accountId) async {
      final provider = friendProfileViewModelProvider((accountId: accountId, myAccountId: 'me', groupChatRoomId: null));
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      expect(await container.read(provider.notifier).addFriend(), isTrue);
    }

    test('QRコード・招待リンクで受け取ったキーがあれば添える', () async {
      container.read(receivedInviteKeysProvider.notifier).remember('alice', key);
      await add('alice');
      expect(repository.added, [('me', 'alice', key)]);
    });

    test('受け取っていなければ添えない（IDで検索したとき等）', () async {
      container.read(receivedInviteKeysProvider.notifier).remember('alice', key);
      await add('bob');
      expect(repository.added, [('me', 'bob', null)]);
    });
  });
}

/// 友だち追加の呼び出しを記録するだけのリポジトリ
class _RecordingFriendRepository implements FriendRepository {
  final added = <(String, String, String?)>[];

  @override
  Future<void> addFriend({required String myAccountId, required String peerAccountId, String? inviteKey}) async {
    added.add((myAccountId, peerAccountId, inviteKey));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
