// DocumentSnapshotはsealedだが、カーソルとして受け渡すだけの偽物を作るためにテストでのみ継承する。
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/message.dart';
import 'package:multi_id_msg/domain/models/message_history.dart';
import 'package:multi_id_msg/data/repositories/chat/chat_repository.dart';
import 'package:multi_id_msg/ui/chat/view_models/chat_providers.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/config/provider_retry.dart';

/// 秒単位で時刻をずらしたメッセージ。idは`m<秒>`。[pending]はサーバー時刻が未確定の状態。
Message _msg(int sec, {bool pending = false}) => Message(
  id: 'm$sec',
  senderId: 'a',
  text: 't$sec',
  createdAt: pending ? null : DateTime(2026, 9, 21, 12, 0, sec),
  readBy: const [],
);

List<Message> _range(int from, int to) => [for (var i = from; i <= to; i++) _msg(i)];

List<String> _ids(Iterable<Message> messages) => [for (final m in messages) m.id];

List<String> _idsOf(int from, int to) => [for (var i = from; i <= to; i++) 'm$i'];

/// Firestoreのドキュメントの代わり。カーソルとして受け渡すだけで、メソッドは呼ばれない。
class _FakeDoc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this.id);

  @override
  final String id;
}

MessagePage _page(List<Message> messages, {bool fromCache = false}) => MessagePage(
  messages: messages,
  cursor: messages.isEmpty ? null : _FakeDoc(messages.first.id),
  isFromCache: fromCache,
);

class _FakeChatRepository extends Fake implements ChatRepository {
  final live = StreamController<MessagePage>();
  final olderPages = <MessagePage>[];
  final olderCursors = <String>[];
  Object? olderError;
  DateTime? liveSince;
  DateTime? olderSince;

  @override
  Stream<MessagePage> watchLatestMessages(
    String chatRoomId, {
    int limit = ChatRepository.messagePageSize,
    DateTime? since,
  }) {
    liveSince = since;
    return live.stream;
  }

  @override
  Future<MessagePage> fetchOlderMessages(
    String chatRoomId, {
    required Object cursor,
    int limit = ChatRepository.messagePageSize,
    DateTime? since,
  }) async {
    olderSince = since;
    olderCursors.add((cursor as _FakeDoc).id);
    final error = olderError;
    if (error != null) throw error;
    return olderPages.removeAt(0);
  }
}

void main() {
  group('MessageHistoryAccumulator', () {
    late MessageHistoryAccumulator history;
    setUp(() => history = MessageHistoryAccumulator(pageSize: 3));

    test('窓が満杯でなければ、過去分なしとして全件を返す', () {
      history.applyLive(_range(1, 2), cursor: _FakeDoc('m1'), fromCache: false);

      expect(_ids(history.messages), ['m1', 'm2']);
      expect(history.hasMore, isFalse);
    });

    test('窓が満杯なら、過去分ありとして扱いカーソルを保持する', () {
      final cursor = _FakeDoc('m1');
      history.applyLive(_range(1, 3), cursor: cursor, fromCache: false);

      expect(history.hasMore, isTrue);
      expect(history.cursor, same(cursor));
    });

    test('新着で窓がずれても、押し出された古いメッセージは表示に残り、カーソルは最初のまま', () {
      final cursor = _FakeDoc('m1');
      history.applyLive(_range(1, 3), cursor: cursor, fromCache: false);
      history.applyLive(_range(2, 4), cursor: _FakeDoc('m2'), fromCache: false);
      history.applyLive(_range(3, 5), cursor: _FakeDoc('m3'), fromCache: false);

      expect(_ids(history.messages), _idsOf(1, 5));
      expect(history.cursor, same(cursor));
      expect(history.hasMore, isTrue);
    });

    test('窓の内側で送信取消されたメッセージは消え、押し出しとは区別される', () {
      history.applyLive(_range(2, 4), cursor: _FakeDoc('m2'), fromCache: false);
      // m3を送信取消。窓には、その分を埋めるより古いm1が入る。
      history.applyLive([_msg(1), _msg(2), _msg(4)], cursor: _FakeDoc('m1'), fromCache: false);

      expect(_ids(history.messages), ['m1', 'm2', 'm4']);
    });

    test('窓の最も古いメッセージが送信取消されても、押し出しと誤認して残さない', () {
      history.applyLive(_range(2, 4), cursor: _FakeDoc('m2'), fromCache: false);
      // m2を送信取消。窓にはより古いm1が入る（m2は窓の先頭m1より新しい＝削除）。
      history.applyLive([_msg(1), _msg(3), _msg(4)], cursor: _FakeDoc('m1'), fromCache: false);

      expect(_ids(history.messages), ['m1', 'm3', 'm4']);
    });

    test('窓が満杯でない（全件が窓内の）ときの送信取消は、そのまま消える', () {
      history.applyLive(_range(1, 2), cursor: _FakeDoc('m1'), fromCache: false);
      history.applyLive([_msg(2)], cursor: _FakeDoc('m2'), fromCache: false);

      expect(_ids(history.messages), ['m2']);
    });

    test('過去ページを追加すると先頭側に並び、ページが満杯なら引き続き過去分あり', () {
      history.applyLive(_range(4, 6), cursor: _FakeDoc('m4'), fromCache: false);
      final olderCursor = _FakeDoc('m1');
      history.addOlder(_range(1, 3), cursor: olderCursor);

      expect(_ids(history.messages), _idsOf(1, 6));
      expect(history.hasMore, isTrue);
      expect(history.cursor, same(olderCursor));
    });

    test('過去ページが満杯未満なら、これ以上過去分なし', () {
      history.applyLive(_range(4, 6), cursor: _FakeDoc('m4'), fromCache: false);
      history.addOlder([_msg(3)], cursor: _FakeDoc('m3'));

      expect(_ids(history.messages), _idsOf(3, 6));
      expect(history.hasMore, isFalse);
    });

    test('過去ページ取得後に窓が新しい側へずれても、境界カーソルは動かない', () {
      history.applyLive(_range(4, 6), cursor: _FakeDoc('m4'), fromCache: false);
      final olderCursor = _FakeDoc('m1');
      history.addOlder(_range(1, 3), cursor: olderCursor);
      history.applyLive(_range(5, 7), cursor: _FakeDoc('m5'), fromCache: false);

      expect(_ids(history.messages), _idsOf(1, 7));
      expect(history.cursor, same(olderCursor));
    });

    test('ライブ側と重複する過去分は、二重に表示しない', () {
      history.applyLive(_range(4, 6), cursor: _FakeDoc('m4'), fromCache: false);
      // 窓内の送信取消で窓が古い側へ伸びた後に、同じメッセージを過去ページが返した場合。
      history.addOlder([_msg(3), _msg(4)], cursor: _FakeDoc('m3'));

      expect(_ids(history.messages), ['m3', 'm4', 'm5', 'm6']);
    });

    test('キャッシュ由来の暫定の窓は、サーバー確定の窓で境界を置き換える', () {
      history.applyLive(_range(8, 9), cursor: _FakeDoc('m8'), fromCache: true);
      expect(history.hasMore, isFalse);

      final serverCursor = _FakeDoc('m7');
      history.applyLive(_range(7, 9), cursor: serverCursor, fromCache: false);

      expect(history.hasMore, isTrue);
      expect(history.cursor, same(serverCursor));
    });

    test('キャッシュ由来の窓に含まれていた古いメッセージを、押し出しと誤認して残さない', () {
      // キャッシュには、サーバー側で既に取消済みの古いメッセージm1が残っていた場合。
      history.applyLive([_msg(1), _msg(9)], cursor: _FakeDoc('m1'), fromCache: true);
      history.applyLive(_range(7, 9), cursor: _FakeDoc('m7'), fromCache: false);

      expect(_ids(history.messages), _idsOf(7, 9));
    });

    test('サーバー時刻が未確定の送信直後のメッセージは、末尾に置かれ、押し出し扱いにならない', () {
      history.applyLive(_range(1, 3), cursor: _FakeDoc('m1'), fromCache: false);
      history.applyLive([_msg(2), _msg(3), _msg(4, pending: true)], cursor: _FakeDoc('m2'), fromCache: false);
      // 確定後に時刻が入る。
      history.applyLive(_range(2, 4), cursor: _FakeDoc('m2'), fromCache: false);

      expect(_ids(history.messages), _idsOf(1, 4));
    });
  });

  group('messagesProvider', () {
    // Notifierのページ件数は本番値（ChatRepository.messagePageSize）固定のため、窓もその件数で組む。
    const n = ChatRepository.messagePageSize;
    late _FakeChatRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = _FakeChatRepository();
      container = ProviderContainer(retry: noProviderRetry, overrides: [chatRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(() {
        container.dispose();
        repo.live.close();
      });
    });

    /// 直近の窓（満杯）として、m[n+1]〜m[2n]を初回結果に流す。
    Future<MessageHistory> firstLoad([List<Message>? messages]) async {
      final loaded = container.read(messagesProvider((chatRoomId: 'room', since: null)).future);
      repo.live.add(_page(messages ?? _range(n + 1, 2 * n)));
      return loaded;
    }

    MessageHistory current() => container.read(messagesProvider((chatRoomId: 'room', since: null))).requireValue;
    MessagesNotifier notifier() => container.read(messagesProvider((chatRoomId: 'room', since: null)).notifier);

    test('初回は直近の窓を返し、満杯なら過去分ありとなる', () async {
      final history = await firstLoad();

      expect(_ids(history.messages), _idsOf(n + 1, 2 * n));
      expect(history.hasMore, isTrue);
    });

    test('初回の窓が満杯未満なら、過去分なし', () async {
      final history = await firstLoad(_range(1, 3));

      expect(history.hasMore, isFalse);
    });

    test('loadMoreで、現在の最古のメッセージを起点に過去のページを取得して加える', () async {
      await firstLoad();
      repo.olderPages.add(_page(_range(1, n)));

      await notifier().loadMore();

      expect(repo.olderCursors, ['m${n + 1}']);
      expect(_ids(current().messages), _idsOf(1, 2 * n));
      expect(current().hasMore, isTrue);
    });

    test('過去分が尽きたらhasMoreがfalseになり、以後loadMoreは取得しない', () async {
      await firstLoad();
      repo.olderPages.add(_page([_msg(n)]));

      await notifier().loadMore();
      await notifier().loadMore();

      expect(repo.olderCursors, hasLength(1));
      expect(current().hasMore, isFalse);
    });

    test('取得中のloadMoreの重複呼び出しは、1回だけ取得する', () async {
      await firstLoad();
      repo.olderPages.add(_page(_range(1, n)));

      await Future.wait([notifier().loadMore(), notifier().loadMore()]);

      expect(repo.olderCursors, hasLength(1));
    });

    test('過去分の取得に失敗しても、表示中の履歴は変わらず、次回再試行できる', () async {
      await firstLoad();

      repo.olderError = Exception('offline');
      await notifier().loadMore();
      expect(_ids(current().messages), _idsOf(n + 1, 2 * n));

      repo.olderError = null;
      repo.olderPages.add(_page(_range(1, n)));
      await notifier().loadMore();
      expect(_ids(current().messages), _idsOf(1, 2 * n));
    });

    test('ライブ購読の更新が、追加取得した過去分を保ったまま反映される', () async {
      await firstLoad();
      repo.olderPages.add(_page(_range(1, n)));
      await notifier().loadMore();

      // 新着で窓が1件ずれる。
      repo.live.add(_page(_range(n + 2, 2 * n + 1)));
      await Future<void>.delayed(Duration.zero);

      expect(_ids(current().messages), _idsOf(1, 2 * n + 1));
    });

    test('初回の取得に失敗したらエラー状態になる', () async {
      final loaded = container.read(messagesProvider((chatRoomId: 'room', since: null)).future);
      repo.live.addError(Exception('permission-denied'));

      await expectLater(loaded, throwsException);
    });
  });
}
