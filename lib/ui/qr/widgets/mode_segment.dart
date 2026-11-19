import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'qr_scan_screen.dart' show QrScreenMode;
import 'segment_button.dart';

/// 画面下部の、読み取り・マイQRコードの切り替え
class ModeSegment extends StatelessWidget {
  const ModeSegment({super.key, required this.mode, required this.onChanged});

  final QrScreenMode mode;
  final ValueChanged<QrScreenMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentButton(
            label: AppLocalizations.of(context)!.qrcSegmentScan,
            selected: mode == QrScreenMode.scan,
            onTap: () => onChanged(QrScreenMode.scan),
          ),
          SegmentButton(
            label: AppLocalizations.of(context)!.commonMyQrCode,
            selected: mode == QrScreenMode.myQr,
            onTap: () => onChanged(QrScreenMode.myQr),
          ),
        ],
      ),
    );
  }
}
