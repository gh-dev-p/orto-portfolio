// ============================================================
// 例外クラス
// ============================================================

/// 作成しようとしたアカウントIDが、既に使われていることを表す例外
/// 使用可能の事前確認の後に、他のユーザが先に使った場合などに[AccountRepository.createAccount]が投げる
class AccountIdTakenException implements Exception {
  const AccountIdTakenException();
}

/// アカウントの削除を繰り返したため、しばらく新しいアカウントを作れない（機能仕様書4.2.3）
class AccountCreationBlockedException implements Exception {
  const AccountCreationBlockedException();
}
