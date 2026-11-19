/// `appConfig/version`ドキュメント。データ設計書3.7参照。
/// 動かせる最低のアプリのバージョンと、更新先のストアのURLを持つ。
class AppVersionPolicy {
  const AppVersionPolicy({required this.minimumVersion, this.iosStoreUrl, this.androidStoreUrl});

  /// 動かせる最低のバージョン（`1.1.0`の形式）。これより古いアプリにはAUT-06を表示する。
  final String minimumVersion;

  final String? iosStoreUrl;
  final String? androidStoreUrl;

  factory AppVersionPolicy.fromMap(Map<String, dynamic> map) => AppVersionPolicy(
    minimumVersion: map['minimumVersion'] as String? ?? '',
    iosStoreUrl: map['iosStoreUrl'] as String?,
    androidStoreUrl: map['androidStoreUrl'] as String?,
  );

  /// [currentVersion]のアプリが更新を必要とするか。
  /// どちらかのバージョンを読み取れないときは、アプリを止めないよう更新不要として扱う。
  bool requiresUpdate(String currentVersion) {
    final current = _parse(currentVersion);
    final minimum = _parse(minimumVersion);
    if (current == null || minimum == null) return false;
    for (var i = 0; i < _segments; i++) {
      if (current[i] != minimum[i]) return current[i] < minimum[i];
    }
    return false;
  }

  static const _segments = 3;

  /// `1.2.3`を3つの数に分ける。足りない桁は0とし、数でないものが混ざればnull。
  static List<int>? _parse(String version) {
    if (version.isEmpty) return null;
    final parts = version.split('.').map(int.tryParse).toList();
    if (parts.length > _segments || parts.contains(null)) return null;
    return [...parts.cast<int>(), ...List.filled(_segments - parts.length, 0)];
  }
}
