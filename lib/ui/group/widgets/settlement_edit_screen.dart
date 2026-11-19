import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/settlement.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../view_models/group_providers.dart';
import 'group_message_row.dart';
import 'settlement_screen.dart';

// ============================================================
// 処理
// ============================================================

/// 区分のID（端末で作る。英数字8文字）
String newSettlementTierId([Random? random]) {
  final rand = random ?? Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
}

/// 合計の金額の入力が正しければその額、正しくなければnull（1円〜1,000万円）
int? parseSettlementTotal(String text) {
  final value = int.tryParse(text.trim());
  if (value == null || value < 1 || value > settlementMaxTotal) return null;
  return value;
}

/// 保存すると払った記録が未払いに戻る人の数（額が変わり、未払いでない人。Cloud Functionsの`resetCount`と同じ）
int settlementResetCount(List<SettlementShare> current, Map<String, int> nextAmounts) {
  return current.where((share) {
    final next = nextAmounts[share.accountId];
    return next != null && next != share.amount && share.status != PaymentStatus.unpaid;
  }).length;
}

// ============================================================
// 画面
// ============================================================

/// 画面GRP-13：精算の設定（機能仕様書4.7.8.12 / 画面設計書5.10.14）。主催チームだけ
/// 合計・端数の単位・区分（割合）と、精算の対象の人とその区分を決め、一人ひとりの額を見ながら保存する。
/// 初めて開いたときは、出欠で「参加」と答えた人が対象に入っている
class SettlementEditScreen extends ConsumerStatefulWidget {
  const SettlementEditScreen({super.key, required this.chatRoomId, required this.myAccountId});

  final String chatRoomId;
  final String myAccountId;

  @override
  ConsumerState<SettlementEditScreen> createState() => _SettlementEditScreenState();
}

class _SettlementEditScreenState extends ConsumerState<SettlementEditScreen> {
  final _total = TextEditingController();
  var _initialized = false;
  var _roundingUnit = settlementDefaultRoundingUnit;
  var _tiers = <SettlementTier>[];

  /// 対象の人とその区分（並びは候補の並び）
  final _targets = <String, String>{};

  @override
  void dispose() {
    _total.dispose();
    super.dispose();
  }

  /// 今の設定（無ければ出欠の「参加」）から、入力の初期値を作る
  void _initialize(GroupRoom room, List<SettlementShare> shares, List<String> attending) {
    final l10n = AppLocalizations.of(context)!;
    final settlement = room.settlement;
    if (settlement == null) {
      final tier = SettlementTier(tierId: newSettlementTierId(), name: l10n.stlTierDefaultName, percent: 100);
      _tiers = [tier];
      for (final id in attending) {
        if (room.participantIds.contains(id)) _targets[id] = tier.tierId;
      }
    } else {
      _total.text = '${settlement.totalAmount}';
      _roundingUnit = settlement.roundingUnit;
      _tiers = [...settlement.tiers];
      for (final share in shares) {
        _targets[share.accountId] = settlement.tierOf(share.tierId) == null ? _tiers.first.tierId : share.tierId;
      }
    }
    _initialized = true;
  }

  Map<String, int> _amounts(int total) {
    final percentOf = {for (final tier in _tiers) tier.tierId: tier.percent};
    return computeSettlementAmounts(total, _roundingUnit, [
      for (final entry in _targets.entries) (accountId: entry.key, percent: percentOf[entry.value] ?? 0),
    ]);
  }

  Future<void> _editTier([SettlementTier? tier]) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<SettlementTier>(
      context: context,
      builder: (_) => _TierDialog(
        initial: tier ?? SettlementTier(tierId: newSettlementTierId(), name: '', percent: 100),
        isNew: tier == null,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final index = _tiers.indexWhere((item) => item.tierId == result.tierId);
      if (index < 0) {
        _tiers = [..._tiers, result];
      } else {
        _tiers = [..._tiers]..[index] = result;
      }
    });
    if (tier == null && mounted) showAppSnackBar(context, l10n.stlTierAdded);
  }

  void _deleteTier(SettlementTier tier) {
    setState(() {
      _tiers = _tiers.where((item) => item.tierId != tier.tierId).toList();
      // その区分だった人は、最初の区分に移す
      for (final entry in _targets.entries.toList()) {
        if (entry.value == tier.tierId) _targets[entry.key] = _tiers.first.tierId;
      }
    });
  }

  Future<void> _save(GroupRoom room, List<SettlementShare> current) async {
    final l10n = AppLocalizations.of(context)!;
    final total = parseSettlementTotal(_total.text);
    if (total == null || _targets.isEmpty) return;
    final amounts = _amounts(total);
    final resetCount = settlementResetCount(current, amounts);
    if (resetCount > 0) {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.stlResetConfirm(resetCount),
        message: l10n.stlResetConfirmMessage,
        confirmLabel: l10n.commonSave,
      );
      if (!confirmed || !mounted) return;
    }
    final ok = await runSettlementAction(
      context,
      ref,
      widget.myAccountId,
      () => ref
          .read(groupRepositoryProvider)
          .saveSettlement(
            accountId: widget.myAccountId,
            chatRoomId: widget.chatRoomId,
            totalAmount: total,
            roundingUnit: _roundingUnit,
            tiers: _tiers,
            shares: [for (final entry in _targets.entries) (accountId: entry.key, tierId: entry.value)],
          ),
    );
    if (!ok || !mounted) return;
    showAppSnackBar(context, room.settlement == null ? l10n.stlStarted : l10n.stlSaved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final room = ref.watch(groupRoomProvider(widget.chatRoomId)).value;
    final sharesValue = ref.watch(settlementSharesProvider(widget.chatRoomId));
    final attendance = ref.watch(groupAttendanceProvider(widget.chatRoomId));
    final shares = sharesValue.value ?? const <SettlementShare>[];
    final ready = room != null && (room.settlement == null ? attendance.hasValue : sharesValue.hasValue);
    if (ready && !_initialized) {
      _initialize(room, shares, [
        for (final answer in attendance.value ?? const <GroupAttendance>[])
          if (answer.response == AttendanceResponse.yes) answer.accountId,
      ]);
    }
    final total = parseSettlementTotal(_total.text);
    final canSave = _initialized && total != null && _targets.isNotEmpty && _tiers.isNotEmpty;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(
        title: l10n.stlEditTitle,
        actions: [
          TextButton(
            key: const Key('settlement-save'),
            onPressed: canSave ? () => _save(room!, shares) : null,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
      body: SafeArea(child: !_initialized ? const AppLoadingIndicator() : _body(room!, total)),
    );
  }

  Widget _body(GroupRoom room, int? total) {
    final l10n = AppLocalizations.of(context)!;
    final amounts = total == null ? const <String, int>{} : _amounts(total);
    final collected = amounts.values.fold(0, (acc, amount) => acc + amount);
    // 候補：今のメンバーと、対象に残っている抜けた人
    final candidates = [...room.participantIds, ..._targets.keys.where((id) => !room.participantIds.contains(id))]
      ..sort((a, b) => a == widget.myAccountId ? -1 : (b == widget.myAccountId ? 1 : 0));
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: context.textStyles.sectionHeader),
    );
    final showTotalError = _total.text.trim().isNotEmpty && total == null;
    return ListView(
      key: const Key('settlement-edit-screen'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        heading(l10n.stlTotalLabel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const Key('settlement-total-field'),
            controller: _total,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
            decoration: InputDecoration(
              hintText: l10n.stlTotalHint,
              suffixText: l10n.stlYenSuffix,
              errorText: showTotalError ? l10n.stlErrorTotal : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        heading(l10n.stlRoundingTitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            key: const Key('settlement-rounding'),
            segments: [
              for (final unit in settlementRoundingUnits)
                ButtonSegment(value: unit, label: Text(l10n.stlRoundingOption(unit))),
            ],
            selected: {_roundingUnit},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => _roundingUnit = value.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(l10n.stlRoundingNote, style: context.textStyles.captionRegular),
        ),
        heading(l10n.stlTiersHeading),
        for (final tier in _tiers)
          ListTile(
            key: Key('settlement-tier-${tier.tierId}'),
            title: Text(tier.name, style: context.textStyles.bodyRegular),
            subtitle: Text(l10n.stlPercent(tier.percent), style: context.textStyles.captionRegular),
            trailing: _tiers.length > 1
                ? IconButton(
                    key: Key('settlement-tier-delete-${tier.tierId}'),
                    icon: Icon(Icons.close, color: context.colors.secondaryText),
                    tooltip: l10n.stlTierDelete,
                    onPressed: () => _deleteTier(tier),
                  )
                : null,
            onTap: () => _editTier(tier),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.stlTiersNote, style: context.textStyles.captionRegular),
        ),
        if (_tiers.length < settlementMaxTiers)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              key: const Key('settlement-tier-add'),
              onPressed: () => _editTier(),
              icon: const Icon(Icons.add),
              label: Text(l10n.stlTierAdd),
            ),
          ),
        heading(l10n.stlTargetsHeading(_targets.length)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            [
              l10n.stlTargetsNote,
              if (total != null && _targets.isNotEmpty)
                collected > total
                    ? l10n.stlCollectedSurplus(
                        formatYen(context, l10n, collected),
                        formatYen(context, l10n, collected - total),
                      )
                    : l10n.stlCollected(formatYen(context, l10n, collected)),
            ].join('\n'),
            key: const Key('settlement-edit-collected'),
            style: context.textStyles.captionRegular,
          ),
        ),
        for (final accountId in candidates)
          _TargetRow(
            accountId: accountId,
            tiers: _tiers,
            tierId: _targets[accountId],
            amount: amounts[accountId],
            hasLeft: !room.participantIds.contains(accountId),
            onChanged: (tierId) => setState(() {
              if (tierId == null) {
                _targets.remove(accountId);
              } else {
                _targets[accountId] = tierId;
              }
            }),
          ),
      ],
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// 対象の候補の1人。チェックで対象に入れ・外し、区分を選ぶ。[tierId]がnullなら対象でない
class _TargetRow extends ConsumerWidget {
  const _TargetRow({
    required this.accountId,
    required this.tiers,
    required this.tierId,
    required this.amount,
    required this.hasLeft,
    required this.onChanged,
  });

  final String accountId;
  final List<SettlementTier> tiers;
  final String? tierId;
  final int? amount;
  final bool hasLeft;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final name = groupMemberName(ref, l10n, accountId);
    final selected = tierId != null;
    return CheckboxListTile(
      key: Key('settlement-target-$accountId'),
      value: selected,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        hasLeft ? '$name（${l10n.stlLeft}）' : name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyles.bodyRegular,
      ),
      subtitle: selected && amount != null ? Text(formatYen(context, l10n, amount!)) : null,
      secondary: selected
          ? DropdownButton<String>(
              key: Key('settlement-target-tier-$accountId'),
              value: tierId,
              underline: const SizedBox.shrink(),
              items: [for (final tier in tiers) DropdownMenuItem(value: tier.tierId, child: Text(tier.name))],
              onChanged: onChanged,
            )
          : null,
      // 抜けた人は、外すことだけできる（もう一度入れられない）
      onChanged: hasLeft && !selected ? null : (value) => onChanged(value == true ? tiers.first.tierId : null),
    );
  }
}

/// 区分の名前と割合を入れるダイアログ
class _TierDialog extends StatefulWidget {
  const _TierDialog({required this.initial, required this.isNew});

  final SettlementTier initial;
  final bool isNew;

  @override
  State<_TierDialog> createState() => _TierDialogState();
}

class _TierDialogState extends State<_TierDialog> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _percent = TextEditingController(text: '${widget.initial.percent}');

  @override
  void dispose() {
    _name.dispose();
    _percent.dispose();
    super.dispose();
  }

  SettlementTier? get _result {
    final name = _name.text.trim();
    final percent = int.tryParse(_percent.text.trim());
    if (name.isEmpty || name.characters.length > settlementTierNameMaxLength) return null;
    if (percent == null || percent < 0 || percent > settlementMaxPercent) return null;
    return widget.initial.copyWith(name: name, percent: percent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = _result;
    return AlertDialog(
      title: Text(widget.isNew ? l10n.stlTierAdd : l10n.stlTierEditTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('settlement-tier-name'),
            controller: _name,
            autofocus: true,
            maxLength: settlementTierNameMaxLength,
            decoration: InputDecoration(hintText: l10n.stlTierNameHint),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            key: const Key('settlement-tier-percent'),
            controller: _percent,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: InputDecoration(hintText: l10n.stlTierPercentHint, suffixText: '%'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(l10n.stlTierPercentNote, style: context.textStyles.captionRegular),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        TextButton(
          key: const Key('settlement-tier-save'),
          onPressed: result == null ? null : () => Navigator.of(context).pop(result),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
