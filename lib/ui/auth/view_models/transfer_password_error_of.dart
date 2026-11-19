import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/transfer_password_error.dart';

// ============================================================
// 関数
// ============================================================

/// [AsyncValue]のエラーを、引き継ぎパスワードのエラー種別に変換する
/// エラーがなければnull（[TransferPasswordException]以外の例外は通信エラー扱い）。AUT-05・SET-05のViewModelの状態に使う
TransferPasswordError? transferPasswordErrorOf(AsyncValue<void> state) {
  if (!state.hasError) return null;
  final error = state.error;
  return error is TransferPasswordException ? error.error : TransferPasswordError.network;
}
