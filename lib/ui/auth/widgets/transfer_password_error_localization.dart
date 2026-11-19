import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../../../domain/models/transfer_password_error.dart';

// ============================================================
// 関数
// ============================================================

/// [TransferPasswordError]を表示文言に変換する
/// AUT-05・SET-05で共用する
String localizedTransferPasswordError(BuildContext context, TransferPasswordError error) {
  final l10n = AppLocalizations.of(context)!;
  return switch (error) {
    TransferPasswordError.wrong => l10n.transferPasswordErrorWrong,
    TransferPasswordError.locked => l10n.transferPasswordErrorLocked,
    TransferPasswordError.invalid => l10n.transferPasswordErrorInvalid,
    TransferPasswordError.network => l10n.transferPasswordErrorNetwork,
  };
}
