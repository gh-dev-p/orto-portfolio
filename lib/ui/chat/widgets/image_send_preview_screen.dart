import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// 画像の送信前のプレビュー（CHA-02）
/// 選んだ画像を全画面で確かめ、「送信」で`true`を返して閉じる（×・戻るでは`null`で、送らない）
class ImageSendPreviewScreen extends StatelessWidget {
  const ImageSendPreviewScreen({super.key, required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: l10n.commonClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: InteractiveViewer(maxScale: 4, child: Center(child: Image.file(file))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.accent,
                    foregroundColor: context.colors.onAccent,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.send, size: 18),
                  label: Text(l10n.chaImageSendButton),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
