import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/services/passcode/passcode_store.dart';

/// Keystoreの鍵と保存値が食い違った状態（Auto Backupの復元後）を模した保存先。
/// `resetOnError: false`の通常の操作は、初期化の段階で失敗し続ける（read・write・deleteのすべて）。
/// 復旧用の`deleteAll`（`resetOnError: true`の初期化）だけが、鍵ごと作り直して復帰させる。
class _KeyMismatchStorage implements PasscodeStorage {
  _KeyMismatchStorage({this.broken = true});

  bool broken;
  final values = <String, String>{};
  var recoveryCalls = 0;

  void _check() {
    if (broken) throw Exception('Failed to unwrap key');
  }

  @override
  Future<String?> read(String key) async {
    _check();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _check();
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _check();
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    recoveryCalls++;
    broken = false;
    values.clear();
  }
}

class _MemoryStorage implements PasscodeStorage {
  final values = <String, String>{};
  Object? readError;
  Object? deleteError;
  Object? deleteAllError;
  var deleteAllCalls = 0;

  @override
  Future<String?> read(String key) async {
    final error = readError;
    if (error != null) throw error;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async {
    final error = deleteError;
    if (error != null) throw error;
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCalls++;
    final error = deleteAllError;
    if (error != null) throw error;
    values.clear();
  }
}

void main() {
  group('SecurePasscodeStorage', () {
    test('Androidでは、鍵の不整合をデータ消去で握りつぶさず例外にする（resetOnError: false）', () {
      const storage = FlutterSecureStorage(aOptions: SecurePasscodeStorage.androidOptions);

      expect(storage.aOptions.toMap()['resetOnError'], 'false');
      expect(SecurePasscodeStorage.defaultStorage.aOptions.toMap()['resetOnError'], 'false');
    });

    test('既定のプラグイン設定はresetOnError: true（この差が、上の指定が必要な理由）', () {
      expect(AndroidOptions.defaultOptions.toMap()['resetOnError'], 'true');
    });

    test('復旧用の保存先は、鍵の保存先まで作り直せるresetOnError: true', () {
      expect(SecurePasscodeStorage.recoveryStorage.aOptions.toMap()['resetOnError'], 'true');
      expect(SecurePasscodeStorage.recoveryAndroidOptions.toMap()['resetOnError'], 'true');
    });
  });

  late _MemoryStorage storage;
  late PasscodeStore store;

  setUp(() {
    storage = _MemoryStorage();
    store = PasscodeStore(storage, random: Random(1));
  });

  test('未設定のアカウントは、パスコード無しとして扱われ、検証は常に失敗する', () async {
    expect(await store.isEnabled('a'), isFalse);
    expect(await store.verify('a', '1234'), isFalse);
  });

  test('設定したパスコードだけが検証に通る', () async {
    await store.save('a', '1234');

    expect(await store.isEnabled('a'), isTrue);
    expect(await store.verify('a', '1234'), isTrue);
    expect(await store.verify('a', '1235'), isFalse);
    expect(await store.verify('a', '0000'), isFalse);
  });

  test('パスコードは平文で保存されない', () async {
    await store.save('a', '1234');

    expect(storage.values.values.single, isNot(contains('1234')));
  });

  test('パスコードはアカウントごとに独立している', () async {
    await store.save('a', '1111');
    await store.save('b', '2222');

    expect(await store.verify('a', '1111'), isTrue);
    expect(await store.verify('a', '2222'), isFalse);
    expect(await store.verify('b', '2222'), isTrue);
    expect(await store.isEnabled('c'), isFalse);
  });

  test('同じパスコードでも、saltが違うため保存値は毎回異なる', () async {
    await store.save('a', '1234');
    final first = storage.values['passcode.a'];
    await store.save('a', '1234');

    expect(storage.values['passcode.a'], isNot(first));
    expect(await store.verify('a', '1234'), isTrue);
  });

  test('同じ保存値を別のアカウントIDに移しても、検証に通らない', () async {
    await store.save('a', '1234');
    storage.values['passcode.b'] = storage.values['passcode.a']!;

    expect(await store.verify('b', '1234'), isFalse);
  });

  test('上書きすると、古いパスコードは使えなくなる', () async {
    await store.save('a', '1234');
    await store.save('a', '5678');

    expect(await store.verify('a', '1234'), isFalse);
    expect(await store.verify('a', '5678'), isTrue);
  });

  test('数字4桁以外は設定できない', () async {
    for (final invalid in ['', '123', '12345', 'abcd', '12a4', ' 123']) {
      expect(() => store.save('a', invalid), throwsArgumentError, reason: 'passcode="$invalid"');
    }
    expect(await store.isEnabled('a'), isFalse);
  });

  test('removeで設定が消え、他のアカウントには影響しない', () async {
    await store.save('a', '1234');
    await store.save('b', '5678');

    await store.remove('a');

    expect(await store.isEnabled('a'), isFalse);
    expect(await store.verify('a', '1234'), isFalse);
    expect(await store.verify('b', '5678'), isTrue);
  });

  test('保存値が壊れている場合は、検証に失敗する（例外を出さない）', () async {
    for (final broken in ['', 'nocolon', ':hash', 'salt:']) {
      storage.values['passcode.a'] = broken;
      expect(await store.verify('a', '1234'), isFalse, reason: 'stored="$broken"');
    }
  });

  test('保存領域を読めない場合は、ロック中（有効）だが検証はできない状態として扱う', () async {
    await store.save('a', '1234');
    storage.readError = Exception('Failed to unwrap key');

    expect(await store.isEnabled('a'), isTrue);
    expect(await store.verify('a', '1234'), isFalse);
  });

  test('復元で鍵が食い違った状態：ロック扱い→復旧で解除→再設定できる', () async {
    final mismatch = _KeyMismatchStorage(broken: false);
    final mismatchStore = PasscodeStore(mismatch, random: Random(1));
    await mismatchStore.save('a', '1234');
    await mismatchStore.save('b', '5678');

    // 復元後：鍵が食い違い、通常の操作はすべて失敗する。素通りさせず、ロック扱い（検証は常に失敗）になる。
    mismatch.broken = true;
    expect(await mismatchStore.isEnabled('a'), isTrue);
    expect(await mismatchStore.verify('a', '1234'), isFalse);

    // 「パスコードを忘れた場合」（SMS再認証）：個別の削除は失敗するが、復旧用の全消去で復帰する。
    await mismatchStore.remove('a');
    expect(mismatch.recoveryCalls, 1);
    expect(await mismatchStore.isEnabled('a'), isFalse);

    // 復帰後は、新しいパスコードを再設定できる。
    await mismatchStore.save('a', '4321');
    expect(await mismatchStore.verify('a', '4321'), isTrue);
    expect(await mismatchStore.verify('a', '1234'), isFalse);
  });

  test('鍵の不整合が無い通常の削除では、復旧用の全消去は使わず、他のアカウントのパスコードも消さない', () async {
    final healthy = _KeyMismatchStorage(broken: false);
    final healthyStore = PasscodeStore(healthy, random: Random(1));
    await healthyStore.save('a', '1234');
    await healthyStore.save('b', '5678');

    await healthyStore.remove('a');

    expect(healthy.recoveryCalls, 0);
    expect(await healthyStore.isEnabled('a'), isFalse);
    expect(await healthyStore.verify('b', '5678'), isTrue);
  });

  test('復旧の全消去まで失敗した場合は、例外を投げて呼び出し元に伝える', () async {
    storage.deleteError = Exception('corrupted');
    storage.deleteAllError = Exception('recovery failed');

    await expectLater(store.remove('a'), throwsException);
  });

  test('保存領域が壊れて個別に削除できない場合は、領域ごと消去して復帰できる', () async {
    await store.save('a', '1234');
    storage.deleteError = Exception('corrupted');

    await store.remove('a');

    expect(storage.deleteAllCalls, 1);
    storage.readError = null;
    expect(await store.isEnabled('a'), isFalse);
  });

  group('誤りの回数の制限（機能仕様書4.2.4.5）', () {
    late _MemoryStorage storage;
    late DateTime now;
    late PasscodeStore store;

    setUp(() async {
      storage = _MemoryStorage();
      now = DateTime(2026, 11, 1, 12);
      store = PasscodeStore(storage, now: () => now);
      await store.save('a', '1234');
    });

    Future<void> failTimes(int times) async {
      for (var i = 0; i < times; i++) {
        final retryAt = (await store.lockout('a')).retryAt;
        if (retryAt != null && retryAt.isAfter(now)) now = retryAt;
        expect((await store.attempt('a', '0000')).matched, isFalse);
      }
    }

    test('4回までは待ち時間なしで、正しい値で回数が戻る', () async {
      await failTimes(4);
      expect((await store.lockout('a')).isActiveAt(now), isFalse);

      expect((await store.attempt('a', '1234')).matched, isTrue);
      await failTimes(4);
      expect((await store.lockout('a')).isActiveAt(now), isFalse);
    });

    test('5回で待ち時間が入り、その間は正しい値でも照合しない', () async {
      await failTimes(5);
      final result = await store.attempt('a', '1234');
      expect(result.matched, isFalse);
      expect(result.lockout.retryAt, now.add(const Duration(seconds: 30)));

      now = now.add(const Duration(seconds: 30));
      expect((await store.attempt('a', '1234')).matched, isTrue);
    });

    test('回数はストアを作り直しても（アプリを再起動しても）引き継ぐ', () async {
      await failTimes(5);
      final restarted = PasscodeStore(storage, now: () => now);
      expect((await restarted.attempt('a', '1234')).matched, isFalse);
    });

    test('10回で、時計を進めても入力できなくなる', () async {
      await failTimes(10);
      now = now.add(const Duration(days: 365));

      final result = await store.attempt('a', '1234');
      expect(result.matched, isFalse);
      expect(result.lockout.exhausted, isTrue);
    });

    test('SMS再認証の削除と再設定で回数が消える', () async {
      await failTimes(10);
      await store.remove('a');
      await store.save('a', '5678');

      expect((await store.lockout('a')).exhausted, isFalse);
      expect((await store.attempt('a', '5678')).matched, isTrue);
    });

    test('待ち時間の秒数は回数とともに長くなる', () {
      expect(PasscodeAttemptPolicy.waitAfter(4), isNull);
      expect(PasscodeAttemptPolicy.waitAfter(5), const Duration(seconds: 30));
      expect(PasscodeAttemptPolicy.waitAfter(8), const Duration(minutes: 15));
      expect(PasscodeAttemptPolicy.waitAfter(9), const Duration(hours: 1));
    });
  });
}
