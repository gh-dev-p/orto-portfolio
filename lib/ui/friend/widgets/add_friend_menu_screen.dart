import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_metrics.dart';
import '../../core/themes/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../qr/widgets/qr_scan_screen.dart';
import 'friend_search_screen.dart';

// ============================================================
// 画面
// ============================================================

/// 画面FRI-02：友だち追加メニュー（ボトムシート）を開く
/// 検索（FRI-04）・QRコード（QRC-01、読み取りから開く）への入口で、どちらもシートの上に全画面で重ねて開く
///
/// 招待（FRI-03）はこのシートではなく、AppHomeHeaderの＋メニューに「友だち追加」と並べて置く
/// 表示するデータが無いため、ViewModelは持たない
///
/// 機能仕様書：4.3.1 / 画面設計書：5.4.2
Future<void> showAddFriendMenu(BuildContext context, {required String myAccountId}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    builder: (context) => _AddFriendMenuSheet(myAccountId: myAccountId),
  );
}

/// 友だち追加メニューのシートの中身
class _AddFriendMenuSheet extends StatelessWidget {
  const _AddFriendMenuSheet({required this.myAccountId});

  final String myAccountId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: SizedBox()),
                Expanded(
                  flex: 2,
                  child: Text(l10n.friAddMenuTitle, textAlign: TextAlign.center, style: context.textStyles.h1),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppMetrics.addFriendMenuHorizontalPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MenuIcon(
                    icon: Icons.search,
                    label: l10n.commonSearch,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => FriendSearchScreen(myAccountId: myAccountId)),
                    ),
                  ),
                  _MenuIcon(
                    icon: Icons.qr_code_scanner,
                    label: l10n.friAddMenuQrCode,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => QrScanScreen(myAccountId: myAccountId)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// メニューの項目
/// 丸いアイコンの下にラベルを置く
class _MenuIcon extends StatelessWidget {
  const _MenuIcon({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: context.colors.background, shape: BoxShape.circle),
              child: Icon(icon, color: context.colors.primaryText, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: context.textStyles.captionRegular,
            ),
          ],
        ),
      ),
    );
  }
}
