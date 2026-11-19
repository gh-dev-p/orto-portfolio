import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gal/gal.dart';

import '../../../domain/models/chat_room.dart';
import '../../../domain/models/firestore_values.dart';
import '../../../domain/models/image_save_result.dart';
import '../../../domain/models/message.dart';
import '../../../domain/models/sticker_pack.dart';
import '../../services/common/firestore_paths.dart';
import '../../services/common/storage_paths.dart';
import '../../services/chat/chat_image_storage_service.dart';
import '../../services/chat/photo_library_service.dart';
import '../../../utils/image_size.dart';

export '../../../domain/models/image_save_result.dart';

// ============================================================
// 関数
// ============================================================

/// [items]を、1回のバッチで書ける件数（[maxWrites]）ごとに分ける
/// 最後のバッチには別の書き込みが[extraWritesInLast]件加わるため、その分を空けて区切る（[items]が空でも、最後のバッチ用に空の組を1つ返す）
List<List<T>> splitForBatches<T>(List<T> items, {required int extraWritesInLast, required int maxWrites}) {
  final chunks = <List<T>>[];
  var start = 0;
  while (items.length - start + extraWritesInLast > maxWrites) {
    chunks.add(items.sublist(start, start + maxWrites));
    start += maxWrites;
  }
  chunks.add(items.sublist(start));
  return chunks;
}

/// 送信バッチに含める、カウンターの書き込み（データ設計書3.1.2）
/// [messageKey]は[sendCounterMessageKey]の値。オフライン・複数端末でも値がずれないよう、今の値を読まずに+1する
Map<String, dynamic> sendCounterWrite(String messageKey) => {
  'counterId': 'current',
  'count': FieldValue.increment(1),
  'lastMessageKey': messageKey,
};

/// カウンターに書く、このメッセージを表すキー（ルールが、作るメッセージとの一致を確かめる）
String sendCounterMessageKey({required String chatRoomId, required String messageId}) => '$chatRoomId/$messageId';

/// カウンターの件数を0に戻す時期か（[baseAt]が未設定、または24時間以上前）
/// 間隔はfirestore.rulesのsendCountersの巻き戻しの条件と同じ。変更時は両方を更新すること
bool needsSendCounterReset(DateTime? baseAt, {required DateTime now}) {
  return baseAt == null || now.difference(baseAt) >= const Duration(hours: 24);
}

// ============================================================
// 状態クラス
// ============================================================

/// メッセージ1回分の取得結果
class MessagePage {
  const MessagePage({required this.messages, required this.cursor, this.isFromCache = false});

  /// 取得したメッセージ（古い順）
  final List<Message> messages;

  /// この取得結果で最も古いメッセージの位置
  /// 次のページを取得するときに[ChatRepository.fetchOlderMessages]へ渡す（中身はリポジトリだけが扱う。空ならnull）
  final Object? cursor;

  /// 端末のキャッシュから読んだ結果か
  /// サーバーで確定する前は、中身が欠けていることがある
  final bool isFromCache;
}

// ============================================================
// リポジトリ
// ============================================================

/// トークのリポジトリ
/// トーク一覧・メッセージ（Firestore）と、トークの画像（Cloud Storage・端末のアルバム）を扱う
///
/// 機能仕様書：4.4.1〜4.4.5 / データ設計書：3.2.4・3.3・3.3.1
class ChatRepository {
  ChatRepository(this._paths, this._imageStorageService, this._photoLibraryService, this._currentUid);

  // ---- 状態・初期化 ----

  /// Firestoreのパス（接続先）
  final FirestorePaths _paths;

  /// トークの画像のサービス（Cloud Storage）
  final ChatImageStorageService _imageStorageService;

  /// 端末のアルバムのサービス
  final PhotoLibraryService _photoLibraryService;

  /// ログイン中のuid（送信の回数制限のカウンターに使う）
  final String? Function() _currentUid;

  /// uidごとの、カウンターを最後に確かめた時刻（[_refreshSendCounter]）
  final _sendCounterCheckedAt = <String, DateTime>{};

  // ---- トーク一覧 ----

  /// アカウント[accountId]のトーク一覧を、新しい順に監視する（機能仕様書4.4.1.1）
  /// 自分のアカウントの`chatList`だけを読み、uidでは検索しない（データ設計書1章）
  Stream<List<ChatListEntry>> watchChatList(String accountId) {
    return _paths.chatList(accountId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => parseSkippingBroken(snap.docs, ChatListEntry.fromFirestore));
  }

  /// アカウント[accountId]のトーク一覧を1回だけ取得する（ACC-01の未読合計バッジ用、データ設計書3.2.4）
  /// 監視はせず、ACC-01を開いたときにだけ呼ぶ
  Future<List<ChatListEntry>> fetchChatList(String accountId) async {
    final snap = await _paths.chatList(accountId).get();
    return parseSkippingBroken(snap.docs, ChatListEntry.fromFirestore);
  }

  /// トークがメッセージを読みに行ってよいか（ルームがあるか）を監視する（データ設計書3.3）
  /// ルームは最初の送信時に作られ、ルームが無いとメッセージの読み取りはルールで拒否される
  ///
  /// 自分の`chatList`はルームと同時（自分が作った場合）か、ルームの作成後（相手が作った場合、Cloud Functions）に作られるため、サーバーで確定した`chatList`があればルームもある。`chatList`が無い場合は、Cloud Functionsの遅れ・失敗に備えてルーム自体の有無も確かめる
  /// 送信直後の端末内の書き込み（サーバー未確定）ではtrueにしない（サーバーでルームが作られる前にメッセージの監視を始めると、権限エラーになるため）
  Stream<bool> watchChatRoomExists({required String accountId, required String chatRoomId}) {
    return _paths.chatList(accountId)
        .doc(chatRoomId)
        .snapshots(includeMetadataChanges: true)
        .where((doc) => !doc.metadata.hasPendingWrites)
        .asyncMap((doc) async {
          if (doc.exists) return true;
          final room = await _paths.chatRoom(chatRoomId).get();
          return room.exists;
        })
        .distinct();
  }

  /// 自分の`chatList`にあるこのトークの未読数（メッセージとリアクションの合計）を監視する
  /// トークを開いている間に届いたメッセージ・リアクションを既読にするのに使う（トークが一覧に無ければ0）
  Stream<int> watchUnreadCount({required String accountId, required String chatRoomId}) {
    return _paths.chatList(accountId).doc(chatRoomId).snapshots().map((doc) {
      final data = doc.data();
      return ((data?['unreadCount'] as num?)?.toInt() ?? 0) + unreadReactionCount(data);
    }).distinct();
  }

  // ---- メッセージの読み込み ----

  /// トークが1回に取得・監視するメッセージの件数
  static const messagePageSize = 50;

  /// 直近[limit]件のメッセージを監視する（機能仕様書4.4.3.4）
  /// それより過去は[fetchOlderMessages]で追加で取得する
  ///
  /// グループでは[since]に参加した時刻を渡す（参加前のメッセージは読めず、条件の無いクエリはルールで拒否される。データ設計書6章）
  Stream<MessagePage> watchLatestMessages(String chatRoomId, {int limit = messagePageSize, DateTime? since}) {
    return _newestFirst(chatRoomId, since: since)
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map(_toMessagePage);
  }

  /// [cursor]より過去のメッセージを[limit]件取得する
  /// [cursor]は、これまでに取得した最も古いメッセージの位置（[MessagePage.cursor]）
  Future<MessagePage> fetchOlderMessages(
    String chatRoomId, {
    required Object cursor,
    int limit = messagePageSize,
    DateTime? since,
  }) async {
    final snap = await _newestFirst(chatRoomId, since: since)
        .startAfterDocument(cursor as DocumentSnapshot<Map<String, dynamic>>)
        .limit(limit)
        .get();
    return _toMessagePage(snap);
  }

  /// アカウント[accountId]がグループに参加した時刻（データ設計書8.2）
  /// 参加していなければ読み取りがルールで拒否される。`members`に無ければnull
  Future<DateTime?> fetchGroupJoinedAt({required String chatRoomId, required String accountId}) async {
    final doc = await _paths.chatRoomMembers(chatRoomId).doc(accountId).get();
    return (doc.data()?['joinedAt'] as Timestamp?)?.toDate();
  }

  /// メッセージを新しい順に並べるクエリ（[since]があれば、それ以降のメッセージだけ）
  Query<Map<String, dynamic>> _newestFirst(String chatRoomId, {DateTime? since}) {
    final messages = _paths.messages(chatRoomId);
    final query = since == null
        ? messages
        : messages.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    return query.orderBy('createdAt', descending: true);
  }

  /// クエリの結果を、メッセージ1回分の取得結果にする
  static MessagePage _toMessagePage(QuerySnapshot<Map<String, dynamic>> snap) {
    final docs = snap.docs;
    return MessagePage(
      // クエリは新しい順のため、画面表示用に古い順へ並べ替える。
      messages: parseSkippingBroken(docs.reversed, Message.fromFirestore),
      cursor: docs.isEmpty ? null : docs.last,
      isFromCache: snap.metadata.isFromCache,
    );
  }

  // ---- 送信 ----

  /// テキストを送信する（機能仕様書4.4.3.1）
  /// 書き込みはサーバーで確定する前から監視中のメッセージに現れるため、送信直後からトークに表示される
  Future<void> sendMessage({
    required String chatRoomId,
    required String senderAccountId,
    required String? peerAccountId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _commitMessage(
      chatRoomId: chatRoomId,
      senderAccountId: senderAccountId,
      peerAccountId: peerAccountId,
      messageRef: _paths.messages(chatRoomId).doc(),
      content: {'type': MessageType.text.value, 'text': trimmed},
    );
  }

  /// スタンプを送信する（機能仕様書4.4.8）
  /// 画像は送らず、パックとスタンプのIDだけをメッセージに載せる
  Future<void> sendStickerMessage({
    required String chatRoomId,
    required String senderAccountId,
    required String? peerAccountId,
    required String stickerPackId,
    required String stickerId,
  }) {
    return _commitMessage(
      chatRoomId: chatRoomId,
      senderAccountId: senderAccountId,
      peerAccountId: peerAccountId,
      messageRef: _paths.messages(chatRoomId).doc(),
      content: {'type': MessageType.sticker.value, 'stickerPackId': stickerPackId, 'stickerId': stickerId},
    );
  }

  /// 当日の定型連絡を送信する（オフ会グループのみ。機能仕様書4.7.8.11）
  /// 文言は送らず、中身の種類だけをメッセージに載せる。会の日でなければサーバーが拒む
  Future<void> sendMeetupStatusMessage({
    required String chatRoomId,
    required String senderAccountId,
    required MeetupStatus status,
  }) {
    return _commitMessage(
      chatRoomId: chatRoomId,
      senderAccountId: senderAccountId,
      peerAccountId: null,
      messageRef: _paths.messages(chatRoomId).doc(),
      content: {'type': MessageType.meetupStatus.value, 'meetupStatus': status.value},
    );
  }

  /// アルバムの作成・追加の案内を送る（機能仕様書4.4.9.2、データ設計書3.13）
  /// 1回の操作につき1件。通常のメッセージとして未読・通知・トーク一覧に反映される
  Future<void> sendAlbumNotice({
    required String chatRoomId,
    required String senderAccountId,
    required String? peerAccountId,
    required String albumId,
    required String albumName,
    required AlbumEvent event,
    required int itemCount,
  }) {
    return _commitMessage(
      chatRoomId: chatRoomId,
      senderAccountId: senderAccountId,
      peerAccountId: peerAccountId,
      messageRef: _paths.messages(chatRoomId).doc(),
      content: {
        'type': MessageType.album.value,
        'albumId': albumId,
        'albumEvent': event.value,
        'albumItemCount': itemCount,
        'albumName': albumName,
      },
    );
  }

  /// 画像メッセージのID（＝Storageのファイル名）を先に採番する
  /// 送信中の画像をトークに表示するときに同じIDを使い、メッセージができたらFirestore側の表示と入れ替える（[sendImageMessage]に渡す）
  String newMessageId(String chatRoomId) => _paths.messages(chatRoomId).doc().id;

  /// 画像メッセージを送信する
  /// [messageId]（[newMessageId]で採番）で画像をStorageへアップロードし、その後にメッセージを作る（最初の送信なら、ルーム・自分のchatListも同じリクエストで作る）
  ///
  /// 画像は選択時に縮小・圧縮済みであること。10MB以上は[ChatImageTooLargeException]を投げる。[onProgress]にはアップロードの進み具合（0〜1）を渡す
  /// [size]は読み取り済みの大きさ。無ければここで読む
  Future<void> sendImageMessage({
    required String chatRoomId,
    required String messageId,
    required String senderAccountId,
    required String? peerAccountId,
    required File file,
    ({int width, int height})? size,
    void Function(double progress)? onProgress,
  }) async {
    final imageSize = size ?? await readImageSize(file);
    await _imageStorageService.upload(StoragePaths.chatImage(chatRoomId, messageId), file, onProgress: onProgress);
    await _createImageMessage(
      chatRoomId: chatRoomId,
      messageId: messageId,
      senderAccountId: senderAccountId,
      peerAccountId: peerAccountId,
      width: imageSize.width,
      height: imageSize.height,
    );
  }

  // ---- 画像 ----

  /// スタンプのパックの一覧を監視する（機能仕様書4.4.8、データ設計書3.9）
  /// スタンプが1つも無いパックは除く
  Stream<List<StickerPack>> watchStickerPacks() => _paths.stickerPacks.snapshots().map(
    (snapshot) => snapshot.docs
        .map((doc) => StickerPack.fromMap(doc.data()))
        .where((pack) => pack.stickerIds.isNotEmpty)
        .toList(),
  );

  /// 表示用の画像のダウンロードURL（データ設計書3.3.1）
  /// URLはFirestoreに保存せず、表示のたびにルールで許可された参加者がSDK経由で取得する
  Future<String> imageDownloadUrl(String path) => _imageStorageService.downloadUrl(path);

  /// 端末のアルバムへの保存が許可されているか
  /// まだ許可を求めていなければ、ここで求める（許可されなければfalse）
  Future<bool> ensurePhotoLibraryAccess() => _photoLibraryService.ensureAccess();

  /// トークの画像を、端末のアルバムに保存する（CHA-03）
  /// 結果を返す（保存の途中で許可されていないと分かったら[ImageSaveResult.denied]）。先に[ensurePhotoLibraryAccess]で許可を確かめておく
  Future<ImageSaveResult> saveImageToPhotoLibrary(String path) async {
    try {
      final Uint8List bytes = await _imageStorageService.download(path);
      await _photoLibraryService.saveImage(bytes, name: path.split('/').last.split('.').first);
      return ImageSaveResult.saved;
    } on GalException catch (e) {
      return e.type == GalExceptionType.accessDenied ? ImageSaveResult.denied : ImageSaveResult.failed;
    } catch (_) {
      return ImageSaveResult.failed;
    }
  }

  /// アップロード済みの画像で、画像メッセージを作る
  Future<void> _createImageMessage({
    required String chatRoomId,
    required String messageId,
    required String senderAccountId,
    required String? peerAccountId,
    required int width,
    required int height,
  }) {
    return _commitMessage(
      chatRoomId: chatRoomId,
      senderAccountId: senderAccountId,
      peerAccountId: peerAccountId,
      messageRef: _paths.messages(chatRoomId).doc(messageId),
      content: {
        'type': MessageType.image.value,
        'imagePath': StoragePaths.chatImage(chatRoomId, messageId),
        'imageWidth': width,
        'imageHeight': height,
      },
    );
  }

  /// メッセージと自分の`chatList`の更新を、1回のリクエストで書く
  /// ルームが無ければ（最初の送信）、ルームと自分の`chatList`の作成も同じリクエストに含める（相手の`chatList`の更新と未読数の+1は、Cloud Functionsの`onMessageCreated`が行う。データ設計書3.2.4・3.3）
  ///
  /// [peerAccountId]がnullならグループ。ルームと自分の`chatList`はCloud Functionsが作っているため、更新だけを行う。既読は`members`で持つので`readBy`は書かない（データ設計書8.6）
  ///
  /// [content]は種類ごとの項目（`type`と、`text`または画像の項目）
  Future<void> _commitMessage({
    required String chatRoomId,
    required String senderAccountId,
    required String? peerAccountId,
    required DocumentReference<Map<String, dynamic>> messageRef,
    required Map<String, dynamic> content,
  }) async {
    final uid = _currentUid();
    if (uid == null) throw StateError('not signed in');
    final roomRef = _paths.chatRoom(chatRoomId);
    final chatListRef = _paths.chatList(senderAccountId).doc(chatRoomId);
    final counterRef = _paths.sendCounter(uid);
    final counter = sendCounterWrite(sendCounterMessageKey(chatRoomId: chatRoomId, messageId: messageRef.id));
    unawaited(_refreshSendCounter(uid));
    if (peerAccountId == null) {
      final batch = _paths.batch();
      batch.update(chatListRef, {
        'lastMessage': _lastMessage(
          messageId: messageRef.id,
          type: content['type'],
          text: content['text'],
          meetupStatus: content['meetupStatus'],
          senderId: senderAccountId,
          createdAt: FieldValue.serverTimestamp(),
        ),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      batch.set(messageRef, {
        'messageId': messageRef.id,
        'senderId': senderAccountId,
        ...content,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(counterRef, counter, SetOptions(merge: true));
      await batch.commit();
      return;
    }

    final results = await Future.wait([roomRef.get(), chatListRef.get()]);
    final roomExists = results[0].exists;
    final chatListExists = results[1].exists;

    final lastMessage = _lastMessage(
      messageId: messageRef.id,
      type: content['type'],
      text: content['text'],
      senderId: senderAccountId,
      createdAt: FieldValue.serverTimestamp(),
    );
    final batch = _paths.batch();
    if (!roomExists) {
      batch.set(roomRef, {
        'chatRoomId': chatRoomId,
        'participantIds': [senderAccountId, peerAccountId]..sort(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (chatListExists) {
      batch.update(chatListRef, {'lastMessage': lastMessage, 'lastMessageAt': FieldValue.serverTimestamp()});
    } else {
      batch.set(chatListRef, {
        'chatRoomId': chatRoomId,
        'peerAccountId': peerAccountId,
        'lastMessage': lastMessage,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(messageRef, {
      'messageId': messageRef.id,
      'senderId': senderAccountId,
      ...content,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [senderAccountId],
    });
    batch.set(counterRef, counter, SetOptions(merge: true));
    await batch.commit();
  }

  /// 必要ならカウンターの件数を0に戻す（データ設計書3.1.2）
  /// 送信とは別に書く（送信バッチはオフラインでも書けるよう今の値を読まないため）。読み取りを増やさないよう、確かめるのは1時間に1回まで
  /// 失敗しても送信には影響しないので無視する（オフラインなら次の送信でやり直す。別の端末が先に戻していたらルールで拒否される）
  Future<void> _refreshSendCounter(String uid) async {
    final now = DateTime.now();
    final checkedAt = _sendCounterCheckedAt[uid];
    if (checkedAt != null && now.difference(checkedAt) < _sendCounterCheckInterval) return;
    try {
      final counterRef = _paths.sendCounter(uid);
      final counter = await counterRef.get(const GetOptions(source: Source.server));
      _sendCounterCheckedAt[uid] = now;
      if (!needsSendCounterReset((counter.data()?['baseAt'] as Timestamp?)?.toDate(), now: now)) return;
      await counterRef.set({
        'counterId': 'current',
        'count': 0,
        'baseAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// カウンターを確かめる間隔
  static const _sendCounterCheckInterval = Duration(hours: 1);

  /// トーク一覧のプレビュー（`chatList.lastMessage`、データ設計書3.2.4）
  /// 画像メッセージは本文を持たないため、[text]がnullなら`text`を入れない（Cloud Functionsの`toLastMessage`（firebase/functions/index.js）と同じ形）
  static Map<String, dynamic> _lastMessage({
    required String messageId,
    required Object? type,
    required Object? text,
    required Object? senderId,
    required Object? createdAt,
    Object? meetupStatus,
    Object? systemType,
    Object? targetAccountIds,
  }) {
    return {
      'messageId': messageId,
      'type': type,
      'text': ?text,
      'meetupStatus': ?meetupStatus,
      'senderId': senderId,
      'createdAt': createdAt,
      'systemType': ?systemType,
      'targetAccountIds': ?targetAccountIds,
    };
  }

  // ---- 既読 ----

  /// アカウント[readerAccountId]が、相手からの未読メッセージを既読にする（機能仕様書4.4.3.3）
  /// 履歴の全件を読まないよう、自分の`chatList.unreadCount`を手がかりに、新しい側から未読分が出尽くすまでだけ遡る（未読が0件・トークが一覧に無いなら、何も読み書きしない）
  ///
  /// 1回のバッチの書き込みは500件までのため、[_maxWritesPerBatch]件ずつに分けて書く。`chatList`の未読数は最後のバッチで0にする（途中で失敗したら未読数を残し、次に開いたときにやり直す）
  ///
  /// 未読のリアクション（`unreadReactions`）も、最後のバッチで消す。リアクションはメッセージの件数に含めない（`unreadCount`をメッセージの件数として遡るため）
  Future<void> markRead({required String chatRoomId, required String readerAccountId}) async {
    final chatListRef = _paths.chatList(readerAccountId).doc(chatRoomId);
    final entry = await chatListRef.get();
    var remaining = (entry.data()?['unreadCount'] as num?)?.toInt() ?? 0;
    final hasUnreadReactions = unreadReactionCount(entry.data()) > 0;
    if (remaining <= 0 && !hasUnreadReactions) return;

    final unread = <DocumentReference<Map<String, dynamic>>>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (remaining > 0) {
      var query = _paths.messages(
        chatRoomId,
      ).orderBy('createdAt', descending: true).limit(messagePageSize);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final page = await query.get();

      for (final doc in page.docs) {
        final data = doc.data();
        // 取消済みのメッセージは更新できない（ルールで拒否）。未読数からはCloud Functionsが差し引く。
        if (data['senderId'] == readerAccountId || data['unsentAt'] != null) continue;
        final readBy = stringList(data['readBy']);
        if (readBy.contains(readerAccountId)) continue;
        unread.add(doc.reference);
        remaining--;
      }

      if (page.docs.length < messagePageSize) break;
      cursor = page.docs.last;
    }

    final chunks = splitForBatches(unread, extraWritesInLast: 1, maxWrites: _maxWritesPerBatch);
    for (var i = 0; i < chunks.length; i++) {
      final batch = _paths.batch();
      for (final ref in chunks[i]) {
        batch.update(ref, {
          'readBy': FieldValue.arrayUnion([readerAccountId]),
        });
      }
      if (i == chunks.length - 1) {
        batch.update(chatListRef, {'unreadCount': 0, if (hasUnreadReactions) 'unreadReactions': FieldValue.delete()});
      }
      await batch.commit();
    }
  }

  /// アカウント[readerAccountId]がグループのトークを開いた（データ設計書8.6）
  /// 自分の未読数を0にし、`members`の最後に読んだ時刻を更新する
  /// 未読が無ければ何も書かない（`lastReadAt`は参加者が読めるので、開いただけの時刻を残さない。[markRead]と同じ）
  Future<void> markGroupRead({required String chatRoomId, required String readerAccountId}) async {
    final chatListRef = _paths.chatList(readerAccountId).doc(chatRoomId);
    final entry = await chatListRef.get();
    final unreadCount = intOrNull(entry.data()?['unreadCount']) ?? 0;
    final hasUnreadReactions = unreadReactionCount(entry.data()) > 0;
    if (!entry.exists || (unreadCount <= 0 && !hasUnreadReactions)) return;
    final batch = _paths.batch();
    batch.update(_paths.chatRoomMembers(chatRoomId).doc(readerAccountId), {'lastReadAt': FieldValue.serverTimestamp()});
    batch.update(chatListRef, {'unreadCount': 0, if (hasUnreadReactions) 'unreadReactions': FieldValue.delete()});
    await batch.commit();
  }

  /// 1回のバッチで書ける件数（Firestoreの上限は500件）
  static const _maxWritesPerBatch = 500;

  // ---- メッセージの操作 ----

  /// リアクションを付ける・変える・外す
  /// [emoji]がnullなら外す（同じ絵文字をもう一度選んだとき）
  /// グループでは、変更した本人を`reactedBy`に書く（ルールが、変更したキーと一致するかを検証する。データ設計書6章）
  Future<void> setReaction({
    required String chatRoomId,
    required String messageId,
    required String reactorAccountId,
    required String? emoji,
  }) {
    // アカウントIDには「.」を使えるため、文字列の'reactions.$id'では「.」が入れ子の区切りと解釈されてしまう。FieldPathで1つのキーとして指定する
    final field = FieldPath(['reactions', reactorAccountId]);
    return _paths.messages(chatRoomId).doc(messageId).update({
      field: emoji ?? FieldValue.delete(),
      if (isGroupChatRoomId(chatRoomId)) 'reactedBy': reactorAccountId,
    });
  }

  /// 送信を取り消す
  /// 自分・相手の両方の画面から消える。物理削除はせず`unsentAt`を付ける論理削除で、本文の退避・削除と双方のトーク一覧の書き直しはCloud Functionsの`onMessageUnsent`が行う
  Future<void> unsendMessage({required String chatRoomId, required String messageId}) {
    return _paths.messages(chatRoomId).doc(messageId).update({'unsentAt': FieldValue.serverTimestamp()});
  }

  /// アカウント[accountId]の画面からだけメッセージを消す（論理削除）
  /// 相手の画面には残る
  ///
  /// 消したメッセージが自分の一覧の最新メッセージだった場合は、自分に見えている最も新しいメッセージで自分の`chatList.lastMessage`を書き直す（無ければnull。データ設計書3.3.1）
  /// グループでは[since]に参加した時刻を渡す（[watchLatestMessages]と同じ）
  /// 書き直す内容を先に求めてから、メッセージと`chatList`の更新を1回のバッチで書く（片方だけが反映され、消えたメッセージが一覧のプレビューに残ることが無いように）
  Future<void> hideMessageForMe({
    required String chatRoomId,
    required String messageId,
    required String accountId,
    DateTime? since,
  }) async {
    final messageRef = _paths.messages(chatRoomId).doc(messageId);
    final chatListRef = _paths.chatList(accountId).doc(chatRoomId);
    final entry = await chatListRef.get();
    final lastMessage = entry.data()?['lastMessage'] as Map<String, dynamic>?;

    final batch = _paths.batch();
    batch.update(messageRef, {
      'hiddenFor': FieldValue.arrayUnion([accountId]),
    });
    if (lastMessage?['messageId'] == messageId) {
      final recent = await _newestFirst(chatRoomId, since: since).limit(messagePageSize).get();
      Map<String, dynamic>? newest;
      for (final doc in recent.docs) {
        final data = doc.data();
        final hiddenFor = List<String>.from(data['hiddenFor'] as List? ?? const []);
        // 今回削除するメッセージは、まだhiddenForに入っていないため明示的に除く。
        if (doc.id == messageId || hiddenFor.contains(accountId) || data['unsentAt'] != null) continue;
        newest = _lastMessage(
          messageId: doc.id,
          type: data['type'] ?? MessageType.text.value,
          text: data['text'],
          meetupStatus: data['meetupStatus'],
          senderId: data['senderId'],
          createdAt: data['createdAt'],
          systemType: data['systemType'],
          targetAccountIds: data['targetAccountIds'],
        );
        break;
      }
      batch.update(chatListRef, {'lastMessage': newest});
    }
    await batch.commit();
  }
}
