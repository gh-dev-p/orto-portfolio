import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/view_models/active_account_provider.dart';
import 'passcode_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// パスコードのガードの状態
class PasscodeGuardState {
  const PasscodeGuardState({required this.status, required this.accountId});

  /// ガードの状態（開いている・確認中・入力が必要）
  final PasscodeGuardStatus status;

  /// 使用中のアカウントID
  /// 使用中のアカウントが無ければnull
  final String? accountId;
}

// ============================================================
// ViewModel
// ============================================================

/// パスコードのガード（機能仕様書4.2.4）のViewModel
/// 使用中のアカウントにパスコードが設定されていて、今回まだ解除していない間だけ、画面全体をAUT-04で覆うかを決める
class PasscodeGuardViewModel extends Notifier<PasscodeGuardState> {

  // ---- 状態・初期化 ----

  /// 表示内容を作る
  /// 使用中のアカウントと、ガードの状態を監視し、変わるたびに作り直す
  @override
  PasscodeGuardState build() {
    return PasscodeGuardState(
      status: ref.watch(passcodeGuardStatusProvider),
      accountId: ref.watch(activeAccountIdProvider),
    );
  }
}

// ============================================================
// Provider
// ============================================================

/// [PasscodeGuardViewModel]のProvider
/// ガードはアプリを開いている間ずっと表示するため、破棄しない
final passcodeGuardViewModelProvider = NotifierProvider<PasscodeGuardViewModel, PasscodeGuardState>(
  PasscodeGuardViewModel.new,
);
