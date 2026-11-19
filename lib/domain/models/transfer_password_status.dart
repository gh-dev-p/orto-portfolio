// ============================================================
// ドメインモデル
// ============================================================

/// 引き継ぎパスワードの状態
/// IDトークンのカスタムクレームから読み取る（[AuthRepository.transferPasswordStatus]）
class TransferPasswordStatus {
  const TransferPasswordStatus({required this.registered, required this.sessionVerified});

  /// 引き継ぎパスワードを登録済みか
  final bool registered;

  /// 今のセッション（この端末のログイン）でパスワードの確認が済んでいるか
  /// 未登録なら常にtrue（falseの間は、firestore.rules・storage.rulesにより何も読み書きできない）
  final bool sessionVerified;
}
