import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth/auth_repository.dart';
import '../../../config/service_providers.dart';
import '../../../domain/use_cases/complete_phone_verification_use_case.dart';

// ============================================================
// Provider
// ============================================================

/// Firebase Authenticationのログイン状態
/// AuthGate（画面設計書5.1.1 スプラッシュ画面の判定）が監視して、表示する画面を切り替える
final authStateChangesProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// 引き継ぎパスワードの状態
/// ログイン状態が変わるたびに読み直す（パスワードの確認・登録の後は[refreshTransferPasswordStatus]で取り直す）
final transferPasswordStatusProvider = FutureProvider<TransferPasswordStatus>((ref) async {
  ref.watch(authStateChangesProvider.select((async) => async.value?.uid));
  return ref.watch(authRepositoryProvider).transferPasswordStatus();
});

/// ログイン中のユーザが管理者か（機能仕様書4.1.7）
/// ログイン状態が変わるたびと、アプリが前面に戻るたびに読み直す。読めなければエラーになり、画面では管理者ではない扱いにする
///
/// [SettingsBody]はホームのIndexedStackに常にあるため、タブを開いても読み直されない。前面に戻ったときに読むことで、
/// アプリを終了しなくても、クレームの設定後にIDトークンが更新された時点で反映し、読み取りの失敗からも戻る
/// トークンの強制更新はしない（一般の利用者の通信を増やさないため）
final isAdminProvider = FutureProvider<bool>((ref) async {
  final listener = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(listener.dispose);
  ref.watch(authStateChangesProvider.select((async) => async.value?.uid));
  return ref.watch(authRepositoryProvider).isAdmin();
});

/// ログイン中のユーザ
/// [authStateChangesProvider]と異なり、電話番号の変更でも更新される（SET-01の電話番号表示用）
final currentUserProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).userChanges;
});

// ============================================================
// 関数
// ============================================================

/// IDトークンを取り直して、[transferPasswordStatusProvider]を更新する
/// Cloud Functionsでクレームを変えた直後（パスワードの確認・登録、確認済みの状態の引き継ぎ）に呼ぶ
Future<void> refreshTransferPasswordStatus(Ref ref) async {
  await ref.read(authRepositoryProvider).transferPasswordStatus(forceRefresh: true);
  ref.invalidate(transferPasswordStatusProvider);
  await ref.read(transferPasswordStatusProvider.future);
}

/// SMS認証で目的の処理まで完了した後の後処理を行う
/// [CompletePhoneVerificationUseCase]を実行し、引き継ぎパスワードの状態が変わったら取り直す（AUT-02・AUT-03・AUT-04のViewModelから呼ぶ）
///
/// サインインの後処理はない（AuthGateが画面を切り替え、呼び出し元のViewModelが破棄されることがある）ため、何もしない
Future<void> completePhoneVerification(Ref ref, PhoneVerificationPurpose purpose) async {
  if (purpose == PhoneVerificationPurpose.signIn || !ref.mounted) return;
  final carriedOver = await ref.read(completePhoneVerificationUseCaseProvider).call(purpose);
  if (!carriedOver) return;
  try {
    await refreshTransferPasswordStatus(ref);
  } catch (e) {
    debugPrint('[PhoneVerification] refreshTransferPasswordStatus failed: $e');
  }
}
