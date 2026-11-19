import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/blocked_account.dart';
import 'package:multi_id_msg/domain/models/chat_list_sections.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';
import 'package:multi_id_msg/domain/models/friend.dart';
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
import 'package:multi_id_msg/ui/block/view_models/block_providers.dart';
import 'package:multi_id_msg/ui/chat/view_models/chat_providers.dart';
import 'package:multi_id_msg/ui/friend/view_models/friend_providers.dart';
import 'package:multi_id_msg/config/provider_retry.dart';

ChatListEntry _room(String peerId) => ChatListEntry(
  chatRoomId: buildChatRoomId('me', peerId),
  peerAccountId: peerId,
  lastMessage: LastMessagePreview(messageId: 'm1', text: 'hi', senderId: peerId),
);

Friend _friend(String id) => Friend(friendAccountId: id, addedAt: DateTime(2026, 9, 1));

/// 端末内の保存値（SharedPreferences）を使わずに、最初からアクティブアカウントを固定する。
class _FixedActiveAccount extends ActiveAccountNotifier {
  @override
  String? build() => 'me';
}

ProviderContainer _container({required Stream<List<BlockedAccount>> blocked}) {
  return ProviderContainer(
    retry: noProviderRetry,
    overrides: [
      activeAccountIdProvider.overrideWith(_FixedActiveAccount.new),
      chatRoomsProvider.overrideWith((ref) => Stream.value([_room('bob'), _room('dave')])),
      friendsProvider.overrideWith((ref) => Stream.value([_friend('bob')])),
      blockedAccountsProvider.overrideWith((ref) => blocked),
      blockedByPeerProvider.overrideWith((ref, peerId) => false),
    ],
  );
}

/// トーク一覧の区分けを取得する。Riverpod 3では、誰も監視していないProviderは一時停止し、依存先のStreamProviderも
/// 値を流さない（アプリではHomeShell等が監視している）。そのため、監視しながら結果を待つ。
Future<ChatListSections> _read(ProviderContainer container) =>
    container.listen(chatListSectionsProvider.future, (_, _) {}).read();

List<String> _peers(Iterable<ChatListEntry> rooms) => [for (final r in rooms) r.peerAccountId!];

void main() {
  test('友だちは通常、友だちでない相手はリクエストに振り分けられる', () async {
    final container = _container(blocked: Stream.value(const []));
    addTearDown(container.dispose);

    final sections = await _read(container);
    expect(_peers(sections.normal), ['bob']);
    expect(_peers(sections.requests), ['dave']);
  });

  test('ブロックリストの取得に失敗しても、トーク一覧自体は取得できる', () async {
    // firestore.rulesが未デプロイなどでblockedAccountsを読めない場合（permission-denied）。
    final container = _container(blocked: Stream.error(Exception('permission-denied')));
    addTearDown(container.dispose);

    final sections = await _read(container);
    expect(_peers(sections.normal), ['bob']);
    expect(_peers(sections.requests), ['dave']);
  });

  test('自分がブロックした相手のルームは、通常にもリクエストにも出ない', () async {
    final container = _container(blocked: Stream.value([BlockedAccount(blockedAccountId: 'dave', blockedAt: DateTime(2026, 9, 20))]));
    addTearDown(container.dispose);

    final sections = await _read(container);
    expect(_peers(sections.normal), ['bob']);
    expect(sections.requests, isEmpty);
  });
}
