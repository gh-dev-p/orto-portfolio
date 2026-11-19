import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../passcode/view_models/passcode_providers.dart';

// ============================================================
// enum
// ============================================================

/// SET-03（パスコード設定）で数字を入力した結果
enum PasscodeSetupResult {
  /// まだ桁がそろっていない・1回目を入力し終えた・2回目が1回目と違った（画面に留まる）
  pending,
  /// 設定できた（画面を閉じる）
  saved,
  /// 保存に失敗した（1回目からやり直す）
  failed,
}

// ============================================================
// 状態クラス
// ============================================================

/// SET-03（パスコード設定）の状態
class PasscodeSetupState {
  const PasscodeSetupState({this.digits = '', this.confirming = false, this.mismatch = false, this.busy = false});

  /// 入力中のパスコード
  final String digits;

  /// 2回目（確認）の入力中か
  /// falseなら1回目の入力中
  final bool confirming;

  /// 直前の2回目の入力が、1回目と違ったか
  /// trueの間、不一致の表示を出す
  final bool mismatch;

  /// 保存中か
  /// trueの間は入力を受け付けない
  final bool busy;
}

// ============================================================
// ViewModel
// ============================================================

/// SET-03（パスコード設定）のViewModel
/// 新しいパスコード（4桁）を2回入力させ、一致したら端末に保存する（不一致なら1回目からやり直す）
///
/// 機能仕様書：4.2.4 / 画面設計書：5.6.3
class PasscodeSetupViewModel extends Notifier<PasscodeSetupState> {
  PasscodeSetupViewModel(this.accountId);

  // ---- 状態・初期化 ----

  /// 対象のアカウントID
  final String accountId;

  /// 1回目に入力したパスコード
  /// 1回目の入力中はnull
  String? _first;

  /// 最初の状態を作る
  /// 1回目の入力から始める
  @override
  PasscodeSetupState build() => const PasscodeSetupState();

  // ---- 入力 ----

  /// 数字を1つ入力する
  /// 2回目の桁がそろって1回目と一致したら保存し、結果を返す
  Future<PasscodeSetupResult> inputDigit(int digit) async {
    if (state.busy || state.digits.length >= passcodeLength) return PasscodeSetupResult.pending;
    final entered = '${state.digits}$digit';
    if (entered.length < passcodeLength) {
      state = PasscodeSetupState(digits: entered, confirming: state.confirming);
      return PasscodeSetupResult.pending;
    }

    final first = _first;
    if (first == null) {
      _first = entered;
      state = const PasscodeSetupState(confirming: true);
      return PasscodeSetupResult.pending;
    }
    if (entered != first) {
      _first = null;
      state = const PasscodeSetupState(mismatch: true);
      return PasscodeSetupResult.pending;
    }

    state = PasscodeSetupState(digits: entered, confirming: true, busy: true);
    try {
      // 設定した直後に自分がロックされないよう、保存の前にこのアカウントを解除済みにしておく。
      ref.read(unlockedAccountIdProvider.notifier).unlock(accountId);
      await ref.read(passcodeRepositoryProvider).save(accountId, entered);
      return PasscodeSetupResult.saved;
    } catch (error) {
      // 保存に失敗した場合は、設定されていない状態のまま1回目からやり直せるようにする。
      // 黙って戻ると原因が分からないため、ログにも残す。
      debugPrint('[Passcode] enable failed: $error');
      _first = null;
      if (ref.mounted) state = const PasscodeSetupState();
      return PasscodeSetupResult.failed;
    }
  }

  /// 最後の数字を1つ消す
  /// 保存中・何も入力していないときは何もしない
  void deleteDigit() {
    if (state.busy || state.digits.isEmpty) return;
    state = PasscodeSetupState(
      digits: state.digits.substring(0, state.digits.length - 1),
      confirming: state.confirming,
    );
  }
}

// ============================================================
// Provider
// ============================================================

/// [PasscodeSetupViewModel]のProvider
/// 引数は対象のアカウントID。誰も監視しなくなったら破棄される（autoDispose）
final passcodeSetupViewModelProvider =
    NotifierProvider.autoDispose.family<PasscodeSetupViewModel, PasscodeSetupState, String>(
      PasscodeSetupViewModel.new,
    );
