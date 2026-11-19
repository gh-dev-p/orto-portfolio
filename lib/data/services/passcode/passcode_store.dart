import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'passcode_attempts.dart';

export 'passcode_attempts.dart';

// ============================================================
// 保存先
// ============================================================

/// パスコードの保存先
/// 実機では[SecurePasscodeStorage]（Keychain・Keystore）、テストではメモリ上の実装に差し替える
abstract class PasscodeStorage {
  /// [key]の値を読む（無ければnull）
  Future<String?> read(String key);

  /// [key]に[value]を書く
  Future<void> write(String key, String value);

  /// [key]の値を消す
  Future<void> delete(String key);

  /// 保存領域を、暗号鍵の保存先も含めて全消去する
  /// [PasscodeStore.remove]が個別の削除に失敗したときの復旧用
  Future<void> deleteAll();
}

/// `flutter_secure_storage`による保存先（機能仕様書4.2.4）
class SecurePasscodeStorage implements PasscodeStorage {
  const SecurePasscodeStorage([this._storage = defaultStorage, this._recoveryStorage = recoveryStorage]);

  /// Androidの`resetOnError`はプラグインの既定値がtrueで、Auto Backupの復元等でKeystoreの鍵と保存値が
  /// 食い違うと、例外を出さずに保存データを消去してnullを返す（＝パスコードが黙って未設定に戻り、
  /// ロックされているはずのアカウントが開いてしまう）。falseにして、鍵の不整合を例外として扱わせる
  /// （[PasscodeStore]がロック扱いにし、「パスコードを忘れた場合」で復帰する）。
  static const androidOptions = AndroidOptions(resetOnError: false);

  static const defaultStorage = FlutterSecureStorage(aOptions: androidOptions);

  /// 復旧用：Keystore不整合の状態から抜け出すための`resetOnError: true`の設定。
  ///
  /// 【プラグイン内部への依存】flutter_secure_storage v11.2.0のAndroid実装は、すべての操作の前に暗号を
  /// 初期化する。復元による鍵の不整合はこの初期化で検出され、`resetOnError: false`だと初期化自体が
  /// エラーになって、`delete`・`deleteAll`を含むすべての操作が失敗し続ける（＝通常の[defaultStorage]では
  /// SMS再認証後もパスコードを消せず、再設定もできない）。`resetOnError: true`だと、初期化の段階で
  /// 保存値・Keystoreの鍵・暗号鍵の保存先（`FlutterSecureKeyStorage`）をすべて消して作り直すため、
  /// その後は新しい鍵で書き込める（FlutterSecureStorage.javaの`handleKeyMismatch`→`deleteAllDataAndKeys`）。
  /// この経路は公式APIではないため、プラグインを更新するときは、上記の挙動が変わっていないか確認すること。
  static const recoveryAndroidOptions = AndroidOptions(resetOnError: true);

  static const recoveryStorage = FlutterSecureStorage(aOptions: recoveryAndroidOptions);

  final FlutterSecureStorage _storage;
  final FlutterSecureStorage _recoveryStorage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  /// 復旧用のため、通常の[_storage]ではなく[recoveryStorage]で行う（上記参照）。鍵の不整合が無い状態で呼ぶと、
  /// 全アカウントのパスコードが消える。
  @override
  Future<void> deleteAll() => _recoveryStorage.deleteAll();
}

// ============================================================
// サービス
// ============================================================

/// アカウントごとの4桁のパスコードを保存・照合するサービス（機能仕様書4.2.4 / 画面設計書5.1.4・5.6.3）
/// `PasscodeRepository`から使う
///
/// デバイスローカルのみに保存し、Firestoreには送らない（複数端末間で同期しない）。
/// 平文では持たず、アカウントごとのランダムなsaltと組み合わせたSHA-256のハッシュを保存する。
/// 4桁（1万通り）のため、端末から保存値を取り出せる相手にはハッシュでも総当たりで破られる。
/// 守るのは「画面を開いた第三者」であり、端末自体の保護（Keychain／Keystore）が前提。
///
/// 保存領域が壊れて読めない場合（Android Auto Backupの復元でKeystoreの鍵と保存値が食い違う既知の
/// 問題等）は、ロックされているが検証できない状態として扱う（[isEnabled]はtrue、[verify]はfalse）。
/// パスコードを素通りさせる方向には倒さず、「パスコードを忘れた場合」（SMS再認証→[remove]）で復帰させる。
/// Androidでこの経路に入るには、[SecurePasscodeStorage.androidOptions]（`resetOnError: false`）が前提。
///
/// 総当たりを防ぐため、誤りの回数も同じ保存先に持つ（[PasscodeAttemptPolicy]）。iOSのKeychainはアプリを
/// 削除しても残るため、再インストールでは回数を消せない。回数はパスコードの設定・削除で消える。
class PasscodeStore {
  PasscodeStore(this._storage, {Random? random, DateTime Function()? now})
    : _random = random ?? Random.secure(),
      _now = now ?? DateTime.now;

  static const length = 4;
  static final _validPasscode = RegExp(r'^\d{4}$');

  final PasscodeStorage _storage;
  final Random _random;
  final DateTime Function() _now;

  static String _key(String accountId) => 'passcode.$accountId';

  /// 誤りの回数の保存キー（値は`回数:次に入力できる時刻のミリ秒`）
  static String _attemptsKey(String accountId) => 'passcodeAttempts.$accountId';

  /// アカウント[accountId]にパスコードが設定されているか
  /// 保存領域が読めなければtrue（素通りさせない）
  Future<bool> isEnabled(String accountId) async {
    try {
      return await _storage.read(_key(accountId)) != null;
    } catch (_) {
      return true;
    }
  }

  /// パスコードを設定（上書き）する
  /// [passcode]は数字4桁
  Future<void> save(String accountId, String passcode) async {
    if (!_validPasscode.hasMatch(passcode)) {
      throw ArgumentError.value(passcode, 'passcode', 'must be $length digits');
    }
    final salt = base64Url.encode(List<int>.generate(16, (_) => _random.nextInt(256)));
    await _storage.write(_key(accountId), '$salt:${_hash(accountId, salt, passcode)}');
    await _clearAttempts(accountId);
  }

  /// アカウント[accountId]の、今の入力の制限
  /// 読み取りに失敗したら制限なしとして返す（その場合は[verify]も失敗するため、素通りはしない）
  Future<PasscodeLockout> lockout(String accountId) async {
    final attempts = await _readAttempts(accountId);
    return _lockoutOf(attempts.failures, attempts.retryAt);
  }

  /// [passcode]を照合し、結果を誤りの回数に反映する
  /// 待ち時間の間と回数の上限の後は、照合せずに[PasscodeAttemptResult.matched]をfalseで返す
  Future<PasscodeAttemptResult> attempt(String accountId, String passcode) async {
    final attempts = await _readAttempts(accountId);
    final current = _lockoutOf(attempts.failures, attempts.retryAt);
    if (current.isActiveAt(_now())) return PasscodeAttemptResult(matched: false, lockout: current);

    if (await verify(accountId, passcode)) {
      await _clearAttempts(accountId);
      return const PasscodeAttemptResult(matched: true, lockout: PasscodeLockout.none);
    }

    final failures = attempts.failures + 1;
    final wait = PasscodeAttemptPolicy.waitAfter(failures);
    final retryAt = wait == null ? null : _now().add(wait);
    try {
      await _storage.write(_attemptsKey(accountId), '$failures:${retryAt?.millisecondsSinceEpoch ?? 0}');
    } catch (_) {
      // 保存領域の異常。読めない状態なら照合も失敗するため、ここでは止めない。
    }
    return PasscodeAttemptResult(matched: false, lockout: _lockoutOf(failures, retryAt));
  }

  PasscodeLockout _lockoutOf(int failures, DateTime? retryAt) =>
      PasscodeLockout(retryAt: retryAt, exhausted: failures >= PasscodeAttemptPolicy.maxFailures);

  /// 保存している誤りの回数と、次に入力できる時刻
  Future<({int failures, DateTime? retryAt})> _readAttempts(String accountId) async {
    try {
      final parts = (await _storage.read(_attemptsKey(accountId)))?.split(':');
      final failures = int.tryParse(parts?.first ?? '') ?? 0;
      final retryAtMillis = parts != null && parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return (
        failures: failures,
        retryAt: retryAtMillis == 0 ? null : DateTime.fromMillisecondsSinceEpoch(retryAtMillis),
      );
    } catch (_) {
      return (failures: 0, retryAt: null);
    }
  }

  Future<void> _clearAttempts(String accountId) async {
    try {
      await _storage.delete(_attemptsKey(accountId));
    } catch (_) {
      // 消せなくても、次の起動で読めるようになれば正しい回数のまま動く。
    }
  }

  /// [passcode]が保存済みのパスコードと一致するか
  /// 未設定・保存値の破損・読み取りの失敗ならfalse
  Future<bool> verify(String accountId, String passcode) async {
    try {
      final stored = await _storage.read(_key(accountId));
      if (stored == null) return false;
      final separator = stored.indexOf(':');
      if (separator <= 0) return false;
      final salt = stored.substring(0, separator);
      final expected = stored.substring(separator + 1);
      return _constantTimeEquals(expected, _hash(accountId, salt, passcode));
    } catch (_) {
      return false;
    }
  }

  /// パスコードの設定を削除する（OFFの確認の成功後・アカウント削除・退会・SMS再認証での解除）
  /// 保存領域が壊れて個別の削除に失敗した場合は、鍵の保存先も含めて領域ごと消して復帰を優先する（[PasscodeStorage.deleteAll]。他のアカウントのパスコードも消えるが、鍵の不整合の状態ではどれも読めない）。消去まで失敗したら例外を投げる
  Future<void> remove(String accountId) async {
    try {
      await _storage.delete(_key(accountId));
      await _storage.delete(_attemptsKey(accountId));
    } catch (_) {
      await _storage.deleteAll();
    }
  }

  static String _hash(String accountId, String salt, String passcode) =>
      sha256.convert(utf8.encode('$salt:$accountId:$passcode')).toString();

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
