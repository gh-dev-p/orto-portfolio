import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/account/active_account_repository.dart';
import 'package:multi_id_msg/data/repositories/friend/friend_request_repository.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/models/blocked_account.dart';
import 'package:multi_id_msg/domain/models/friend.dart';
import 'package:multi_id_msg/domain/models/friend_request.dart';
import 'package:multi_id_msg/domain/models/notification_target.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/block/view_models/block_providers.dart';
import 'package:multi_id_msg/ui/friend/view_models/friend_providers.dart';
import 'package:multi_id_msg/ui/friend/view_models/friend_request_providers.dart';
import 'package:multi_id_msg/ui/profile/view_models/friend_profile_viewmodel.dart';

// 友だち申請（機能仕様書4.3.8）のアプリ側の判定

class _FakeActiveAccountRepository implements ActiveAccountRepository {
  @override
  String? read() => 'me';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFriendRequestRepository implements FriendRequestRepository {
  final sent = <Map<String, String>>[];
  final responded = <(String, bool)>[];
  bool acceptOnSend = false;
  FriendRequestFailure? failure;

  @override
  Future<bool> send({required String accountId, required String chatRoomId, required String targetAccountId}) async {
    if (failure != null) throw FriendRequestException(failure!);
    sent.add({'accountId': accountId, 'chatRoomId': chatRoomId, 'targetAccountId': targetAccountId});
    return acceptOnSend;
  }

  @override
  Future<void> respond({required String accountId, required String senderAccountId, required bool accept}) async {
    if (failure != null) throw FriendRequestException(failure!);
    responded.add((senderAccountId, accept));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _now = DateTime(2026, 11, 16, 12);

FriendRequest _received(String sender, {DateTime? expiresAt}) =>
    FriendRequest(senderAccountId: sender, chatRoomId: 'g1', groupName: 'ボドゲ会', expiresAt: expiresAt);

void main() {
  group('期限', () {
    test('期限が無い（オフ会グループ）・期限前なら有効、期限を過ぎたら無いものとする', () {
      expect(_received('a').isLiveAt(_now), isTrue);
      expect(_received('a', expiresAt: _now.add(const Duration(seconds: 1))).isLiveAt(_now), isTrue);
      expect(_received('a', expiresAt: _now).isLiveAt(_now), isFalse);
      expect(
        SentFriendRequest(receiverAccountId: 'a', expiresAt: _now.subtract(const Duration(days: 1))).isLiveAt(_now),
        isFalse,
      );
      expect(const SentFriendRequest(receiverAccountId: 'a').isLiveAt(_now), isTrue);
    });
  });

  test('Cloud Functionsのエラーの理由を読み分ける', () {
    expect(FriendRequestFailure.fromValue('read-only'), FriendRequestFailure.readOnly);
    expect(FriendRequestFailure.fromValue('not-member'), FriendRequestFailure.notMember);
    expect(FriendRequestFailure.fromValue('request-invalid'), FriendRequestFailure.requestInvalid);
    expect(FriendRequestFailure.fromValue('???'), FriendRequestFailure.unknown);
    expect(FriendRequestFailure.fromValue(null), FriendRequestFailure.unknown);
  });

  test('友だち申請の通知は、トークではなく友だち申請を開く', () {
    final target = NotificationTarget.fromData({'type': 'friend_request', 'accountId': 'me', 'chatRoomId': 'g1'})!;
    expect(target.isFriendRequest, isTrue);
    expect(target.isGroupInvite, isFalse);
    final invite = NotificationTarget.fromData({'type': 'group_invite', 'accountId': 'me', 'chatRoomId': 'g1'})!;
    expect(target == invite, isFalse);
  });

  group('FRI-01に出す申請', () {
    late StreamController<List<FriendRequest>> received;
    late ProviderContainer container;

    setUp(() async {
      received = StreamController<List<FriendRequest>>.broadcast();
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          activeAccountRepositoryProvider.overrideWithValue(_FakeActiveAccountRepository()),
          friendRequestClockProvider.overrideWithValue(() => _now),
          receivedFriendRequestsProvider.overrideWith((ref, accountId) => received.stream),
          accountByIdProvider.overrideWith(
            (ref, id) => Stream.value(Account(id: id, displayName: id, isDeleted: id == 'deleted')),
          ),
          blockedAccountsProvider.overrideWith(
            (ref) => Stream.value([BlockedAccount(blockedAccountId: 'blocked', blockedAt: _now)]),
          ),
          blockedByPeerProvider.overrideWith((ref, id) async => id == 'blocker'),
        ],
      );
      addTearDown(container.dispose);
      container.listen(visibleFriendRequestsProvider, (_, _) {});
      await pumpEventQueue();
    });

    test('期限切れ・退会済み・自分がブロックした相手・自分をブロックした相手からの申請は出さない', () async {
      received.add([
        _received('ok'),
        _received('expired', expiresAt: _now.subtract(const Duration(minutes: 1))),
        _received('deleted'),
        _received('blocked'),
        _received('blocker'),
        _received('later', expiresAt: _now.add(const Duration(days: 29))),
      ]);
      await pumpEventQueue();
      expect(container.read(visibleFriendRequestsProvider).map((r) => r.senderAccountId), ['ok', 'later']);
    });

    test('届いていなければ空', () async {
      received.add(const []);
      await pumpEventQueue();
      expect(container.read(visibleFriendRequestsProvider), isEmpty);
    });
  });

  group('PRO-01の友だち申請', () {
    late StreamController<List<FriendRequest>> received;
    late StreamController<List<SentFriendRequest>> sent;
    late _FakeFriendRequestRepository repository;
    late ProviderContainer container;
    const args = (accountId: 'peer', myAccountId: 'me', groupChatRoomId: 'g1');

    setUp(() async {
      received = StreamController<List<FriendRequest>>.broadcast();
      sent = StreamController<List<SentFriendRequest>>.broadcast();
      repository = _FakeFriendRequestRepository();
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          activeAccountRepositoryProvider.overrideWithValue(_FakeActiveAccountRepository()),
          friendRequestClockProvider.overrideWithValue(() => _now),
          friendRequestRepositoryProvider.overrideWithValue(repository),
          receivedFriendRequestsProvider.overrideWith((ref, accountId) => received.stream),
          sentFriendRequestsProvider.overrideWith((ref, accountId) => sent.stream),
          accountByIdProvider.overrideWith((ref, id) => Stream.value(Account(id: id, displayName: id))),
          friendsProvider.overrideWith((ref) => Stream.value(const <Friend>[])),
        ],
      );
      addTearDown(container.dispose);
      container.listen(friendProfileViewModelProvider(args), (_, _) {});
      container.listen(
        friendProfileViewModelProvider((accountId: 'peer', myAccountId: 'me', groupChatRoomId: null)),
        (_, _) {},
      );
      received.add(const []);
      sent.add(const []);
      await pumpEventQueue();
    });

    FriendRequestStatus status() => container.read(friendProfileViewModelProvider(args)).requestStatus;

    test('まだ申請していなければ「友だち申請」、送ったら「申請中」、期限を過ぎたら戻る', () async {
      expect(status(), FriendRequestStatus.none);
      sent.add([SentFriendRequest(receiverAccountId: 'peer', expiresAt: _now.add(const Duration(days: 30)))]);
      await pumpEventQueue();
      expect(status(), FriendRequestStatus.pending);
      sent.add([SentFriendRequest(receiverAccountId: 'peer', expiresAt: _now.subtract(const Duration(seconds: 1)))]);
      await pumpEventQueue();
      expect(status(), FriendRequestStatus.none);
    });

    test('相手から届いていれば「承認する」（送った申請より優先）', () async {
      sent.add(const [SentFriendRequest(receiverAccountId: 'peer')]);
      received.add([_received('peer')]);
      await pumpEventQueue();
      expect(status(), FriendRequestStatus.received);
    });

    test('ほかの相手への申請は関係しない', () async {
      sent.add(const [SentFriendRequest(receiverAccountId: 'other')]);
      received.add([_received('other')]);
      await pumpEventQueue();
      expect(status(), FriendRequestStatus.none);
    });

    test('グループのメンバーの画面以外から開いたときは、申請の状態を見ない', () async {
      received.add([_received('peer')]);
      await pumpEventQueue();
      final state = container.read(
        friendProfileViewModelProvider((accountId: 'peer', myAccountId: 'me', groupChatRoomId: null)),
      );
      expect(state.requestStatus, FriendRequestStatus.none);
    });

    test('申請はそのグループと相手を指定して送る', () async {
      final accepted = await container.read(friendProfileViewModelProvider(args).notifier).sendFriendRequest();
      expect(accepted, isFalse);
      expect(repository.sent, [
        {'accountId': 'me', 'chatRoomId': 'g1', 'targetAccountId': 'peer'},
      ]);
      expect(container.read(friendProfileViewModelProvider(args)).adding, isFalse);
    });

    test('申請の失敗は理由つきで投げ、実行中の表示を戻す', () async {
      repository.failure = FriendRequestFailure.notMember;
      await expectLater(
        container.read(friendProfileViewModelProvider(args).notifier).sendFriendRequest(),
        throwsA(isA<FriendRequestException>().having((e) => e.failure, 'failure', FriendRequestFailure.notMember)),
      );
      expect(container.read(friendProfileViewModelProvider(args)).adding, isFalse);
    });

    test('承認は相手からの申請に答える', () async {
      await container.read(friendProfileViewModelProvider(args).notifier).acceptFriendRequest();
      expect(repository.responded, [('peer', true)]);
    });
  });
}
