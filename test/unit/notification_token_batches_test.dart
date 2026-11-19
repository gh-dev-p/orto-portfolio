// ignore_for_file: subtype_of_sealed_class
// FCMトークンの登録と削除のバッチの分割（機能仕様書4.1.7）
// ルールの参照の上限に当たらないよう10件ずつに分けること、途中で失敗したら呼び直せば完了することを確かめる。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/repositories/notification/notification_repository.dart';
import 'package:multi_id_msg/data/services/common/firestore_paths.dart';
import 'package:multi_id_msg/data/services/notification/push_notification_service.dart';

class _FakePushService extends Fake implements PushNotificationService {
  @override
  Future<String?> token() async => 't';
}

class _FakeDocument extends Fake implements DocumentReference<Map<String, dynamic>> {
  _FakeDocument(this.accountId);

  final String accountId;
}

class _FakeCollection extends Fake implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this.accountId);

  final String accountId;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _FakeDocument(accountId);
}

class _FakeBatch extends Fake implements WriteBatch {
  _FakeBatch(this.paths);

  final _FakePaths paths;
  final accountIds = <String>[];

  @override
  void delete(DocumentReference document) => accountIds.add((document as _FakeDocument).accountId);

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      accountIds.add((document as _FakeDocument).accountId);

  @override
  Future<void> commit() async {
    if (paths.commits.length == paths.failAtCommit) {
      paths.failAtCommit = null;
      throw paths.failure;
    }
    paths.commits.add(accountIds);
  }
}

class _FakePaths extends Fake implements FirestorePaths {
  final commits = <List<String>>[];

  /// 何回目のコミットで失敗するか
  int? failAtCommit;
  Object failure = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

  @override
  CollectionReference<Map<String, dynamic>> fcmTokens(String accountId) => _FakeCollection(accountId);

  @override
  WriteBatch batch() => _FakeBatch(this);
}

void main() {
  final batchSizes = {
    1: [1],
    10: [10],
    11: [10, 1],
    20: [10, 10],
  };

  List<String> ids(int count) => [for (var i = 0; i < count; i++) 'a$i'];

  for (final MapEntry(key: count, value: sizes) in batchSizes.entries) {
    test('$count件の削除は、${sizes.length}回のバッチで全件に行う', () async {
      final paths = _FakePaths();
      await NotificationRepository(_FakePushService(), paths).unregisterToken(ids(count));

      expect(paths.commits.map((batch) => batch.length), sizes);
      expect(paths.commits.expand((batch) => batch), ids(count));
    });

    test('$count件の登録は、${sizes.length}回のバッチで全件に行う', () async {
      final paths = _FakePaths();
      await NotificationRepository(_FakePushService(), paths).registerToken(ids(count), languageCode: 'ja');

      expect(paths.commits.map((batch) => batch.length), sizes);
      expect(paths.commits.expand((batch) => batch), ids(count));
    });
  }

  test('途中のバッチで失敗したら例外を投げ、呼び直すと全件を消す', () async {
    final paths = _FakePaths()..failAtCommit = 1;
    final repository = NotificationRepository(_FakePushService(), paths);

    await expectLater(repository.unregisterToken(ids(20)), throwsA(isA<FirebaseException>()));
    expect(paths.commits.expand((batch) => batch), ids(10));

    paths.commits.clear();
    await repository.unregisterToken(ids(20));
    expect(paths.commits.expand((batch) => batch), ids(20));
  });

  test('ルールに拒否されたら、拒否の例外を投げる', () async {
    final paths = _FakePaths()
      ..failAtCommit = 0
      ..failure = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

    await expectLater(
      NotificationRepository(_FakePushService(), paths).unregisterToken(ids(1)),
      throwsA(isA<TokenUnregisterDeniedException>()),
    );
  });
}
