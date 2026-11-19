import '../../data/repositories/auth/auth_repository.dart';
import '../../data/repositories/notification/notification_repository.dart';
import '../../data/services/common/firestore_cache_cleaner.dart';

// ============================================================
// UseCase
// ============================================================

/// 管理者のログアウト（機能仕様書4.1.7）
/// SET-01のViewModelから使い、[NotificationRepository]と[AuthRepository]を組み合わせる
///
/// この端末のFCMトークンを外してからサインアウトする（Firestoreのルールが、ログイン中の保有ユーザにだけ削除を許すため）
/// 外せなければサインアウトせず、例外を投げる（ログアウトした端末に通知が届き続けないようにするため）
/// 端末のFirestoreのキャッシュは、次の起動で消す（[FirestoreCacheCleaner]。起動中は監視が動いていて消せないため）
/// アクティブアカウントの記録の消去は、呼び出し元のViewModelが行う（アクティブアカウントはViewModel層のNotifierが持つため）
///
/// パスコードは消さない。端末に残すことで、ログアウトと再ログインでロックを回避できないようにする
class LogoutUseCase {
  LogoutUseCase(this._authRepository, this._notificationRepository, this._cacheCleaner);

  // ---- 状態・初期化 ----

  /// ログインのリポジトリ
  final AuthRepository _authRepository;

  /// プッシュ通知のリポジトリ
  final NotificationRepository _notificationRepository;

  /// 端末のFirestoreのキャッシュの消去
  final FirestoreCacheCleaner _cacheCleaner;

  // ---- 実行 ----

  /// 保有するアカウント[accountIds]からこの端末のFCMトークンを外し、サインアウトする
  Future<void> call(List<String> accountIds) async {
    await _notificationRepository.unregisterToken(accountIds);
    await _cacheCleaner.request();
    await _authRepository.signOut();
  }
}
