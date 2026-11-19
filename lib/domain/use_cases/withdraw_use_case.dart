import '../../data/repositories/passcode/passcode_repository.dart';
import '../../data/repositories/user/user_repository.dart';
import '../../data/services/common/firestore_cache_cleaner.dart';

// ============================================================
// UseCase
// ============================================================

/// 退会
/// SET-04（退会画面）のViewModelから使い、[UserRepository]と[PasscodeRepository]を組み合わせる
///
/// サーバー側で保有する全アカウント・ユーザ・Firebase Authのユーザーを削除した後、端末内のパスコード設定を消す
/// 端末のFirestoreのキャッシュは、次の起動で消す（[FirestoreCacheCleaner]。起動中は監視が動いていて消せないため）
/// アクティブアカウントの記録の消去とサインアウトは、呼び出し元のViewModelが行う（アクティブアカウントはViewModel層のNotifierが持つため）
class WithdrawUseCase {
  WithdrawUseCase(this._userRepository, this._passcodeRepository, this._cacheCleaner);

  // ---- 状態・初期化 ----

  /// ユーザのリポジトリ
  final UserRepository _userRepository;

  /// パスコードのリポジトリ
  final PasscodeRepository _passcodeRepository;

  /// 端末のFirestoreのキャッシュの消去
  final FirestoreCacheCleaner _cacheCleaner;

  // ---- 実行 ----

  /// 退会し、保有していたアカウント[accountIds]のパスコード設定を消す
  /// サーバー側の削除に失敗したら例外を投げる（パスコードの消去の失敗は無視する）
  Future<void> call(List<String> accountIds) async {
    // 退会の途中でアプリが終了しても消せるよう、先に印を付ける（失敗して残っても、キャッシュを取り直すだけ）。
    await _cacheCleaner.request();
    await _userRepository.withdraw();
    for (final accountId in accountIds) {
      try {
        await _passcodeRepository.remove(accountId);
      } catch (_) {}
    }
  }
}
