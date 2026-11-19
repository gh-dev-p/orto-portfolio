import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

// ============================================================
// enum
// ============================================================

/// 起動時の入口（AuthGate）で表示する画面の種類
enum AuthGateStatus {
  /// ログイン状態・引き継ぎパスワードの状態を確認中（スプラッシュ画面）
  loading,
  /// ログインしていない（AUT-02 電話番号入力画面）
  /// ログイン状態の確認に失敗した場合もこれにする（画面設計書5.1.1 異常系）
  signedOut,
  /// ログインしたが、引き継ぎパスワードの確認が済んでいない（AUT-05 引き継ぎパスワード入力画面）
  transferPasswordRequired,
  /// ログイン済みで、確認も済んでいる（アカウントの保有状況に応じた画面へ進む）
  /// 引き継ぎパスワードの状態を読めない場合（オフライン等）もこれにする（未確認なら、ルールで読み書きが拒否される）
  signedIn,
}

// ============================================================
// ViewModel
// ============================================================

/// 起動時の入口（AuthGate、画面設計書5.1.1 スプラッシュ画面の判定ロジック）のViewModel
/// ログイン状態と引き継ぎパスワードの状態を監視し、表示する画面の種類を返す
class AuthGateViewModel extends Notifier<AuthGateStatus> {

  // ---- 状態・初期化 ----

  /// 表示する画面の種類を決める
  /// ログイン状態 → 引き継ぎパスワードの状態の順に確認する（ログインしているときだけ、引き継ぎパスワードの状態を監視する）
  @override
  AuthGateStatus build() {
    return ref
        .watch(authStateChangesProvider)
        .when(
          data: (user) {
            if (user == null) return AuthGateStatus.signedOut;
            return ref
                .watch(transferPasswordStatusProvider)
                .when(
                  data: (status) =>
                      status.sessionVerified ? AuthGateStatus.signedIn : AuthGateStatus.transferPasswordRequired,
                  loading: () => AuthGateStatus.loading,
                  error: (_, _) => AuthGateStatus.signedIn,
                );
          },
          loading: () => AuthGateStatus.loading,
          // セッション確認処理のタイムアウト等は電話番号入力画面へフォールバックする（画面設計書5.1.1異常系）。
          error: (_, _) => AuthGateStatus.signedOut,
        );
  }
}

// ============================================================
// Provider
// ============================================================

/// [AuthGateViewModel]のProvider
/// アプリの入口なので、破棄しない
final authGateViewModelProvider = NotifierProvider<AuthGateViewModel, AuthGateStatus>(AuthGateViewModel.new);
