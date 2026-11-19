import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import 'auth_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// copyWithで「errorCodeが指定されなかった」ことを表す目印
const _unset = Object();

/// AUT-03（認証コード入力画面）の状態
class VerificationCodeState {
  const VerificationCodeState({
    required this.purpose,
    this.phoneNumber,
    this.code = '',
    this.confirming = false,
    this.resending = false,
    this.errorCode,
    this.failureCount = 0,
    this.cooldownSeconds = 0,
  });

  /// 何のための認証か
  /// 画面の閉じ方（サインインかそれ以外か）に使う
  final PhoneVerificationPurpose purpose;

  /// 送信先の電話番号（E.164形式）
  final String? phoneNumber;

  /// 入力中の認証コード
  final String code;

  /// 認証コードを確認中か
  final bool confirming;

  /// SMSを再送中か
  final bool resending;

  /// エラーの種類（null：エラーなし）
  /// 表示文言への変換はView側で行う
  final AuthErrorCode? errorCode;

  /// 認証コードの確認に失敗した回数
  /// 3回以上で注意を表示する（SMSを再送できたら0に戻る）
  final int failureCount;

  /// 再送できるようになるまでの残り秒数
  /// 0なら再送できる
  final int cooldownSeconds;

  /// 入力が6桁そろっているか
  /// 前後の空白は除いて数える
  bool get isValid => code.trim().length == 6;

  /// 再送できるか
  /// 待ち時間が過ぎていて、再送中でないときtrue
  bool get canResend => cooldownSeconds <= 0 && !resending;

  /// 指定した項目だけを変えた、新しい状態を作る
  /// 指定しなかった項目は今の値を引き継ぐ（errorCodeはnullを渡すと消える）
  VerificationCodeState copyWith({
    String? code,
    bool? confirming,
    bool? resending,
    Object? errorCode = _unset,
    int? failureCount,
    int? cooldownSeconds,
  }) {
    return VerificationCodeState(
      purpose: purpose,
      phoneNumber: phoneNumber,
      code: code ?? this.code,
      confirming: confirming ?? this.confirming,
      resending: resending ?? this.resending,
      errorCode: identical(errorCode, _unset) ? this.errorCode : errorCode as AuthErrorCode?,
      failureCount: failureCount ?? this.failureCount,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
    );
  }
}

// ============================================================
// ViewModel
// ============================================================

/// AUT-03（認証コード入力画面）のViewModel
/// AUT-02・AUT-04で始めたSMS認証の手続き（[AuthRepository.verificationSession]）を引き継ぎ、認証コードの確認・再送を行う
///
/// 機能仕様書：4.1.1 / 画面設計書：5.1.3
class VerificationCodeViewModel extends Notifier<VerificationCodeState> {

  // ---- 状態・初期化 ----

  /// 再送の待ち時間のカウントダウンタイマー
  Timer? _cooldownTimer;

  /// 最初の状態を作る
  /// 手続き中の状態から、送信先・目的・再送の残り秒数を読み、カウントダウンを始める
  @override
  VerificationCodeState build() {
    ref.onDispose(() => _cooldownTimer?.cancel());
    final session = ref.read(authRepositoryProvider).verificationSession;
    final cooldownSeconds = _remainingSeconds(session?.resendAvailableAt);
    if (cooldownSeconds > 0) _startCooldown();
    return VerificationCodeState(
      purpose: session?.purpose ?? PhoneVerificationPurpose.signIn,
      phoneNumber: session?.phoneNumber,
      cooldownSeconds: cooldownSeconds,
    );
  }

  // ---- 入力 ----

  /// 入力を更新する
  /// 前回のエラー表示は消す
  void updateCode(String code) => state = state.copyWith(code: code, errorCode: null);

  // ---- 確認・再送 ----

  /// 入力された認証コードを確認し、目的の処理（サインイン・再認証・電話番号の差し替え）と後処理を行う
  /// 成功したらtrue。6桁でない・確認中・失敗ならfalse（失敗したらエラーの種類を持ち、失敗回数を1増やす）
  Future<bool> confirm() async {
    if (!state.isValid || state.confirming) return false;
    if (ref.read(authRepositoryProvider).verificationSession?.codeSent != true) return false;
    state = state.copyWith(confirming: true, errorCode: null);

    try {
      await ref.read(authRepositoryProvider).confirmCode(state.code.trim());
      await completePhoneVerification(ref, state.purpose);
      if (ref.mounted) state = state.copyWith(confirming: false);
      return true;
    } on AuthException catch (e) {
      _onConfirmFailed(e.code);
      return false;
    } catch (e) {
      debugPrint('[VerificationCode] confirm failed with non-AuthException: $e');
      _onConfirmFailed(AuthErrorCode.network);
      return false;
    }
  }

  /// 確認の失敗を記録する
  /// エラーの種類を保存し、失敗回数を1増やす
  void _onConfirmFailed(AuthErrorCode errorCode) {
    if (!ref.mounted) return;
    state = state.copyWith(confirming: false, failureCount: state.failureCount + 1, errorCode: errorCode);
  }

  /// 認証コードを再送する
  /// 送信できたら[VerificationStart.codeSent]、端末の自動検証で完了したら[VerificationStart.verified]（後処理まで行う）。再送できない・失敗ならfailed
  Future<VerificationStart> resend() async {
    if (!state.canResend || state.phoneNumber == null) return VerificationStart.failed;
    state = state.copyWith(resending: true, errorCode: null);

    try {
      final result = await ref.read(authRepositoryProvider).resendCode();
      if (result == VerificationStart.verified) await completePhoneVerification(ref, state.purpose);
      if (!ref.mounted) return result;
      if (result == VerificationStart.codeSent) {
        final session = ref.read(authRepositoryProvider).verificationSession;
        state = state.copyWith(
          resending: false,
          failureCount: 0,
          cooldownSeconds: _remainingSeconds(session?.resendAvailableAt),
        );
        _startCooldown();
      } else {
        state = state.copyWith(resending: false);
      }
      return result;
    } on AuthException catch (e) {
      if (ref.mounted) state = state.copyWith(resending: false, errorCode: e.code);
      return VerificationStart.failed;
    }
  }

  // ---- 再送の待ち時間 ----

  /// 再送の待ち時間のカウントダウンを始める
  /// 1秒ごとに残り秒数を手続き中の状態から計算し直し、0になったら止まる
  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted) {
        timer.cancel();
        return;
      }
      final session = ref.read(authRepositoryProvider).verificationSession;
      final next = _remainingSeconds(session?.resendAvailableAt);
      state = state.copyWith(cooldownSeconds: next);
      if (next <= 0) timer.cancel();
    });
  }

  /// [resendAvailableAt]までの残り秒数
  /// 端数は切り上げる（過ぎていれば0）
  static int _remainingSeconds(DateTime? resendAvailableAt) {
    if (resendAvailableAt == null) return 0;
    final remaining = resendAvailableAt.difference(DateTime.now()).inMilliseconds;
    return remaining <= 0 ? 0 : (remaining + 999) ~/ 1000;
  }
}

// ============================================================
// Provider
// ============================================================

/// [VerificationCodeViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final verificationCodeViewModelProvider =
    NotifierProvider.autoDispose<VerificationCodeViewModel, VerificationCodeState>(VerificationCodeViewModel.new);
