import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../themes/app_metrics.dart';
import '../../../l10n/app_localizations.dart';
import '../themes/app_colors.dart';
import 'count_badge.dart';
import 'press_opacity.dart';

/// 画面設計書 2章「ボトムナビゲーション」：チャット一覧／フレンド一覧／設定の3タブ。
///
/// 画面設計書4章補足の通り、タブ切替はNavigatorのpush/popを使わず表示切替のみで行うため、
/// タップ時の実際の切替処理は呼び出し元（[onTap]）に委譲する。
///
/// CHA-01のボトムナビ「チャット」タブには未読合計バッジ（[chatUnreadCount]）を表示する
/// （データ設計書3.2.4）。集計は呼び出し元（[HomeShell]）が行う。
/// グループへの招待が届いている間（[chatHasGroupRequest]）は、未読合計に代えて「!」を表示する。
/// 友だち申請が届いている間（[friendHasRequest]、機能仕様書4.3.8.2）は、「友だち」タブに「!」を表示する。
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.chatUnreadCount,
    required this.chatHasGroupRequest,
    this.friendHasRequest = false,
    required this.onTap,
  });

  final int currentIndex;
  final int chatUnreadCount;
  final bool chatHasGroupRequest;
  final bool friendHasRequest;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      // トークは角の丸い吹き出し（Materialの吹き出しは角張って硬く見えるため、iOSのメッセージに近いCupertinoのものを使う）
      (icon: CupertinoIcons.chat_bubble, selectedIcon: CupertinoIcons.chat_bubble_fill, label: l10n.bottomNavChatTab),
      (icon: Icons.people_outline, selectedIcon: Icons.people, label: l10n.bottomNavFriendTab),
      (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: l10n.bottomNavSettingsTab),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [BoxShadow(color: context.colors.shadow, blurRadius: 32, offset: Offset(0, -8))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppMetrics.bottomNavHorizontalPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < items.length; i++)
                  _NavItem(
                    icon: items[i].icon,
                    selectedIcon: items[i].selectedIcon,
                    label: items[i].label,
                    selected: i == currentIndex,
                    badgeCount: i == 0 ? chatUnreadCount : 0,
                    badgeAttention: (i == 0 && chatHasGroupRequest) || (i == 1 && friendHasRequest),
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
    this.badgeAttention = false,
  });

  /// 非選択時のアイコン（outline系）。選択時は[selectedIcon]（中塗り版）に切り替える。
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;
  final bool badgeAttention;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colors.primaryText : context.colors.secondaryText.withValues(alpha: 0.5);
    return PressOpacity(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 24),
                if (badgeCount > 0 || badgeAttention)
                  Positioned(
                    left: AppMetrics.bottomNavBadgeLeft,
                    top: -4,
                    child: CountBadge(count: badgeCount, attention: badgeAttention),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
