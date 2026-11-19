import '../../../domain/models/app_version_policy.dart';
import '../../services/common/firestore_paths.dart';

/// アプリ全体の設定（`appConfig`、データ設計書3.7）を読む。
class AppConfigRepository {
  const AppConfigRepository(this._paths);

  final FirestorePaths _paths;

  /// 最低バージョンの設定を監視する。ドキュメントが無ければnull。
  Stream<AppVersionPolicy?> watchVersionPolicy() => _paths.appConfigVersion.snapshots().map((doc) {
    final data = doc.data();
    return data == null ? null : AppVersionPolicy.fromMap(data);
  });
}
