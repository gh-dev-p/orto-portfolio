import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// リポジトリ
// ============================================================

/// アクティブアカウント（現在操作しているアカウント）の保存先のリポジトリ
/// アプリを再起動しても直前のアクティブアカウントを引き継ぐため、端末内（SharedPreferences）に保存する（機能仕様書4.2.2）
class ActiveAccountRepository {
  ActiveAccountRepository(this._preferences);

  // ---- 状態・初期化 ----

  /// 端末内の設定の保存先（起動時に読み込み済み）
  final SharedPreferences _preferences;

  /// 保存に使うキー
  static const _key = 'activeAccountId';

  // ---- 読み書き ----

  /// 保存しているアクティブアカウントのID
  /// 保存していなければnull（起動時に読み込み済みのため、すぐに返る）
  String? read() => _preferences.getString(_key);

  /// アクティブアカウントのIDを保存する
  Future<void> save(String accountId) => _preferences.setString(_key, accountId);

  /// 保存しているアクティブアカウントのIDを消す
  Future<void> clear() => _preferences.remove(_key);
}
