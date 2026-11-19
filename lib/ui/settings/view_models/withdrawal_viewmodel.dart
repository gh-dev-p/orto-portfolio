import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../domain/models/account.dart';
import '../../account/view_models/account_providers.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../auth/view_models/auth_providers.dart';

// ============================================================
// ViewModel
// ============================================================

/// SET-04（退会画面）のViewModel
/// 待機中は`AsyncData(null)`、実行中は`AsyncLoading`、失敗時は`AsyncError`
class WithdrawalViewModel extends AsyncNotifier<void> {

  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  /// 待機中（`AsyncData(null)`）から始める
  @override
  FutureOr<void> build() {}

  // ---- 操作 ----

  /// ログイン中の電話番号宛に、退会の確認のSMS認証コードを送る（機能仕様書4.1.5）
  /// 結果を返す（[VerificationStart.codeSent]ならAUT-03へ進む。[VerificationStart.verified]なら再認証まで完了している）。
  /// 送れなければ[AsyncError]を状態に入れてfailedを返す
  Future<VerificationStart> startReauthentication() async {
    final repository = ref.read(authRepositoryProvider);
    final phoneNumber = repository.currentUser?.phoneNumber;
    state = const AsyncData(null);
    try {
      if (phoneNumber == null) throw StateError('phone number unavailable');
      final result = await repository.startVerification(
        purpose: PhoneVerificationPurpose.reauthentication,
        phoneNumber: phoneNumber,
      );
      if (result == VerificationStart.verified) {
        await completePhoneVerification(ref, PhoneVerificationPurpose.reauthentication);
      }
      return result;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      return VerificationStart.failed;
    }
  }

  /// 退会する
  /// サーバーが直前の再認証を確かめる（[startReauthentication]の成功の後に呼ぶ）
  /// 成功したらtrue。実行中なら何もせずfalse（AuthGateがAUT-02へ切り替える）
  Future<bool> withdraw() async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    // サーバー側の削除の途中でアカウントが0件になると、AuthGateが本画面を閉じて本ViewModelが破棄される。
    // 破棄後のrefは使えずサインアウトできなくなる（ACC-02に残ってしまう）ため、待つ前に取り出しておく。
    final withdraw = ref.read(withdrawUseCaseProvider);
    final activeAccountId = ref.read(activeAccountIdProvider.notifier);
    final authRepository = ref.read(authRepositoryProvider);
    final next = await AsyncValue.guard(() async {
      await withdraw([for (final account in accounts) account.id]);
      // Firebase Authのユーザーは削除済みのため、端末側の状態を片付けるだけ。
      await activeAccountId.clear();
      await authRepository.signOut();
    });
    if (ref.mounted) state = next;
    return !next.hasError;
  }
}

// ============================================================
// Provider
// ============================================================

/// [WithdrawalViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final withdrawalViewModelProvider = AsyncNotifierProvider.autoDispose<WithdrawalViewModel, void>(
  WithdrawalViewModel.new,
);
