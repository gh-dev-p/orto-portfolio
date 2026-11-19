import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../view_models/chat_image_providers.dart';

/// トークの画像
/// Storageのパスからダウンロードして表示する（失敗したらタップで読み込み直す）
///
/// 読み込み中・失敗時も[aspectRatio]の枠を先に確保して、一覧の高さが読み込み後にずれないようにする
class ChatImage extends ConsumerWidget {
  const ChatImage({super.key, required this.path, required this.aspectRatio, this.fit = BoxFit.cover, this.errorText});

  final String path;
  final double aspectRatio;
  final BoxFit fit;

  /// 失敗時の文言（省略すると画像の読み込み失敗の文言）
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(chatImageUrlProvider(path));
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: url.when(
        data: (url) => Image.network(
          url,
          fit: fit,
          loadingBuilder: (context, child, progress) => progress == null ? child : const _Placeholder(),
          errorBuilder: (_, _, _) =>
              _LoadError(text: errorText, onRetry: () => ref.invalidate(chatImageUrlProvider(path))),
        ),
        loading: () => const _Placeholder(),
        error: (_, _) => _LoadError(text: errorText, onRetry: () => ref.invalidate(chatImageUrlProvider(path))),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => ColoredBox(color: context.colors.secondaryText.withValues(alpha: 0.15));
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.text, required this.onRetry});

  final String? text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRetry,
      child: ColoredBox(
        color: context.colors.secondaryText.withValues(alpha: 0.15),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, color: context.colors.secondaryText),
              const SizedBox(height: 4),
              Text(
                text ?? AppLocalizations.of(context)!.chaImageLoadFailed,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
