import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/unread_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/chat_room.dart';
import 'room_tile_loader.dart';

// ============================================================
// 画面の部品
// ============================================================

/// 「未確認のトークリクエスト」のまとまり
/// 友だちに追加していない相手からメッセージを受け取ったトークをまとめ、タップで開いて並べる（トークを選ぶと、CHA-02がリクエストモードで開く）
class RequestSection extends StatefulWidget {
  const RequestSection({super.key, required this.rooms, required this.myAccountId});

  /// リクエストのトーク
  final List<ChatListEntry> rooms;

  /// 使用中のアカウントID
  final String myAccountId;

  @override
  State<RequestSection> createState() => _RequestSectionState();
}

/// [RequestSection]のState
/// 開いているかどうか（この画面の中だけの表示の状態）を持つ
class _RequestSectionState extends State<RequestSection> {
  /// 開いて、リクエストのトークを並べているか
  bool _expanded = false;

  /// 見出し（件数・未読の合計）と、開いているときはリクエストのトークを描く
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unreadTotal = widget.rooms.fold<int>(0, (sum, room) => sum + room.unreadCount);

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            color: context.colors.accent.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.mark_email_unread_outlined, color: context.colors.accent),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.chaRequestSectionTitle(widget.rooms.length),
                    style: context.textStyles.titleMedium,
                  ),
                ),
                UnreadCountBadge(count: unreadTotal),
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: context.colors.secondaryText),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final room in widget.rooms) RoomTileLoader(room: room, myAccountId: widget.myAccountId),
        const Divider(height: 1),
      ],
    );
  }
}
