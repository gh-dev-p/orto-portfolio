import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/view_models/account_providers.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import 'group_failure_message.dart';

// ============================================================
// 部品
// ============================================================

/// 定員の入力が正しければその数、正しくなければnull（2〜100の整数。機能仕様書4.7.8.10）
int? parseCapacity(String text) {
  final value = int.tryParse(text.trim());
  if (value == null || value < groupMinCapacity || value > groupMaxMembers) return null;
  return value;
}

/// GRP-03の定員の行（主催チームだけ。機能仕様書4.7.8.10 / 画面設計書5.10.3）。押すと定員のダイアログ
class CapacityTile extends ConsumerWidget {
  const CapacityTile({super.key, required this.room, required this.myAccountId, required this.memberCount});

  final GroupRoom room;
  final String myAccountId;

  /// 今のメンバーの数（定員より少なくするときの注意に使う）
  final int memberCount;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(isReadOnlyProvider(myAccountId))) {
      showAppSnackBar(context, l10n.planReadOnlyNotice);
      return;
    }
    final picked = await showDialog<({int? capacity})>(
      context: context,
      builder: (_) => _CapacityDialog(initial: room.capacity, memberCount: memberCount),
    );
    if (picked == null || picked.capacity == room.capacity || !context.mounted) return;
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .updateCapacity(accountId: myAccountId, chatRoomId: room.chatRoomId, capacity: picked.capacity),
          );
    } on GroupException catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(context, groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final capacity = room.capacity;
    return ListTile(
      key: const Key('group-capacity'),
      leading: const Icon(Icons.event_seat_outlined),
      title: Text(l10n.capTitle),
      trailing: Text(
        capacity == null ? l10n.capNone : l10n.capValue(capacity),
        style: context.textStyles.captionRegular,
      ),
      onTap: () => _edit(context, ref),
    );
  }
}

/// 定員のダイアログ。保存で`(capacity: 数)`、［定員なし］で`(capacity: null)`、キャンセルでnullを返す
class _CapacityDialog extends StatefulWidget {
  const _CapacityDialog({required this.initial, required this.memberCount});

  final int? initial;
  final int memberCount;

  @override
  State<_CapacityDialog> createState() => _CapacityDialogState();
}

class _CapacityDialogState extends State<_CapacityDialog> {
  late final _controller = TextEditingController(text: widget.initial?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final value = parseCapacity(_controller.text);
    final invalid = _controller.text.trim().isNotEmpty && value == null;
    return AlertDialog(
      title: Text(l10n.capTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.capDescription, style: context.textStyles.captionRegular),
          const SizedBox(height: 12),
          TextField(
            key: const Key('capacity-field'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: InputDecoration(
              hintText: '$groupMinCapacity-$groupMaxMembers',
              errorText: invalid ? l10n.capErrorRange : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (value != null && value < widget.memberCount) ...[
            const SizedBox(height: 8),
            Text(l10n.capBelowMembers(widget.memberCount), style: context.textStyles.captionRegular),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('capacity-clear'),
          onPressed: () => Navigator.of(context).pop((capacity: null)),
          child: Text(l10n.capClear),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        TextButton(
          key: const Key('capacity-save'),
          onPressed: value == null ? null : () => Navigator.of(context).pop((capacity: value)),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
