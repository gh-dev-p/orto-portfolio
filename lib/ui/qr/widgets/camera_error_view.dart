import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../l10n/app_localizations.dart';

/// カメラを使えないときの表示
/// カメラの使用が許可されていない・カメラを使えない、のどちらかを出す
class CameraErrorView extends StatelessWidget {
  const CameraErrorView({super.key, required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = error.errorCode == MobileScannerErrorCode.permissionDenied
        ? l10n.qrcCameraPermissionDenied
        : l10n.qrcCameraUnavailable;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
