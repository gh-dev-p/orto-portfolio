import 'package:flutter/foundation.dart';

import '../../data/repositories/auth/auth_repository.dart';
import '../../data/repositories/user/user_repository.dart';

// ============================================================
// UseCase
// ============================================================

/// SMS認証で目的の処理（サインイン・再認証・電話番号の差し替え）まで完了した後の、目的ごとの後処理
/// AUT-02・AUT-03・AUT-04のViewModelで共通に使い、[AuthRepository]と[UserRepository]を組み合わせる
///
/// - サインイン：何もしない（AuthGateが認証状態の変化を検知して次画面へ切り替える）
/// - 再認証：引き継ぎパスワードの確認済みの状態を引き継ぐ
/// - 電話番号の変更：上記に加え、Firestoreの`users/{uid}.phoneNumber`も新しい番号にする
///
/// どの後処理も、失敗しても認証自体は成功として扱う（ログだけ出す）
class CompletePhoneVerificationUseCase {
  CompletePhoneVerificationUseCase(this._authRepository, this._userRepository);

  // ---- 状態・初期化 ----

  /// ログイン（認証）のリポジトリ
  final AuthRepository _authRepository;

  /// ユーザのリポジトリ
  final UserRepository _userRepository;

  // ---- 実行 ----

  /// [purpose]の後処理を行う
  /// 引き継ぎパスワードの確認済みの状態を引き継いだらtrue（呼び出し元で引き継ぎパスワードの状態を取り直す）
  Future<bool> call(PhoneVerificationPurpose purpose) async {
    switch (purpose) {
      case PhoneVerificationPurpose.signIn:
        return false;
      case PhoneVerificationPurpose.reauthentication:
        return _carryOverTransferVerification();
      case PhoneVerificationPurpose.phoneNumberChange:
        final carriedOver = await _carryOverTransferVerification();
        await _syncUserPhoneNumber();
        return carriedOver;
    }
  }

  /// 引き継ぎパスワードの確認済みの状態を引き継ぐ
  /// 失敗しても再認証・変更自体は成功として扱う（その場合は次回の起動時にAUT-05でパスワードを求められる）
  Future<bool> _carryOverTransferVerification() async {
    try {
      return await _authRepository.carryOverTransferVerificationIfNeeded();
    } catch (e) {
      debugPrint('[PhoneVerification] carryOverTransferVerification failed: $e');
      return false;
    }
  }

  /// Firestoreの`users/{uid}.phoneNumber`を新しい番号に更新する
  /// Firebase Auth側の変更は済んでいるため、失敗しても変更自体の失敗としては扱わない
  Future<void> _syncUserPhoneNumber() async {
    final user = _authRepository.currentUser;
    final phoneNumber = user?.phoneNumber;
    if (user == null || phoneNumber == null) return;
    try {
      await _userRepository.updateUserPhoneNumber(user.uid, phoneNumber);
    } catch (e) {
      debugPrint('[PhoneVerification] users.phoneNumber update failed: $e');
    }
  }
}
