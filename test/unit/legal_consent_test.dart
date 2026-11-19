import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/repositories/auth/auth_repository.dart';
import 'package:multi_id_msg/data/services/auth/firebase_auth_service.dart';
import 'package:multi_id_msg/data/services/common/cloud_functions_service.dart';

class _FakeAuthService implements FirebaseAuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFunctionsService implements CloudFunctionsService {
  _FakeFunctionsService(this.failures);

  /// 失敗させる回数
  int failures;

  final List<String> calls = [];

  @override
  Future<void> call(String name, [Map<String, dynamic>? data, Duration? timeout]) async {
    calls.add(name);
    if (failures > 0) {
      failures--;
      throw Exception('unavailable');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthRepository _repository(CloudFunctionsService functions) =>
    AuthRepository(_FakeAuthService(), functions, legalConsentRetryDelay: Duration.zero);

void main() {
  test('同意の記録は成功したら1回で終わる', () async {
    final functions = _FakeFunctionsService(0);
    await _repository(functions).recordLegalConsent();
    expect(functions.calls, ['recordLegalConsent']);
  });

  test('失敗したら試し直す', () async {
    final functions = _FakeFunctionsService(2);
    await _repository(functions).recordLegalConsent();
    expect(functions.calls, hasLength(3));
  });

  test('3回失敗しても例外を投げない（サインインを止めない）', () async {
    final functions = _FakeFunctionsService(5);
    await _repository(functions).recordLegalConsent();
    expect(functions.calls, hasLength(3));
  });
}
