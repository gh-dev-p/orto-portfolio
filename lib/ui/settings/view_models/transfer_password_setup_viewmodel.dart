import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../auth/view_models/auth_providers.dart';

export '../../auth/view_models/transfer_password_error_of.dart';

// ============================================================
// ViewModel
// ============================================================

/// SET-05（引き継ぎパスワード設定画面）のViewModel
/// 待機中は`AsyncData(null)`、実行中は`AsyncLoading`、失敗時は`AsyncError`（エラーは[TransferPasswordException]。表示文言への変換はView側で行う）
class TransferPasswordSetupViewModel extends AsyncNotifier<void> {

  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  /// 待機中（`AsyncData(null)`）から始める
  @override
  FutureOr<void> build() {}

  // ---- 操作 ----

  /// 引き継ぎパスワードを登録・変更する
  /// 成功したらtrue（引き継ぎパスワードの状態を取り直す）。実行中なら何もせずfalse
  Future<bool> register(String password) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).registerTransferPassword(password);
      await refreshTransferPasswordStatus(ref);
    });
    if (ref.mounted) state = next;
    return !next.hasError;
  }
}

// ============================================================
// Provider
// ============================================================

/// [TransferPasswordSetupViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final transferPasswordSetupViewModelProvider = AsyncNotifierProvider.autoDispose<TransferPasswordSetupViewModel, void>(
  TransferPasswordSetupViewModel.new,
);
