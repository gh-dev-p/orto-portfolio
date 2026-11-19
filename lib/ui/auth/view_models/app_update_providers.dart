import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/app_version_policy.dart';

/// 最低バージョンの設定（`appConfig/version`）
/// 起動中でも更新を求められるよう、監視する
final appVersionPolicyProvider = StreamProvider<AppVersionPolicy?>(
  (ref) => ref.watch(appConfigRepositoryProvider).watchVersionPolicy(),
);

/// 動いているアプリのバージョン
final currentAppVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// 動いているアプリのバージョンとビルド番号（設定画面の表示用、機能仕様書4.6）
/// 最低バージョンの判定は[currentAppVersionProvider]を使う
final currentAppBuildProvider = FutureProvider<({String version, String buildNumber})>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return (version: info.version, buildNumber: info.buildNumber);
});

/// アップデートが必要か（機能仕様書4.1.6）
/// 設定やバージョンを取得できない間・失敗したときはfalseとし、アプリの起動を止めない
final appUpdateRequiredProvider = Provider<bool>((ref) {
  final policy = ref.watch(appVersionPolicyProvider).value;
  final version = ref.watch(currentAppVersionProvider).value;
  if (policy == null || version == null) return false;
  return policy.requiresUpdate(version);
});
