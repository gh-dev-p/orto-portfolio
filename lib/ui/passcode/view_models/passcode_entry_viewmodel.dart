import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../data/repositories/passcode/passcode_repository.dart';
import '../../../domain/models/account.dart';
import '../../account/view_models/account_providers.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../auth/view_models/auth_providers.dart';
import 'passcode_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// copyWithで「errorCodeが指定されなかった」ことを表す目印
const _unset = Object();

/// AUT-04（パスコード入力画面）の状態
class PasscodeEntryState {
  const PasscodeEntryState({
    this.account,
    this.digits = '',
    this.wrong = false,
    this.busy = false,
    this.errorCode,
    this.waitSeconds = 0,
    this.exhausted = false,
  });

  /// 対象のアカウント
  /// アバター・名前の表示に使う（取得前・見つからなければnull）
  final Account? account;

  /// 入力中のパスコード
  final String digits;

  /// 直前に入力したパスコードが誤っていたか
  /// trueの間、誤りの表示を出す
  final bool wrong;

  /// 照合中、または「パスコードを忘れた場合」の再認証中か
  /// trueの間は入力を受け付けない
  final bool busy;

  /// 再認証のSMS送信に失敗したときのエラーの種類（null：エラーなし）
  /// 表示文言への変換はView側で行う
  final AuthErrorCode? errorCode;

  /// 次に入力できるまでの残り秒数（0なら待ちなし）
  final int waitSeconds;

  /// 誤りの回数の上限に達したか
  /// trueなら入力を受け付けず、「パスコードを忘れた場合」でだけ復帰できる
  final bool exhausted;

  /// 入力を受け付けない制限の間か
  bool get restricted => waitSeconds > 0 || exhausted;

  /// 指定した項目だけを変えた、新しい状態を作る
  /// 指定しなかった項目は今の値を引き継ぐ（errorCodeはnullを渡すと消える）
  PasscodeEntryState copyWith({
    Account? account,
    String? digits,
    bool? wrong,
    bool? busy,
    Object? errorCode = _unset,
    int? waitSeconds,
    bool? exhausted,
  }) {
    return PasscodeEntryState(
      account: account ?? this.account,
      digits: digits ?? this.digits,
      wrong: wrong ?? this.wrong,
      busy: busy ?? this.busy,
      errorCode: identical(errorCode, _unset) ? this.errorCode : errorCode as AuthErrorCode?,
      waitSeconds: waitSeconds ?? this.waitSeconds,
      exhausted: exhausted ?? this.exhausted,
    );
  }
}

// ============================================================
// ViewModel
// ============================================================

/// AUT-04（パスコード入力画面）のViewModel
/// パスコードの入力・照合と、「パスコードを忘れた場合」の再認証を扱う
///
/// 機能仕様書：4.2.4 / 画面設計書：5.1.4
class PasscodeEntryViewModel extends Notifier<PasscodeEntryState> {
  PasscodeEntryViewModel(this.accountId);

  // ---- 状態・初期化 ----

  /// 対象のアカウントID
  final String accountId;

  /// 待ち時間のカウントダウン
  Timer? _waitTimer;

  /// 表示内容を作る
  /// 何も入力していない状態から始め、対象のアカウントが読めたら、入力中の内容を残したまま差し替える
  /// 開いた時点の入力の制限も読む（画面を開き直しても制限を引き継ぐ）
  @override
  PasscodeEntryState build() {
    // 作り直すと待ち時間のカウントダウンまで止まるため、watchではなくlistenで差し替える。
    ref.listen(accountByIdProvider(accountId), (_, next) => state = state.copyWith(account: next.value));
    ref.onDispose(() => _waitTimer?.cancel());
    unawaited(_loadLockout());
    return PasscodeEntryState(account: ref.read(accountByIdProvider(accountId)).value);
  }

  /// 保存している入力の制限を読み、画面に反映する
  Future<void> _loadLockout() async {
    final lockout = await ref.read(passcodeRepositoryProvider).lockout(accountId);
    if (ref.mounted) _applyLockout(lockout);
  }

  /// 入力の制限を状態に反映し、待ち時間があれば1秒ごとに数え直す
  void _applyLockout(PasscodeLockout lockout) {
    _waitTimer?.cancel();
    final now = ref.read(passcodeClockProvider)();
    final retryAt = lockout.retryAt;
    final seconds = lockout.exhausted || retryAt == null ? 0 : _secondsUntil(retryAt, now);
    state = state.copyWith(waitSeconds: seconds, exhausted: lockout.exhausted);
    if (seconds == 0 || retryAt == null) return;
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _secondsUntil(retryAt, ref.read(passcodeClockProvider)());
      state = state.copyWith(waitSeconds: remaining);
      if (remaining == 0) timer.cancel();
    });
  }

  /// [now]から[retryAt]までの秒数（端数は切り上げ、過ぎていれば0）
  static int _secondsUntil(DateTime retryAt, DateTime now) {
    final millis = retryAt.difference(now).inMilliseconds;
    return millis <= 0 ? 0 : (millis / 1000).ceil();
  }

  // ---- 入力・照合 ----

  /// 数字を1つ入力する
  /// 桁がそろったら照合し、結果を返す（正しければtrue、誤りならfalseで入力を消す）。まだそろっていない・受け付けない状態ならnull
  Future<bool?> inputDigit(int digit) async {
    if (state.busy || state.restricted || state.digits.length >= passcodeLength) return null;
    state = state.copyWith(digits: '${state.digits}$digit', wrong: false);
    if (state.digits.length < passcodeLength) return null;

    state = state.copyWith(busy: true);
    final result = await ref.read(passcodeRepositoryProvider).attempt(accountId, state.digits);
    if (!ref.mounted) return result.matched;
    state = result.matched ? state.copyWith(busy: false) : state.copyWith(digits: '', wrong: true, busy: false);
    _applyLockout(result.lockout);
    return result.matched;
  }

  /// 最後の数字を1つ消す
  /// 受け付けない状態・何も入力していないときは何もしない
  void deleteDigit() {
    if (state.busy || state.digits.isEmpty) return;
    state = state.copyWith(digits: state.digits.substring(0, state.digits.length - 1), wrong: false);
  }

  /// このアカウントを解除済みにする
  /// ガードとして表示しているときに、照合に成功したら呼ぶ（ガードの覆いが消える）
  void unlock() => ref.read(unlockedAccountIdProvider.notifier).unlock(accountId);

  /// 解除せずに、このアカウントの使用をやめる（ガードの閉じるボタン）
  /// 使用中のアカウントを未選択に戻し、ACC-01（アカウント一覧）で別のアカウントを選べるようにする（パスコードが分からなくても操作を続けられるようにするため）
  Future<void> leave() => ref.read(activeAccountIdProvider.notifier).clear();

  // ---- パスコードを忘れた場合 ----

  /// ログイン中の電話番号宛に、再認証のSMS認証コードを送る
  /// 結果を返す（[VerificationStart.codeSent]ならAUT-03へ進む）。失敗ならfailed（理由はerrorCodeに入る）
  ///
  /// 端末の自動検証で再認証まで完了したら、ここで後処理まで行う。終わったら[finishRecovery]を呼ぶ
  Future<VerificationStart> startRecovery() async {
    if (state.busy) return VerificationStart.failed;
    state = state.copyWith(busy: true, errorCode: null);

    final repository = ref.read(authRepositoryProvider);
    final phoneNumber = repository.currentUser?.phoneNumber;
    if (phoneNumber == null) {
      state = state.copyWith(busy: false, errorCode: AuthErrorCode.signInFailed);
      return VerificationStart.failed;
    }

    try {
      final result = await repository.startVerification(
        purpose: PhoneVerificationPurpose.reauthentication,
        phoneNumber: phoneNumber,
      );
      if (result == VerificationStart.verified) {
        await completePhoneVerification(ref, PhoneVerificationPurpose.reauthentication);
      }
      return result;
    } on AuthException catch (e) {
      if (ref.mounted) state = state.copyWith(busy: false, errorCode: e.code);
      return VerificationStart.failed;
    }
  }

  /// 再認証の結果を受けて、「パスコードを忘れた場合」の手続きを終える
  /// 再認証できていたら（[verified]）、解除済みにしてからパスコードを削除し、ガードなしで先へ進める。削除に失敗したらfalse（それ以外はtrue）
  Future<bool> finishRecovery({required bool verified}) async {
    try {
      if (!verified) return true;
      try {
        // 削除で設定の有無が変わる前に解除済みにし、ガードが一瞬挟まらないようにする。
        unlock();
        await ref.read(passcodeRepositoryProvider).remove(accountId);
        // 誤りの回数も一緒に消える。
        _waitTimer?.cancel();
        if (ref.mounted) state = state.copyWith(waitSeconds: 0, exhausted: false);
        return true;
      } catch (error) {
        // 再認証には成功したが、パスコードを消せなかった（保存領域の復旧に失敗等）。黙って残さず、表示とログを出す。
        debugPrint('[Passcode] reset after recovery failed: $error');
        return false;
      }
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }
}

// ============================================================
// Provider
// ============================================================

/// [PasscodeEntryViewModel]のProvider
/// 引数は対象のアカウントID。誰も監視しなくなったら破棄される（autoDispose）
final passcodeEntryViewModelProvider =
    NotifierProvider.autoDispose.family<PasscodeEntryViewModel, PasscodeEntryState, String>(
      PasscodeEntryViewModel.new,
    );
