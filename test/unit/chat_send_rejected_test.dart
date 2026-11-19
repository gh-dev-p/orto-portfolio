import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/chat/chat_repository.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/models/friend.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/chat/view_models/chat_viewmodel.dart';
import 'package:multi_id_msg/ui/friend/view_models/friend_providers.dart';
import 'package:multi_id_msg/ui/passcode/view_models/passcode_providers.dart';

/// 送信の回数制限のルールが拒否したときの、サーバーの応答と同じ例外
final _rejected = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

class _FakeChatRepository extends Fake implements ChatRepository {
  var failSend = true;
  final imageSend = Completer<void>();
  final sentTexts = <String>[];

  @override
  Stream<bool> watchChatRoomExists({required String accountId, required String chatRoomId}) => Stream.value(false);

  @override
  Stream<int> watchUnreadCount({required String accountId, required String chatRoomId}) => Stream.value(0);

  @override
  Future<void> sendMessage({
    required String chatRoomId,
    required String senderAccountId,
    required String? peerAccountId,
    required String text,
  }) async {
    if (failSend) throw _rejected;
    sentTexts.add(text);
  }

  @override
  String newMessageId(String chatRoomId) => 'img1';

  @override
  Future<void> sendImageMessage({
    required String chatRoomId,
    required String messageId,
    required String senderAccountId,
    required String? peerAccountId,
    required File file,
    ({int width, int height})? size,
    void Function(double progress)? onProgress,
  }) => imageSend.future;

  @override
  Future<void> sendStickerMessage({
    required String chatRoomId,
    required String senderAccountId,
    required String? peerAccountId,
    required String stickerPackId,
    required String stickerId,
  }) async {
    if (failSend) throw _rejected;
  }
}

void main() {
  const args = (chatRoomId: 'alice~bob', myAccountId: 'alice', peerAccountId: 'bob');
  late _FakeChatRepository repo;
  late ProviderContainer container;

  Future<ChatViewModel> open() async {
    container.listen(chatViewModelProvider(args), (_, _) {}, fireImmediately: true);
    await pumpEventQueue();
    return container.read(chatViewModelProvider(args).notifier);
  }

  setUp(() {
    repo = _FakeChatRepository();
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        friendsProvider.overrideWith((ref) => Stream.value(const <Friend>[])),
        accountByIdProvider.overrideWith((ref, accountId) => Stream<Account?>.value(null)),
        passcodeGuardStatusProvider.overrideWithValue(PasscodeGuardStatus.open),
      ],
    );
    addTearDown(container.dispose);
  });

  test('拒否されたテキストは送信失敗として残り、再送できる', () async {
    final viewModel = await open();

    expect(await viewModel.sendText('こんにちは'), ChatSendResult.failed);
    final failed = container.read(chatViewModelProvider(args)).messages.value!.single;
    expect(failed.isFailed, isTrue);
    expect(failed.text, 'こんにちは');

    repo.failSend = false;
    expect(await viewModel.retry(failed), ChatSendResult.sent);
    expect(repo.sentTexts, ['こんにちは']);
    expect(container.read(chatViewModelProvider(args)).messages.value, isEmpty);
  });

  test('画像は送信の操作の直後に送信中の吹き出しを出し、失敗したら再送できる形で残す', () async {
    final viewModel = await open();

    // 大きさの読み取りなど、最初の待ちより前に吹き出しが出る。
    final result = viewModel.sendImage(File('/nonexistent/image.jpg'));
    final uploading = container.read(chatViewModelProvider(args)).messages.value!.single;
    expect(uploading.isUploadingImage, isTrue);
    expect(uploading.localImagePath, '/nonexistent/image.jpg');

    repo.imageSend.future.ignore();
    repo.imageSend.completeError(_rejected);
    expect(await result, ChatSendResult.failed);
    final failed = container.read(chatViewModelProvider(args)).messages.value!.single;
    expect(failed.isFailed, isTrue);
    expect(failed.isUploadingImage, isFalse);
  });

  test('拒否された後も送信中のままにならない', () async {
    final viewModel = await open();

    await viewModel.sendText('こんにちは');

    expect(container.read(chatViewModelProvider(args)).sending, isFalse);
  });

  test('拒否されたスタンプは失敗を返す', () async {
    final viewModel = await open();

    expect(await viewModel.sendSticker(stickerPackId: 'pack', stickerId: '01'), ChatSendResult.failed);
  });
}
