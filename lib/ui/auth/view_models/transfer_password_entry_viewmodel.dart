import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../account/view_models/active_account_provider.dart';
import 'auth_providers.dart';

export 'transfer_password_error_of.dart';

// ============================================================
// 状態クラス
// ============================================================

/// AUT-05（引き継ぎパスワード入力画面）の状態
class TransferPasswordEntryState {
  const TransferPasswordEntryState({this.verification = const AsyncData(null), this.resetAt});

  /// 引き継ぎパスワードの確認の状態
  /// 待機中は`AsyncData(null)`、実行中は`AsyncLoading`、失敗時は`AsyncError`（エラーは[TransferPasswordException]。表示文言への変換はView側で行う）
  final AsyncValue<void> verification;

  /// 再設定の申請で、前のデータを削除する日時
  /// 申請していない・確認できていなければnull
  final DateTime? resetAt;

  /// [resetAt]を変えた状態を返す
  TransferPasswordEntryState withResetAt(DateTime? resetAt) =>
      TransferPasswordEntryState(verification: verification, resetAt: resetAt);
}

// ============================================================
// ViewModel
// ============================================================

/// AUT-05（引き継ぎパスワード入力画面）のViewModel
/// 引き継ぎパスワードの確認と、電話番号の入力に戻る操作を扱う
class TransferPasswordEntryViewModel extends Notifier<TransferPasswordEntryState> {

  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  /// 待機中から始める
  @override
  TransferPasswordEntryState build() => const TransferPasswordEntryState();

  // ---- 操作 ----

  /// 新しい端末でのログイン後に、引き継ぎパスワードを確認する
  /// 成功したらtrue（[transferPasswordStatusProvider]が確認済みになり、AuthGateが通常の画面へ切り替える）。実行中なら何もせずfalse
  Future<bool> verify(String password) async {
    if (state.verification.isLoading) return false;
    state = const TransferPasswordEntryState(verification: AsyncLoading());
    final next = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).verifyTransferPassword(password);
      await refreshTransferPasswordStatus(ref);
    });
    if (ref.mounted) state = TransferPasswordEntryState(verification: next, resetAt: state.resetAt);
    return !next.hasError;
  }

  /// 再設定の申請の状態を読み込む（画面を開いたときに呼ぶ。失敗したら申請なしとして扱う）
  Future<void> loadResetStatus() async {
    try {
      final resetAt = await ref.read(authRepositoryProvider).transferResetStatus();
      if (ref.mounted) state = state.withResetAt(resetAt);
    } catch (_) {
      // 申請の状態は、申請・取り消しのときにも返るので、ここでは出さない
    }
  }

  /// 再設定を申請する（パスワードを忘れた場合、機能仕様書4.1.4.3）
  /// 成功したらtrue。失敗したらfalse（画面で失敗を知らせる）
  Future<bool> requestReset() async {
    try {
      final resetAt = await ref.read(authRepositoryProvider).requestTransferReset();
      if (ref.mounted) state = state.withResetAt(resetAt);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 再設定の申請を取り消す
  /// 成功したらtrue。失敗したらfalse（画面で失敗を知らせる）
  Future<bool> cancelReset() async {
    try {
      await ref.read(authRepositoryProvider).cancelTransferReset();
      if (ref.mounted) state = state.withResetAt(null);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// サインアウトして、AUT-02（電話番号入力画面）に戻る
  /// AUT-05「電話番号の入力に戻る」から呼ぶ（AuthGateがAUT-02へ切り替える）
  ///
  /// 確認前のセッションはルールで何も読み書きできないため、FCMトークンの削除は行わない
  /// 別の電話番号でログインし直したときに、前のユーザ（uid）のアクティブアカウントを引き継がないよう、記録も消す
  Future<void> returnToPhoneInput() async {
    await ref.read(authRepositoryProvider).signOut();
    await ref.read(activeAccountIdProvider.notifier).clear();
  }
}

// ============================================================
// Provider
// ============================================================

/// [TransferPasswordEntryViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final transferPasswordEntryViewModelProvider =
    NotifierProvider.autoDispose<TransferPasswordEntryViewModel, TransferPasswordEntryState>(
  TransferPasswordEntryViewModel.new,
);
