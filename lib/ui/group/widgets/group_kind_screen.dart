import 'package:flutter/material.dart';

import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/press_opacity.dart';
import 'group_friend_picker_screen.dart';

// ============================================================
// 画面
// ============================================================

/// 画面GRP-06：グループの種類（機能仕様書4.7.8.1 / 画面設計書5.10.6）
/// 普通のグループとオフ会グループを説明つきで並べ、押した種類でGRP-01へ進む
class GroupKindScreen extends StatelessWidget {
  const GroupKindScreen({super.key, required this.myAccountId});

  final String myAccountId;

  void _select(BuildContext context, GroupKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupFriendPickerScreen(myAccountId: myAccountId, kind: kind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppScreenAppBar(title: l10n.grpKindTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _KindCard(
              key: const Key('group-kind-standard'),
              icon: Icons.forum_outlined,
              title: l10n.grpKindStandard,
              description: l10n.grpKindStandardDescription,
              onTap: () => _select(context, GroupKind.standard),
            ),
            const SizedBox(height: 12),
            _KindCard(
              key: const Key('group-kind-meetup'),
              icon: Icons.event_outlined,
              title: l10n.grpKindMeetup,
              description: l10n.grpKindMeetupDescription,
              onTap: () => _select(context, GroupKind.meetup),
            ),
            const SizedBox(height: 16),
            Text(l10n.grpKindFixedNote, style: context.textStyles.captionRegular, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// 種類1つ分のカード（アイコン・名前・説明）
class _KindCard extends StatelessWidget {
  const _KindCard({super.key, required this.icon, required this.title, required this.description, required this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressOpacity(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: context.colors.accent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.titleBold),
                  const SizedBox(height: 4),
                  Text(description, style: context.textStyles.description),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.secondaryText),
          ],
        ),
      ),
    );
  }
}
