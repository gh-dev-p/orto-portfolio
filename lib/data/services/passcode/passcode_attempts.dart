// ============================================================
// モデル
// ============================================================

/// パスコードの入力の制限の状態（機能仕様書4.2.4.5）
class PasscodeLockout {
  const PasscodeLockout({this.retryAt, this.exhausted = false});

  /// 制限なし
  static const none = PasscodeLockout();

  /// 次に入力できる時刻（待たなくてよければnull）
  final DateTime? retryAt;

  /// 回数の上限に達したか
  /// trueなら時間が経っても入力できず、「パスコードを忘れた場合」のSMS再認証でだけ復帰できる
  final bool exhausted;

  /// [now]の時点で入力を受け付けないか
  bool isActiveAt(DateTime now) => exhausted || (retryAt?.isAfter(now) ?? false);
}

/// パスコードを1回照合した結果
class PasscodeAttemptResult {
  const PasscodeAttemptResult({required this.matched, required this.lockout});

  /// 一致したか
  final bool matched;

  /// 照合の後の制限の状態
  final PasscodeLockout lockout;
}

// ============================================================
// 回数ごとの待ち時間
// ============================================================

/// 誤りの回数ごとの制限
/// 回数はアプリの再インストールでも消えないよう、パスコードと同じ保存先（Keychain）に持つ
abstract final class PasscodeAttemptPolicy {
  /// この回数の誤りで、SMS再認証でしか復帰できなくなる
  /// 時刻に依存しないため、端末の時計を進めて待ち時間を飛ばしても、試せる回数はここまで
  static const maxFailures = 10;

  /// 連続して[failures]回誤った後の待ち時間（待たなくてよければnull）
  static Duration? waitAfter(int failures) => switch (failures) {
    < 5 => null,
    5 => const Duration(seconds: 30),
    6 => const Duration(minutes: 1),
    7 => const Duration(minutes: 5),
    8 => const Duration(minutes: 15),
    _ => const Duration(hours: 1),
  };
}
