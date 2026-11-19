// 引き継ぎパスワードの再設定の申請の呼び出しと、結果の変換
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/repositories/auth/auth_repository.dart';
import 'package:multi_id_msg/data/services/auth/firebase_auth_service.dart';
import 'package:multi_id_msg/data/services/common/cloud_functions_service.dart';

class _FakeAuthService implements FirebaseAuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFunctionsService implements CloudFunctionsService {
  _FakeFunctionsService(this.result);

  final Map<String, dynamic> result;
  final List<Map<String, dynamic>?> calls = [];

  @override
  Future<Map<String, dynamic>> callForResult(String name, [Map<String, dynamic>? data]) async {
    expect(name, 'transferReset');
    calls.add(data);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('申請すると、削除の日時を返す', () async {
    final functions = _FakeFunctionsService({'state': 'pending', 'resetAt': 1795000000000});
    final resetAt = await AuthRepository(_FakeAuthService(), functions).requestTransferReset();
    expect(functions.calls, [
      {'action': 'request'},
    ]);
    expect(resetAt, DateTime.fromMillisecondsSinceEpoch(1795000000000));
  });

  test('申請が無ければnull', () async {
    final functions = _FakeFunctionsService({'state': 'none', 'resetAt': null});
    expect(await AuthRepository(_FakeAuthService(), functions).transferResetStatus(), isNull);
    expect(functions.calls.single, {'action': 'status'});
  });

  test('取り消しは cancel で呼ぶ', () async {
    final functions = _FakeFunctionsService({'state': 'none', 'resetAt': null});
    await AuthRepository(_FakeAuthService(), functions).cancelTransferReset();
    expect(functions.calls.single, {'action': 'cancel'});
  });
}
