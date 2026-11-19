// 管理者のログアウト（機能仕様書4.1.7）
// トークンを外せなければサインアウトしないこと、順序を確かめる。

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/repositories/auth/auth_repository.dart';
import 'package:multi_id_msg/data/repositories/notification/notification_repository.dart';
import 'package:multi_id_msg/data/services/common/firestore_cache_cleaner.dart';
import 'package:multi_id_msg/domain/use_cases/logout_use_case.dart';

class _FakeNotificationRepository extends Fake implements NotificationRepository {
  _FakeNotificationRepository(this.calls, {this.fails = false});

  final List<String> calls;
  final bool fails;
  List<String>? accountIds;

  @override
  Future<void> unregisterToken(List<String> accountIds) async {
    this.accountIds = accountIds;
    if (fails) throw Exception('offline');
    calls.add('unregisterToken');
  }
}

class _FakeCacheCleaner extends Fake implements FirestoreCacheCleaner {
  _FakeCacheCleaner(this.calls);

  final List<String> calls;

  @override
  Future<void> request() async => calls.add('requestCacheClear');
}

class _FakeAuthRepository extends Fake implements AuthRepository {
  _FakeAuthRepository(this.calls);

  final List<String> calls;

  @override
  Future<void> signOut() async => calls.add('signOut');
}

void main() {
  test('全アカウントからトークンを外し、キャッシュの消去を予約してからサインアウトする', () async {
    final calls = <String>[];
    final notifications = _FakeNotificationRepository(calls);
    await LogoutUseCase(_FakeAuthRepository(calls), notifications, _FakeCacheCleaner(calls)).call(['alice', 'bob']);

    expect(notifications.accountIds, ['alice', 'bob']);
    expect(calls, ['unregisterToken', 'requestCacheClear', 'signOut']);
  });

  test('トークンを外せなければ、サインアウトせずに例外を投げる', () async {
    final calls = <String>[];
    final useCase = LogoutUseCase(
      _FakeAuthRepository(calls),
      _FakeNotificationRepository(calls, fails: true),
      _FakeCacheCleaner(calls),
    );

    await expectLater(useCase.call(['alice']), throwsException);
    expect(calls, isEmpty);
  });
}
