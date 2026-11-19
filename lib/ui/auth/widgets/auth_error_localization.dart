import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../../../domain/models/auth_error_code.dart';

// ============================================================
// 関数
// ============================================================

/// [AuthErrorCode]を表示文言に変換する
/// AUT-02・AUT-03・AUT-04（phone_input_screen・verification_code_screen・passcode_entry_screen）で共用する
String localizedAuthError(BuildContext context, AuthErrorCode code) {
  final l10n = AppLocalizations.of(context)!;
  switch (code) {
    case AuthErrorCode.invalidPhoneNumber:
      return l10n.authErrorInvalidPhoneNumber;
    case AuthErrorCode.tooManyRequests:
      return l10n.authErrorTooManyRequests;
    case AuthErrorCode.network:
      return l10n.authErrorNetwork;
    case AuthErrorCode.invalidVerificationCode:
      return l10n.authErrorInvalidVerificationCode;
    case AuthErrorCode.codeExpired:
      return l10n.authErrorCodeExpired;
    case AuthErrorCode.signInFailed:
      return l10n.authErrorSignInFailed;
    case AuthErrorCode.phoneNumberInUse:
      return l10n.authErrorPhoneNumberInUse;
    case AuthErrorCode.samePhoneNumber:
      return l10n.authErrorSamePhoneNumber;
    case AuthErrorCode.unsupportedRegion:
      return l10n.authErrorUnsupportedRegion;
    case AuthErrorCode.accountSuspended:
      return l10n.authErrorAccountSuspended;
  }
}
