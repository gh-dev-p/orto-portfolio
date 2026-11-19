import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/app_flavor.dart';
import 'package:multi_id_msg/config/invite_links.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/services/invite_link/invite_clipboard_service.dart';
import 'package:multi_id_msg/data/services/invite_link/invite_link_service.dart';
import 'package:multi_id_msg/data/services/passcode/passcode_store.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
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

void main() {
  group('グループの招待リンク', _groupInviteLinkTests);

  group('招待リンクの組み立て・読み取り', () {
    test('環境ごとのweb.appのドメインで組み立てる', () {
      expect(InviteLinks.forAccount('alice', AppFlavor.prod), 'https://orto.example.com/invite/alice');
      expect(InviteLinks.forAccount('alice', AppFlavor.dev), 'https://orto-dev.example.com/invite/alice');
    });

    test('組み立てたリンクからIDを取り出せる', () {
      final link = Uri.parse(InviteLinks.forAccount('alice.b_c-1', AppFlavor.prod));
      expect(InviteLinks.accountIdFrom(link, AppFlavor.prod), 'alice.b_c-1');
    });

    test('2つ目のドメイン・末尾のスラッシュ付きも読み取る', () {
      expect(InviteLinks.accountIdFrom(Uri.parse('https://open.example.com/invite/alice'), AppFlavor.prod), 'alice');
      expect(InviteLinks.accountIdFrom(Uri.parse('https://orto.example.com/invite/alice/'), AppFlavor.prod), 'alice');
    });

    test('別の環境・別のドメイン・別のパス・httpのリンクは読み取らない', () {
      String? read(String link) => InviteLinks.accountIdFrom(Uri.parse(link), AppFlavor.prod);
      expect(read('https://orto-dev.example.com/invite/alice'), isNull);
      expect(read('https://example.com/invite/alice'), isNull);
      expect(read('https://orto.example.com/legal/alice'), isNull);
      expect(read('https://orto.example.com/invite'), isNull);
      expect(read('https://orto.example.com/invite/alice/extra'), isNull);
      expect(read('http://orto-prod.web.app/invite/alice'), isNull);
    });

    test('アカウントIDの形式に合わないIDは読み取らない', () {
      String? read(String link) => InviteLinks.accountIdFrom(Uri.parse(link), AppFlavor.prod);
      expect(read('https://orto.example.com/invite/abc'), isNull);
      expect(read('https://orto.example.com/invite/a%20bcd'), isNull);
    });
  });

  group('招待リンクで開く予定の招待', () {
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
      // 状態の変化を受け取れるよう、監視しておく（StreamProviderは誰も監視していないと値を流さない）。
      container.listen(readyInviteProvider, (_, _) {});
      container.listen(accountsProvider, (_, _) {});
      container.listen(passcodeEnabledProvider('locked'), (_, _) {});
      container.listen(passcodeEnabledProvider('open'), (_, _) {});
      await container.read(accountsProvider.future);
      await container.read(passcodeEnabledProvider('locked').future);
      await container.read(passcodeEnabledProvider('open').future);
    });

    tearDown(() => container.dispose());

    String? ready() => container.read(readyInviteProvider);

    test('使用中のアカウントが無い間（アカウント未選択等）は開かず、選んだら開ける', () async {
      container.read(pendingInviteProvider.notifier).set('friend');
      expect(ready(), isNull);

      await container.read(activeAccountIdProvider.notifier).setActive('open');
      expect(ready(), 'friend');
    });

    test('パスコードを設定したアカウントは、ロックを解除するまで開かない', () async {
      await container.read(activeAccountIdProvider.notifier).setActive('locked');
      container.read(pendingInviteProvider.notifier).set('friend');
      expect(ready(), isNull);

      container.read(unlockedAccountIdProvider.notifier).unlock('locked');
      expect(ready(), 'friend');
    });

    test('開いたものとして消せるのは、まだ開く予定の招待だけ', () async {
      await container.read(activeAccountIdProvider.notifier).setActive('open');
      container.read(pendingInviteProvider.notifier).set('friend');
      final opener = container.read(inviteLinkOpenerProvider);

      expect(opener.take('someone-else'), isFalse);
      expect(opener.take('friend'), isTrue);
      expect(ready(), isNull);
      expect(opener.take('friend'), isFalse);
    });

    test('自分が持つアカウントの招待は、使用中でなくても自分自身として扱う', () async {
      final opener = container.read(inviteLinkOpenerProvider);
      expect((await opener.resolve(accountId: 'open', myAccountId: 'open')).error, InviteLinkError.selfAdd);
      expect((await opener.resolve(accountId: 'locked', myAccountId: 'open')).error, InviteLinkError.selfAdd);
    });
  });

  group('招待の端末への保存（機能仕様書4.3.5.2）', () {
    ProviderContainer restart(SharedPreferences preferences) {
      final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(preferences)]);
      addTearDown(container.dispose);
      return container;
    }

    test('アプリを再起動しても招待が残り、開いたら消える', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();

      restart(preferences).read(pendingInviteProvider.notifier).set('friend');

      final next = restart(preferences);
      expect(next.read(pendingInviteProvider), 'friend');

      next.read(pendingInviteProvider.notifier).clear();
      expect(restart(preferences).read(pendingInviteProvider), isNull);
    });
  });

  group('クリップボードからの招待の引き継ぎ（機能仕様書4.3.5.2）', () {
    late SharedPreferences preferences;
    late _FakeClipboardService clipboard;
    late ProviderContainer container;

    setUpAll(() => currentFlavor = AppFlavor.prod);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      await preferences.clear();
      clipboard = _FakeClipboardService();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          inviteClipboardServiceProvider.overrideWithValue(clipboard),
        ],
      );
    });

    tearDown(() => container.dispose());

    InviteClipboardRestorer restorer() => container.read(inviteClipboardRestorerProvider);
    InvitePasteStatus status() => container.read(invitePasteProvider);
    String? pending() => container.read(pendingInviteProvider);

    test('URLがありそうなら、貼り付けボタンを出す（本文は読まない）', () async {
      clipboard.hasUrlResult = true;
      await restorer().check();
      expect(status(), InvitePasteStatus.offered);
      expect(pending(), isNull);
    });

    test('URLが無ければ、出さない', () async {
      await restorer().check();
      expect(status(), InvitePasteStatus.hidden);
    });

    test('確認は1回だけ', () async {
      await restorer().check();
      clipboard.hasUrlResult = true;
      await restorer().check();
      expect(clipboard.checks, 1);
      expect(status(), InvitePasteStatus.hidden);
    });

    test('すでに開く予定の招待があれば、確かめない', () async {
      container.read(pendingInviteProvider.notifier).set('first');
      clipboard.hasUrlResult = true;
      await restorer().check();
      expect(clipboard.checks, 0);
      expect(status(), InvitePasteStatus.hidden);
    });

    test('貼り付けた招待リンクを、開く予定の招待にする', () {
      restorer().receive(' https://orto.example.com/invite/friend\n');
      expect(pending(), 'friend');
      expect(status(), InvitePasteStatus.received);
    });

    test('貼り付けたのが招待リンクでなければ、そう知らせる', () {
      restorer().receive('https://example.com/invite/friend');
      expect(pending(), isNull);
      expect(status(), InvitePasteStatus.notInvite);
    });

    test('グループの招待リンクも引き継ぐ（機能仕様書4.7.2.5）', () {
      const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJ0123_-x';
      restorer().receive('https://orto.example.com/group/$token');
      expect(container.read(pendingGroupInviteProvider), token);
      expect(pending(), isNull);
      expect(status(), InvitePasteStatus.received);
    });

    test('貼り付けボタンの本文は、最上位のProviderが受け取る', () async {
      container.listen(inviteClipboardInitProvider, (_, _) {});
      clipboard.paste('https://orto.example.com/invite/friend');
      await Future<void>.delayed(Duration.zero);
      expect(pending(), 'friend');
    });

    test('アプリを開いたリンクは、httpsでもカスタムURLスキームでも開く予定の招待にする', () async {
      const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJ0123_-x';
      final links = StreamController<Uri>();
      addTearDown(links.close);
      final linkContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          inviteLinkServiceProvider.overrideWithValue(_FakeLinkService(links.stream)),
        ],
      );
      addTearDown(linkContainer.dispose);
      linkContainer.listen(inviteLinkInitProvider, (_, _) {});

      links.add(Uri.parse('orto://group/$token'));
      await Future<void>.delayed(Duration.zero);
      expect(linkContainer.read(pendingGroupInviteProvider), token);

      links.add(Uri.parse('orto://invite/friend'));
      await Future<void>.delayed(Duration.zero);
      expect(linkContainer.read(pendingInviteProvider), 'friend');

      links.add(Uri.parse('https://orto.example.com/invite/other'));
      await Future<void>.delayed(Duration.zero);
      expect(linkContainer.read(pendingInviteProvider), 'other');

      // 別の環境のスキームは受け付けない
      links.add(Uri.parse('orto-dev://invite/devuser'));
      await Future<void>.delayed(Duration.zero);
      expect(linkContainer.read(pendingInviteProvider), 'other');
    });
  });
}

class _FakeLinkService implements InviteLinkService {
  _FakeLinkService(this.links);

  @override
  final Stream<Uri> links;
}

class _FakeClipboardService implements InviteClipboardService {
  bool hasUrlResult = false;
  int checks = 0;
  final _pasted = StreamController<String>.broadcast();

  void paste(String text) => _pasted.add(text);

  @override
  Future<bool> hasUrl() async {
    checks++;
    return hasUrlResult;
  }

  @override
  Stream<String> get pasted => _pasted.stream;
}

void _groupInviteLinkTests() {
  const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJ0123_-x';

  test('グループの招待リンクを作り、読み取れる', () {
    final link = InviteLinks.forGroup(token, AppFlavor.prod);
    expect(link, 'https://orto.example.com/group/$token');
    expect(InviteLinks.groupTokenFrom(Uri.parse(link), AppFlavor.prod), token);
    expect(InviteLinks.groupTokenFrom(Uri.parse('https://open.example.com/group/$token'), AppFlavor.prod), token);
  });

  test('別の環境・別のホスト・形式の違うリンクは読み取らない', () {
    String? read(String link) => InviteLinks.groupTokenFrom(Uri.parse(link), AppFlavor.prod);
    expect(read('https://orto-dev.example.com/group/$token'), isNull);
    expect(read('https://example.com/group/$token'), isNull);
    expect(read('http://orto.example.com/group/$token'), isNull);
    expect(read('https://orto.example.com/group/short'), isNull);
    expect(read('https://orto.example.com/group/$token/extra'), isNull);
  });

  test('友だちの招待リンクとグループの招待リンクを取り違えない', () {
    expect(InviteLinks.accountIdFrom(Uri.parse('https://orto.example.com/group/alice'), AppFlavor.prod), isNull);
    expect(InviteLinks.groupTokenFrom(Uri.parse('https://orto.example.com/invite/$token'), AppFlavor.prod), isNull);
  });

  group('カスタムURLスキームの招待リンク', () {
    test('環境ごとのスキームで組み立て、読み取れる', () {
      expect(InviteLinks.appSchemeForGroup(token, AppFlavor.prod), 'orto://group/$token');
      expect(InviteLinks.appSchemeForAccount('alice', AppFlavor.prod), 'orto://invite/alice');
      expect(InviteLinks.appSchemeForGroup(token, AppFlavor.dev), 'orto-dev://group/$token');
      expect(
        InviteLinks.groupTokenFrom(Uri.parse(InviteLinks.appSchemeForGroup(token, AppFlavor.prod)), AppFlavor.prod),
        token,
      );
      expect(
        InviteLinks.accountIdFrom(Uri.parse(InviteLinks.appSchemeForAccount('alice', AppFlavor.dev)), AppFlavor.dev),
        'alice',
      );
    });

    test('末尾のスラッシュ付き・以前のQRコードのorto://friend/も読み取る', () {
      expect(InviteLinks.groupTokenFrom(Uri.parse('orto://group/$token/'), AppFlavor.prod), token);
      expect(InviteLinks.accountIdFrom(Uri.parse('orto://invite/alice/'), AppFlavor.prod), 'alice');
      expect(InviteLinks.accountIdFrom(Uri.parse('orto://friend/alice'), AppFlavor.prod), 'alice');
    });

    test('形式の違うリンク・別のホストは読み取らない', () {
      expect(InviteLinks.groupTokenFrom(Uri.parse('orto://group/short'), AppFlavor.prod), isNull);
      expect(InviteLinks.groupTokenFrom(Uri.parse('orto://group/$token/extra'), AppFlavor.prod), isNull);
      expect(InviteLinks.groupTokenFrom(Uri.parse('orto://group'), AppFlavor.prod), isNull);
      expect(InviteLinks.accountIdFrom(Uri.parse('orto://invite/a%20b'), AppFlavor.prod), isNull);
      expect(InviteLinks.accountIdFrom(Uri.parse('orto://profile/alice'), AppFlavor.prod), isNull);
      expect(InviteLinks.accountIdFrom(Uri.parse('orto:///invite/alice'), AppFlavor.prod), isNull);
    });

    test('友だちとグループを取り違えない', () {
      expect(InviteLinks.accountIdFrom(Uri.parse('orto://group/alice'), AppFlavor.prod), isNull);
      expect(InviteLinks.groupTokenFrom(Uri.parse('orto://invite/$token'), AppFlavor.prod), isNull);
    });

    test('別の環境・別のスキームは読み取らない', () {
      expect(InviteLinks.groupTokenFrom(Uri.parse('orto-dev://group/$token'), AppFlavor.prod), isNull);
      expect(InviteLinks.groupTokenFrom(Uri.parse('orto://group/$token'), AppFlavor.dev), isNull);
      expect(InviteLinks.groupTokenFrom(Uri.parse('line://group/$token'), AppFlavor.prod), isNull);
      expect(InviteLinks.accountIdFrom(Uri.parse('ortox://invite/alice'), AppFlavor.prod), isNull);
    });

    test('アプリのスキャナーでも読む', () {
      final group = InviteLinks.qrInviteFrom('orto://group/$token', AppFlavor.prod) as GroupQrInvite;
      expect(group.token, token);
      final friend = InviteLinks.qrInviteFrom('orto://invite/alice', AppFlavor.prod) as FriendQrInvite;
      expect(friend.accountId, 'alice');
    });
  });

  group('アプリのスキャナーでQRコードを読む', () {
    QrInvite? read(String value) => InviteLinks.qrInviteFrom(value, AppFlavor.prod);

    test('グループの招待リンク（2つのドメインのどちらでも）を読む', () {
      expect((read(InviteLinks.groupQrData(token, AppFlavor.prod)) as GroupQrInvite).token, token);
      expect((read('https://open.example.com/group/$token') as GroupQrInvite).token, token);
      expect((read('https://orto.example.com/group/$token/') as GroupQrInvite).token, token);
    });

    test('友だちの招待リンク（2つのドメインのどちらでも）を読む', () {
      expect((read(InviteLinks.friendQrData('alice', AppFlavor.prod)) as FriendQrInvite).accountId, 'alice');
      expect((read('https://open.example.com/invite/alice') as FriendQrInvite).accountId, 'alice');
    });

    test('以前のorto://のQRコードも読む', () {
      expect((read('orto://group/$token') as GroupQrInvite).token, token);
      expect((read('orto://friend/alice') as FriendQrInvite).accountId, 'alice');
    });

    test('形は合うが中身の形式が違えば、中身をnullにする（グループは「この招待リンクは無効です」）', () {
      expect((read('orto://group/short') as GroupQrInvite).token, isNull);
      expect((read('https://orto.example.com/group/short') as GroupQrInvite).token, isNull);
      expect((read('orto://friend/a b') as FriendQrInvite).accountId, isNull);
    });

    test('招待でないQRコード・別の環境・別のドメイン・httpは読まない', () {
      expect(read('hello'), isNull);
      expect(read('https://example.com/group/$token'), isNull);
      expect(read('https://orto-dev.example.com/group/$token'), isNull);
      expect(read('http://orto.example.com/group/$token'), isNull);
      expect(read('https://orto.example.com/legal/terms'), isNull);
      expect(read('https://orto.example.com/'), isNull);
    });
  });
}
