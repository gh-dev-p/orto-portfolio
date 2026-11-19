import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../data/repositories/passcode/passcode_repository.dart';
import '../../account/view_models/active_account_provider.dart';

// ============================================================
// enum・定数
// ============================================================

/// パスコードの桁数
/// テンキーの表示・入力完了の判定に使う
const passcodeLength = PasscodeRepository.length;

/// バックグラウンドからこの時間以上経って戻ったら、解除をやり直す（機能仕様書4.2.4.3）
/// カメラやSMSアプリとの行き来で毎回ロックされないよう、少し猶予を持たせる
const passcodeRelockAfter = Duration(minutes: 1);

/// 使用中のアカウントに対する、パスコードのガードの状態
enum PasscodeGuardStatus {
  /// ガード不要（使用中のアカウントが無い・パスコード未設定・解除済み）
  open,

  /// パスコードの有無を確認中
  /// 確認できるまでは画面を見せない
  checking,

  /// パスコードの入力が必要
  locked,
}

// ============================================================
// Notifier
// ============================================================

/// 今回の起動中にパスコードで解除済みのアカウントIDを持つNotifier
/// アプリ全体で共有し、起動時はnull（未解除）から始める
///
/// 使用中のアカウントが切り替わるたびに解除状態を破棄する（切り替えのたびに、切り替え先のパスコードを求める。パスコード付きのAから別のアカウントを経由してAに戻った場合も再入力になる）
class UnlockedAccountNotifier extends Notifier<String?> {

  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  /// 未解除（null）から始め、使用中のアカウントの切り替えを監視する
  @override
  String? build() {
    ref.listen<String?>(activeAccountIdProvider, (previous, next) {
      if (previous != next) lock();
    });
    return null;
  }

  // ---- 操作 ----

  /// アカウント[accountId]を解除済みにする
  /// パスコードの照合に成功したとき・パスコードを設定した直後・「パスコードを忘れた場合」の再認証の後に呼ぶ
  void unlock(String accountId) => state = accountId;

  /// 解除状態を破棄する
  /// パスコードを設定したアカウントには、もう一度入力を求める（通知のタップで開く場合等）
  void lock() => state = null;

  // ---- バックグラウンド ----

  /// バックグラウンドに移った時刻
  DateTime? _hiddenAt;

  /// アプリが画面から隠れたときに呼ぶ
  void onHidden() => _hiddenAt ??= ref.read(passcodeClockProvider)();

  /// アプリが画面に戻ったときに呼ぶ
  /// [passcodeRelockAfter]以上経っていれば、解除状態を破棄する
  void onResumed() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null) return;
    if (ref.read(passcodeClockProvider)().difference(hiddenAt) >= passcodeRelockAfter) lock();
  }
}

// ============================================================
// Provider
// ============================================================

/// 今の時刻（テストで差し替える）
final passcodeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// [UnlockedAccountNotifier]のProvider
/// アプリ全体で共有するため、破棄しない
final unlockedAccountIdProvider = NotifierProvider<UnlockedAccountNotifier, String?>(UnlockedAccountNotifier.new);

/// アカウント（アカウントIDがキー）にパスコードが設定されているか
/// 設定・削除のたびに[PasscodeRepository]が流し直す
final passcodeEnabledProvider = StreamProvider.family<bool, String>(
  (ref, accountId) => ref.watch(passcodeRepositoryProvider).watchEnabled(accountId),
);

/// 使用中のアカウントに対するパスコードのガードの状態
/// [PasscodeGuard]が画面全体を覆うかを決める
final passcodeGuardStatusProvider = Provider<PasscodeGuardStatus>((ref) {
  final activeId = ref.watch(activeAccountIdProvider);
  // 使用中のアカウントが無い間も、解除状態の監視（アカウントの切り替えでの破棄）を始めておく。
  final unlockedId = ref.watch(unlockedAccountIdProvider);
  if (activeId == null) return PasscodeGuardStatus.open;
  if (unlockedId == activeId) return PasscodeGuardStatus.open;

  final enabled = ref.watch(passcodeEnabledProvider(activeId));
  final value = enabled.value;
  if (value != null) return value ? PasscodeGuardStatus.locked : PasscodeGuardStatus.open;
  // 読み取りに失敗した場合は、素通りさせずロック扱いにする（SMS再認証で復帰できる）。
  if (enabled.hasError) return PasscodeGuardStatus.locked;
  return PasscodeGuardStatus.checking;
});
