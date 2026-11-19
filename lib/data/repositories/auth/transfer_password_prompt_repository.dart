import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// リポジトリ
// ============================================================

/// 引き継ぎパスワードの案内を出したかの記録の保存先のリポジトリ
/// 案内は1回だけ出すため、端末内（SharedPreferences）にuidごとに保存する（機能仕様書4.1.4.1）
class TransferPasswordPromptRepository {
  TransferPasswordPromptRepository(this._preferences);

  // ---- 状態・初期化 ----

  /// 端末内の設定の保存先（起動時に読み込み済み）
  final SharedPreferences _preferences;

  /// 保存に使うキーの接頭辞
  static const _keyPrefix = 'transferPasswordPromptShown.';

  // ---- 読み書き ----

  /// 案内を出したことがあるか
  bool wasShown(String uid) => _preferences.getBool('$_keyPrefix$uid') ?? false;

  /// 案内を出したことを保存する
  Future<void> markShown(String uid) => _preferences.setBool('$_keyPrefix$uid', true);

  /// 次の起動で案内を出す予定にしたときに使うキーの接頭辞
  static const _deferredKeyPrefix = 'transferPasswordPromptDeferred.';

  /// 次の起動で案内を出す予定か
  bool isDeferred(String uid) => _preferences.getBool('$_deferredKeyPrefix$uid') ?? false;

  /// 次の起動で案内を出す予定にする
  Future<void> markDeferred(String uid) => _preferences.setBool('$_deferredKeyPrefix$uid', true);

  /// 次の起動で案内を出す予定を消す
  Future<void> clearDeferred(String uid) => _preferences.remove('$_deferredKeyPrefix$uid');
}
