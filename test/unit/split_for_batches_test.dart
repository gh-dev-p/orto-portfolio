import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/repositories/chat/chat_repository.dart';

void main() {
  group('splitForBatches（既読処理のバッチ分割、1回500件まで）', () {
    List<int> sizes(int count) => [
      for (final chunk in splitForBatches(List.generate(count, (i) => i), extraWritesInLast: 1, maxWrites: 500))
        chunk.length,
    ];

    test('どのバッチも、最後のバッチの追加の書き込みを含めて500件以内に収まる', () {
      for (final count in [0, 1, 498, 499, 500, 501, 999, 1000, 1500]) {
        final chunks = sizes(count);
        expect(chunks.sum, count, reason: 'count=$count');
        for (var i = 0; i < chunks.length; i++) {
          final writes = chunks[i] + (i == chunks.length - 1 ? 1 : 0);
          expect(writes, lessThanOrEqualTo(500), reason: 'count=$count, batch=$i');
        }
      }
    });

    test('件数の境目で区切る（最後のバッチは未読数の更新の1件を空ける）', () {
      expect(sizes(0), [0]);
      expect(sizes(499), [499]);
      expect(sizes(500), [500, 0]);
      expect(sizes(1000), [500, 500, 0]);
    });

    test('順番を保つ', () {
      final chunks = splitForBatches(List.generate(1200, (i) => i), extraWritesInLast: 1, maxWrites: 500);
      expect([for (final chunk in chunks) ...chunk], List.generate(1200, (i) => i));
    });
  });
}

extension on List<int> {
  int get sum => fold(0, (a, b) => a + b);
}
