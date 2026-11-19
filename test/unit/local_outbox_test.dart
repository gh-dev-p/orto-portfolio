import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/chat/view_models/local_outbox.dart';
import 'package:multi_id_msg/domain/models/message.dart';
import 'package:multi_id_msg/domain/models/message_history.dart';

Message _remote(String id, {List<String> hiddenFor = const [], DateTime? unsentAt}) => Message(
  id: id,
  senderId: 'peer',
  text: id,
  createdAt: DateTime(2026, 10, 1),
  readBy: const [],
  hiddenFor: hiddenFor,
  unsentAt: unsentAt,
);

MessageHistory _history(List<Message> messages) => MessageHistory(messages: messages, hasMore: false);

void main() {
  group('LocalOutbox（CHA-02の端末上だけにあるメッセージ）', () {
    test('送信失敗のメッセージは、Firestoreのメッセージの後ろに送った順で並ぶ', () {
      final outbox = LocalOutbox()
        ..addFailedText(senderId: 'me', text: '  first  ')
        ..addFailedImage(senderId: 'me', localImagePath: '/tmp/a.jpg', width: 10, height: 20);

      final visible = outbox.visibleMessages(_history([_remote('m1')]), myAccountId: 'me');

      expect([for (final m in visible) m.id], ['m1', 'local-failed-0', 'local-failed-1']);
      expect(visible[1].text, 'first');
      expect(visible[1].isFailed, isTrue);
      expect(visible[2].isImage, isTrue);
      expect(visible[2].localImagePath, '/tmp/a.jpg');
    });

    test('再送で外した送信失敗のメッセージは表示しない', () {
      final outbox = LocalOutbox()..addFailedText(senderId: 'me', text: 'x');
      outbox.removeFailed('local-failed-0');

      expect(outbox.visibleMessages(_history(const []), myAccountId: 'me'), isEmpty);
    });

    test('アップロード中の画像の大きさは後から入れられ、進み具合を保つ', () {
      final outbox = LocalOutbox()..startUpload(messageId: 'img1', senderId: 'me', localImagePath: '/tmp/b.jpg');
      outbox.updateProgress('img1', 0.5);
      expect(outbox.visibleMessages(_history(const []), myAccountId: 'me').single.imageWidth, isNull);

      expect(outbox.updateSize('img1', width: 30, height: 40), isTrue);
      expect(outbox.updateSize('unknown', width: 30, height: 40), isFalse);

      final uploading = outbox.visibleMessages(_history(const []), myAccountId: 'me').single;
      expect(uploading.imageWidth, 30);
      expect(uploading.imageHeight, 40);
      expect(uploading.uploadProgress, 0.5);
    });

    test('アップロード中の画像は進み具合を持ち、同じIDのメッセージがFirestoreにできたらそちらを表示する', () {
      final outbox = LocalOutbox()..startUpload(messageId: 'img1', senderId: 'me', localImagePath: '/tmp/b.jpg');
      expect(outbox.updateProgress('img1', 0.5), isTrue);
      expect(outbox.updateProgress('unknown', 0.5), isFalse);

      final uploading = outbox.visibleMessages(_history(const []), myAccountId: 'me').single;
      expect(uploading.isUploadingImage, isTrue);
      expect(uploading.uploadProgress, 0.5);

      final replaced = outbox.visibleMessages(_history([_remote('img1')]), myAccountId: 'me');
      expect(replaced.single.isUploadingImage, isFalse);

      outbox.finishUpload('img1');
      expect(outbox.visibleMessages(_history(const []), myAccountId: 'me'), isEmpty);
    });

    test('自分の画面から削除したメッセージ・送信取消したメッセージは表示しない', () {
      final visible = LocalOutbox().visibleMessages(
        _history([
          _remote('kept'),
          _remote('hidden', hiddenFor: ['me']),
          _remote('unsent', unsentAt: DateTime(2026, 10, 2)),
        ]),
        myAccountId: 'me',
      );

      expect([for (final m in visible) m.id], ['kept']);
    });
  });
}
