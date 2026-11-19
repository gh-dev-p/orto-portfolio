import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/ui/press_opacity.dart';
import '../../../l10n/app_localizations.dart';

/// PRO-01の「友だち追加」ボタン（画面設計書5.7.1）
/// 相手が友だちでないときだけ出す。グループのメンバーの画面から開いたときは、同じ見た目で「友だち申請」「承認する」にも使う（[label]）
class AddFriendButton extends StatelessWidget {
  const AddFriendButton({super.key, required this.onTap, this.label});

  final VoidCallback onTap;

  /// ボタンの文言。nullなら「友だち追加」
  final String? label;

  @override
  Widget build(BuildContext context) {
    return PressOpacity(
      onTap: onTap,
      child: Container(
        height: 44,
        constraints: const BoxConstraints(minWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(color: context.colors.accent, borderRadius: BorderRadius.circular(22)),
        // Containerにalignmentを指定すると親の幅いっぱいに広がるため、Center（widthFactor: 1）で
        // 文字の幅に合わせたまま中央に置く。
        child: Center(
          widthFactor: 1,
          child: Text(
            label ?? AppLocalizations.of(context)!.addMenuAddFriend,
            style: TextStyle(color: context.colors.onAccent, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// PRO-01の「申請中」の表示（画面設計書5.7.1）
/// 友だち申請を送った後に「友だち申請」ボタンの位置に出す。押せない。相手が断っても変わらない
class FriendRequestPendingChip extends StatelessWidget {
  const FriendRequestPendingChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('friend-profile-request-pending'),
      height: 44,
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          AppLocalizations.of(context)!.frqPending,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
