import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/repositories/chat/chat_repository.dart';

void main() {
  final now = DateTime(2026, 11, 1, 12);

  group('sendCounterWrite', () {
    test('今の値を読まずに+1だけを書き、baseAtは書かない', () {
      final write = sendCounterWrite('room/m1');
      expect(write['counterId'], 'current');
      expect(write['count'], FieldValue.increment(1));
      expect(write['lastMessageKey'], 'room/m1');
      expect(write.containsKey('baseAt'), isFalse);
    });
  });

  group('sendCounterMessageKey', () {
    test('ルームとメッセージから作る（ルールの照合と同じ形）', () {
      expect(sendCounterMessageKey(chatRoomId: 'alice~bob', messageId: 'm1'), 'alice~bob/m1');
    });
  });

  group('needsSendCounterReset', () {
    test('baseAtが無ければ戻す', () {
      expect(needsSendCounterReset(null, now: now), isTrue);
    });

    test('24時間未満なら戻さない', () {
      expect(needsSendCounterReset(now.subtract(const Duration(hours: 23, minutes: 59)), now: now), isFalse);
    });

    test('ちょうど24時間で戻す', () {
      expect(needsSendCounterReset(now.subtract(const Duration(hours: 24)), now: now), isTrue);
    });

    test('端末の時計が遅くbaseAtが未来でも戻さない', () {
      expect(needsSendCounterReset(now.add(const Duration(minutes: 5)), now: now), isFalse);
    });
  });
}
