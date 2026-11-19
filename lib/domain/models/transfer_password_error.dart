// ============================================================
// enum
// ============================================================

/// 引き継ぎパスワードの確認・登録の失敗の種類
/// 表示文言はView側でAppLocalizations経由に解決する
enum TransferPasswordError {
  /// パスワードが違う
  wrong,
  /// 続けて間違えたため、しばらく受け付けない
  locked,
  /// パスワードの形式が正しくない（文字数）
  invalid,
  /// 通信エラー等
  network,
}

// ============================================================
// 例外クラス
// ============================================================

/// 引き継ぎパスワードの確認・登録の失敗を表す例外
/// 失敗の種類を[error]に持つ
class TransferPasswordException implements Exception {
  const TransferPasswordException(this.error);

  /// 失敗の種類
  final TransferPasswordError error;
}
