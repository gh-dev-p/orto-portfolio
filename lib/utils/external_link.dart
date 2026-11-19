import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../ui/core/ui/app_snack_bar.dart';

/// 外部（メールアプリ・ブラウザ等）を起動する。起動できなかった場合はSnackBarで案内する
/// （SET-01のお問い合わせ・プライバシーポリシー・利用規約）。
///
/// [launch]はテスト用の差し替え（既定は`url_launcher`の[launchUrl]）。
Future<void> openExternalLink(
  BuildContext context,
  Uri uri, {
  Future<bool> Function(Uri uri, {required LaunchMode mode})? launch,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final doLaunch = launch ?? (u, {required mode}) => launchUrl(u, mode: mode);
  try {
    final launched = await doLaunch(uri, mode: LaunchMode.externalApplication);
    if (!launched) throw Exception('launch returned false');
  } catch (error) {
    debugPrint('[ExternalLink] failed to launch $uri: $error');
    messenger.showSnackBar(buildAppSnackBar(l10n.setLinkOpenFailed));
  }
}
