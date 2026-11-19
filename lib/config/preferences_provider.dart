import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端末内に保存した設定（アクティブアカウント・表示言語・画面モード）の読み書き先。
///
/// 起動時（`bootstrap.dart`）に読み込み済みのインスタンスで上書きする。各Notifierが`build`の時点で
/// 保存値を同期的に読めるため、復元が終わるまでの最初の描画で初期値（アカウント未選択・端末の言語等）が
/// 一瞬表示されることが無い。
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProviderは起動時に上書きすること'),
);
