import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/models/announcement.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_snack_bar.dart';

// ============================================================
// 処理
// ============================================================

/// 地図アプリの選択肢（iOSのシート）
enum _MapChoice { apple, google, copy }

/// 場所[place]を地図アプリで検索して開く（機能仕様書4.7.8.4）
/// iOSは「Apple マップ」「Google マップ」「場所をコピー」から選ぶシートを出し、Androidは端末の地図アプリ（`geo:`）で開く。
/// [isIOS]・[launch]はテスト用の差し替え
Future<void> openPlaceInMaps(
  BuildContext context,
  String place, {
  bool? isIOS,
  Future<bool> Function(Uri uri)? launch,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final doLaunch = launch ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> open(Uri uri) async {
    try {
      if (!await doLaunch(uri)) throw Exception('launch returned false');
    } catch (error) {
      debugPrint('[PlaceLink] failed to launch maps: $error');
      messenger.showSnackBar(buildAppSnackBar(l10n.annMapOpenFailed));
    }
  }

  if (!(isIOS ?? Platform.isIOS)) {
    await open(MapSearchLinks.geo(place));
    return;
  }
  final choice = await showModalBottomSheet<_MapChoice>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(place, style: context.textStyles.titleMedium, textAlign: TextAlign.center),
          ),
          ListTile(
            leading: Icon(Icons.map_outlined, color: context.colors.primaryText),
            title: Text(l10n.annOpenAppleMaps),
            onTap: () => Navigator.of(context).pop(_MapChoice.apple),
          ),
          ListTile(
            leading: Icon(Icons.travel_explore, color: context.colors.primaryText),
            title: Text(l10n.annOpenGoogleMaps),
            onTap: () => Navigator.of(context).pop(_MapChoice.google),
          ),
          ListTile(
            leading: Icon(Icons.copy_outlined, color: context.colors.primaryText),
            title: Text(l10n.annCopyPlace),
            onTap: () => Navigator.of(context).pop(_MapChoice.copy),
          ),
        ],
      ),
    ),
  );
  switch (choice) {
    case _MapChoice.apple:
      await open(MapSearchLinks.apple(place));
    case _MapChoice.google:
      await open(MapSearchLinks.google(place));
    case _MapChoice.copy:
      await _copyPlace(messenger, l10n, place);
    case null:
      return;
  }
}

Future<void> _copyPlace(ScaffoldMessengerState messenger, AppLocalizations l10n, String place) async {
  await Clipboard.setData(ClipboardData(text: place));
  messenger.showSnackBar(buildAppSnackBar(l10n.commonCopied));
}

// ============================================================
// 部品
// ============================================================

/// 押すと地図アプリで検索する場所の文字（長押しでコピー）
class PlaceLink extends StatelessWidget {
  const PlaceLink({super.key, required this.place, this.maxLines = 2});

  final String place;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final style = context.textStyles.bodyRegular.copyWith(
      color: context.colors.accent,
      decoration: TextDecoration.underline,
      decorationColor: context.colors.accent,
    );
    return Semantics(
      link: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openPlaceInMaps(context, place),
        onLongPress: () => _copyPlace(ScaffoldMessenger.of(context), AppLocalizations.of(context)!, place),
        child: Text(place, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
