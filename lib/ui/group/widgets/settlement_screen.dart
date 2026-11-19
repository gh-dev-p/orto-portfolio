import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/settlement.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/external_link.dart';
import '../../account/view_models/account_providers.dart';
import '../../chat_list/view_models/chat_list_viewmodel.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../view_models/group_providers.dart';
import 'group_failure_message.dart';
import 'group_message_row.dart';
import 'group_system_text.dart';
import 'settlement_edit_screen.dart';

// ============================================================
// 文言の部品
// ============================================================

/// 金額の表示（「3,400円」「¥3,400」）
String formatYen(BuildContext context, AppLocalizations l10n, int amount) {
  final localeName = Localizations.localeOf(context).toString();
  return l10n.stlYen(NumberFormat.decimalPattern(localeName).format(amount));
}

/// 払った記録の状態の文言（払う額が無い人は「支払いなし」）
String paymentStatusLabel(AppLocalizations l10n, SettlementShare share) {
  if (share.isFree) return l10n.stlStatusFree;
  return switch (share.status) {
    PaymentStatus.unpaid => l10n.stlStatusUnpaid,
    PaymentStatus.reported => l10n.stlStatusReported,
    PaymentStatus.confirmed => l10n.stlStatusConfirmed,
  };
}

String paymentMethodLabel(AppLocalizations l10n, PaymentMethod method) => switch (method) {
  PaymentMethod.link => l10n.stlMethodLink,
  PaymentMethod.cash => l10n.stlMethodCash,
  PaymentMethod.other => l10n.stlMethodOther,
};

/// 精算の操作を、読み取り専用の確かめ・ローディング・失敗の文言とまとめて行う。成功したらtrue
Future<bool> runSettlementAction(
  BuildContext context,
  WidgetRef ref,
  String myAccountId,
  Future<void> Function() action,
) async {
  final l10n = AppLocalizations.of(context)!;
  if (ref.read(isReadOnlyProvider(myAccountId))) {
    showAppSnackBar(context, l10n.planReadOnlyNotice);
    return false;
  }
  try {
    await ref.read(loadingOverlayProvider.notifier).run(action);
    return true;
  } on GroupException catch (error) {
    if (context.mounted) {
      showAppSnackBar(context, groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed));
    }
    return false;
  }
}

// ============================================================
// 画面
// ============================================================

/// 画面GRP-12：精算（機能仕様書4.7.8.12 / 画面設計書5.10.13）
/// 合計と自分の額・払った記録・送金先を出す。主催チームの人は全員の払った記録を確定し、未払いの人に催促し、
/// 送金先を足し、精算の設定（GRP-13）を開く
class SettlementScreen extends ConsumerWidget {
  const SettlementScreen({super.key, required this.chatRoomId, required this.myAccountId});

  final String chatRoomId;
  final String myAccountId;

  void _openEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettlementEditScreen(chatRoomId: chatRoomId, myAccountId: myAccountId),
      ),
    );
  }

  Future<void> _remind(BuildContext context, WidgetRef ref, int count) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.stlRemindConfirm(count),
      message: l10n.attRemindConfirmMessage,
      confirmLabel: l10n.attRemindSend,
    );
    if (!confirmed || !context.mounted) return;
    var sent = 0;
    final ok = await runSettlementAction(context, ref, myAccountId, () async {
      sent = await ref.read(groupRepositoryProvider).remindSettlement(accountId: myAccountId, chatRoomId: chatRoomId);
    });
    if (ok && context.mounted) showAppSnackBar(context, l10n.attReminded(sent));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.stlDeleteConfirm,
      message: l10n.stlDeleteConfirmMessage,
      confirmLabel: l10n.stlDelete,
    );
    if (!confirmed || !context.mounted) return;
    await runSettlementAction(
      context,
      ref,
      myAccountId,
      () => ref.read(groupRepositoryProvider).deleteSettlement(accountId: myAccountId, chatRoomId: chatRoomId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final room = ref.watch(groupRoomProvider(chatRoomId)).value;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.stlTitle),
      body: SafeArea(child: room == null ? const AppLoadingIndicator() : _body(context, ref, room)),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, GroupRoom room) {
    final l10n = AppLocalizations.of(context)!;
    // 閉じたあと（機能仕様書4.7.8.6）は読むだけ
    final closed = room.isClosedAt(DateTime.now());
    final isOrganizer = room.isOrganizer(myAccountId) && !closed;
    final settlement = room.settlement;
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: context.textStyles.sectionHeader),
    );

    if (settlement == null) {
      return ListView(
        key: const Key('settlement-screen'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.stlNotStarted, style: context.textStyles.bodyRegular),
          const SizedBox(height: 8),
          Text(l10n.stlInAppNote, style: context.textStyles.captionRegular),
          if (isOrganizer) ...[
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('settlement-start'),
              onPressed: () => _openEdit(context),
              child: Text(l10n.stlRowStart),
            ),
          ],
        ],
      );
    }

    final myShare = ref.watch(mySettlementShareProvider((myAccountId, chatRoomId))).value;
    // 全員の分を読めるのは主催チームの人だけ（閉じたあとも読むだけで見られる）
    final shares = room.isOrganizer(myAccountId)
        ? ref.watch(settlementSharesProvider(chatRoomId)).value ?? const <SettlementShare>[]
        : const <SettlementShare>[];
    final sections = SettlementSections.of(shares, myAccountId: myAccountId);
    final unpaidMembers = sections.unpaid.where((share) => room.participantIds.contains(share.accountId)).length;

    return ListView(
      key: const Key('settlement-screen'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListTile(
          key: const Key('settlement-total'),
          title: Text(l10n.stlTotalLabel, style: context.textStyles.bodyRegular),
          subtitle: Text(l10n.stlRoundingValue(settlement.roundingUnit), style: context.textStyles.captionRegular),
          trailing: Text(formatYen(context, l10n, settlement.totalAmount), style: context.textStyles.titleMedium),
        ),
        heading(l10n.stlMyShare),
        if (myShare == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.stlNotTarget, style: context.textStyles.bodyRegular),
          )
        else
          _MyShareCard(
            chatRoomId: chatRoomId,
            myAccountId: myAccountId,
            share: myShare,
            tier: settlement.tierOf(myShare.tierId),
            enabled: !closed,
          ),
        heading(l10n.stlLinksHeading),
        _PaymentLinks(
          chatRoomId: chatRoomId,
          myAccountId: myAccountId,
          links: settlement.paymentLinks,
          canEdit: isOrganizer,
        ),
        if (room.isOrganizer(myAccountId)) ...[
          heading(l10n.stlOrganizerHeading),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              [
                sections.collected > settlement.totalAmount
                    ? l10n.stlCollectedSurplus(
                        formatYen(context, l10n, sections.collected),
                        formatYen(context, l10n, sections.collected - settlement.totalAmount),
                      )
                    : l10n.stlCollected(formatYen(context, l10n, sections.collected)),
                l10n.stlConfirmedSum(formatYen(context, l10n, sections.confirmedAmount)),
              ].join('\n'),
              key: const Key('settlement-collected'),
              style: context.textStyles.bodyRegular,
            ),
          ),
          if (isOrganizer) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton.icon(
                key: const Key('settlement-remind'),
                onPressed: unpaidMembers == 0 ? null : () => _remind(context, ref, unpaidMembers),
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(l10n.stlRemind),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(l10n.stlAutoNote, style: context.textStyles.captionRegular),
            ),
          ],
          for (final (label, list) in [
            (l10n.stlSectionReported(sections.reported.length), sections.reported),
            (l10n.stlSectionUnpaid(sections.unpaid.length), sections.unpaid),
            (l10n.stlSectionConfirmed(sections.confirmed.length), sections.confirmed),
            (l10n.stlSectionFree(sections.free.length), sections.free),
          ]) ...[
            heading(label),
            for (final share in list)
              _ShareRow(
                chatRoomId: chatRoomId,
                myAccountId: myAccountId,
                share: share,
                tier: settlement.tierOf(share.tierId),
                hasLeft: !room.participantIds.contains(share.accountId),
                canEdit: isOrganizer,
              ),
          ],
          if (isOrganizer) ...[
            const SizedBox(height: 16),
            ListTile(
              key: const Key('settlement-edit'),
              leading: Icon(Icons.edit_outlined, color: context.colors.primaryText),
              title: Text(l10n.stlEdit, style: context.textStyles.bodyRegular),
              onTap: () => _openEdit(context),
            ),
            ListTile(
              key: const Key('settlement-delete'),
              leading: Icon(Icons.delete_outline, color: context.colors.error),
              title: Text(l10n.stlDelete, style: context.textStyles.bodyRegular.copyWith(color: context.colors.error)),
              onTap: () => _delete(context, ref),
            ),
          ],
        ],
      ],
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// 精算の行（CHA-02のお知らせの枠の中。機能仕様書4.7.8.12）。押すとGRP-12
/// 精算が始まっていれば自分の額と状態（対象でなければ合計）、始まっていなければ主催チームにだけ「精算を始める」を出す
class SettlementRow extends ConsumerWidget {
  const SettlementRow({super.key, required this.chatRoomId, required this.myAccountId, required this.onOpen});

  final String chatRoomId;
  final String myAccountId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final room = ref.watch(groupRoomProvider(chatRoomId)).value;
    if (room == null || !room.isMeetup) return const SizedBox.shrink();
    final settlement = room.settlement;
    final String text;
    if (settlement == null) {
      // 閉じたあとは始められない
      if (!room.isOrganizer(myAccountId) || room.isClosedAt(DateTime.now())) return const SizedBox.shrink();
      text = l10n.stlRowStart;
    } else {
      final myShare = ref.watch(mySettlementShareProvider((myAccountId, chatRoomId))).value;
      text = myShare == null
          ? l10n.stlRowTotal(formatYen(context, l10n, settlement.totalAmount))
          : l10n.stlRowMine(formatYen(context, l10n, myShare.amount), paymentStatusLabel(l10n, myShare));
    }
    return InkWell(
      key: const Key('settlement-row'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
        child: Row(
          children: [
            Icon(Icons.payments_outlined, size: 18, color: context.colors.secondaryText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                key: const Key('settlement-row-text'),
                style: context.textStyles.bodyRegular,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.secondaryText),
          ],
        ),
      ),
    );
  }
}

/// 自分の額・区分・状態と、「払った」のボタン
class _MyShareCard extends ConsumerWidget {
  const _MyShareCard({
    required this.chatRoomId,
    required this.myAccountId,
    required this.share,
    required this.tier,
    required this.enabled,
  });

  final String chatRoomId;
  final String myAccountId;
  final SettlementShare share;
  final SettlementTier? tier;

  /// 押せるか（閉じたオフ会グループでは押せない）
  final bool enabled;

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final method = await showModalBottomSheet<PaymentMethod>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.stlMethodTitle, style: sheetContext.textStyles.sectionHeader),
            ),
            for (final method in PaymentMethod.values)
              ListTile(
                key: Key('settlement-method-${method.value}'),
                title: Text(paymentMethodLabel(l10n, method)),
                onTap: () => Navigator.of(sheetContext).pop(method),
              ),
          ],
        ),
      ),
    );
    if (method == null || !context.mounted) return;
    await runSettlementAction(
      context,
      ref,
      myAccountId,
      () => ref
          .read(groupRepositoryProvider)
          .reportSettlementPayment(accountId: myAccountId, chatRoomId: chatRoomId, paid: true, method: method),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    await runSettlementAction(
      context,
      ref,
      myAccountId,
      () => ref
          .read(groupRepositoryProvider)
          .reportSettlementPayment(accountId: myAccountId, chatRoomId: chatRoomId, paid: false),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final note = switch (share.status) {
      _ when share.isFree => null,
      PaymentStatus.unpaid => null,
      PaymentStatus.reported => l10n.stlReportedNote,
      PaymentStatus.confirmed => l10n.stlConfirmedNote,
    };
    return Padding(
      key: const Key('settlement-my-share'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatYen(context, l10n, share.amount),
                  key: const Key('settlement-my-amount'),
                  style: context.textStyles.titleMedium,
                ),
              ),
              Text(paymentStatusLabel(l10n, share), style: context.textStyles.bodyRegular),
            ],
          ),
          if (tier != null)
            Text(l10n.stlTierLabel(tier!.name, tier!.percent), style: context.textStyles.captionRegular),
          if (note != null) ...[const SizedBox(height: 4), Text(note, style: context.textStyles.captionRegular)],
          if (enabled && !share.isFree && share.status == PaymentStatus.unpaid) ...[
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('settlement-report'),
              onPressed: () => _report(context, ref),
              child: Text(l10n.stlReportPaid),
            ),
          ],
          if (enabled && share.status == PaymentStatus.reported) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('settlement-report-cancel'),
              onPressed: () => _cancel(context, ref),
              child: Text(l10n.stlReportCancel),
            ),
          ],
        ],
      ),
    );
  }
}

/// 送金先の一覧。リンクは押すと外のアプリで開き、PayPay IDはコピーする。主催チームは足す・外す
class _PaymentLinks extends ConsumerWidget {
  const _PaymentLinks({
    required this.chatRoomId,
    required this.myAccountId,
    required this.links,
    required this.canEdit,
  });

  final String chatRoomId;
  final String myAccountId;
  final List<SettlementLink> links;
  final bool canEdit;

  Future<void> _open(BuildContext context, SettlementLink link) async {
    final l10n = AppLocalizations.of(context)!;
    if (link.isUrl) {
      final uri = Uri.tryParse(link.value);
      if (uri != null) await openExternalLink(context, uri);
      return;
    }
    await Clipboard.setData(ClipboardData(text: link.value));
    if (context.mounted) showAppSnackBar(context, l10n.commonCopied);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, SettlementLink link) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.stlLinkRemoveConfirm,
      message: link.value,
      confirmLabel: l10n.stlLinkRemove,
    );
    if (!confirmed || !context.mounted) return;
    await runSettlementAction(
      context,
      ref,
      myAccountId,
      () => ref
          .read(groupRepositoryProvider)
          .removeSettlementLink(accountId: myAccountId, chatRoomId: chatRoomId, linkId: link.linkId),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final picked = await showDialog<_NewLink>(context: context, builder: (_) => const _AddLinkDialog());
    if (picked == null || !context.mounted) return;
    await runSettlementAction(
      context,
      ref,
      myAccountId,
      () => ref
          .read(groupRepositoryProvider)
          .addSettlementLink(
            accountId: myAccountId,
            chatRoomId: chatRoomId,
            service: picked.service,
            kind: picked.kind,
            value: picked.value,
            label: picked.label,
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasPayPay = links.any((link) => link.service == SettlementLinkService.paypay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (links.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.stlLinksEmpty, style: context.textStyles.bodyRegular),
          ),
        for (final link in links)
          ListTile(
            key: Key('settlement-link-${link.linkId}'),
            leading: Icon(link.isUrl ? Icons.open_in_new : Icons.content_copy, color: context.colors.primaryText),
            title: Text(switch ((link.service, link.kind)) {
              (SettlementLinkService.paypay, SettlementLinkKind.paypayId) => l10n.stlLinkPayPayId(link.value),
              (SettlementLinkService.paypay, _) => l10n.stlLinkPayPay,
              _ => link.label ?? '',
            }, style: context.textStyles.bodyRegular),
            subtitle: Text(
              [
                // 開く前にどこへ行くか分かるよう、リンクはホスト名を出す
                if (link.isUrl) Uri.tryParse(link.value)?.host ?? '',
                l10n.stlLinkAddedBy(groupPersonName(l10n, groupMemberName(ref, l10n, link.addedBy))),
              ].join(' · '),
              style: context.textStyles.captionRegular,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: canEdit
                ? IconButton(
                    key: Key('settlement-link-remove-${link.linkId}'),
                    icon: Icon(Icons.close, color: context.colors.secondaryText),
                    tooltip: l10n.stlLinkRemove,
                    onPressed: () => _remove(context, ref, link),
                  )
                : null,
            onTap: () => _open(context, link),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            [if (hasPayPay) l10n.stlPayPayNote, l10n.stlInAppNote].join('\n'),
            style: context.textStyles.captionRegular,
          ),
        ),
        if (canEdit && links.length < settlementMaxLinks)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              key: const Key('settlement-link-add'),
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.stlLinkAdd),
            ),
          ),
      ],
    );
  }
}

typedef _NewLink = ({SettlementLinkService service, SettlementLinkKind kind, String value, String? label});

/// 送金先を足すダイアログ（PayPayのリンク・PayPay ID・ほかのサービスのリンク）
class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

enum _LinkChoice { paypayUrl, paypayId, other }

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _value = TextEditingController();
  final _label = TextEditingController();
  var _choice = _LinkChoice.paypayUrl;

  @override
  void dispose() {
    _value.dispose();
    _label.dispose();
    super.dispose();
  }

  _NewLink? get _result {
    final (service, kind) = switch (_choice) {
      _LinkChoice.paypayUrl => (SettlementLinkService.paypay, SettlementLinkKind.url),
      _LinkChoice.paypayId => (SettlementLinkService.paypay, SettlementLinkKind.paypayId),
      _LinkChoice.other => (SettlementLinkService.other, SettlementLinkKind.url),
    };
    final value = normalizeSettlementLink(service, kind, _value.text);
    if (value == null) return null;
    final label = _label.text.trim();
    if (service == SettlementLinkService.other &&
        (label.isEmpty || label.characters.length > settlementLinkLabelMaxLength)) {
      return null;
    }
    return (service: service, kind: kind, value: value, label: service == SettlementLinkService.other ? label : null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = _result;
    final showError =
        _value.text.trim().isNotEmpty &&
        normalizeSettlementLink(
              _choice == _LinkChoice.other ? SettlementLinkService.other : SettlementLinkService.paypay,
              _choice == _LinkChoice.paypayId ? SettlementLinkKind.paypayId : SettlementLinkKind.url,
              _value.text,
            ) ==
            null;
    return AlertDialog(
      title: Text(l10n.stlLinkAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (choice, label) in [
              (_LinkChoice.paypayUrl, l10n.stlLinkServicePayPayUrl),
              (_LinkChoice.paypayId, l10n.stlLinkServicePayPayId),
              (_LinkChoice.other, l10n.stlLinkServiceOther),
            ])
              ListTile(
                key: Key('settlement-link-choice-${choice.name}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(choice == _choice ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(label),
                onTap: () => setState(() => _choice = choice),
              ),
            if (_choice == _LinkChoice.other)
              TextField(
                key: const Key('settlement-link-label'),
                controller: _label,
                maxLength: settlementLinkLabelMaxLength,
                decoration: InputDecoration(hintText: l10n.stlLinkLabelHint),
                onChanged: (_) => setState(() {}),
              ),
            TextField(
              key: const Key('settlement-link-value'),
              controller: _value,
              keyboardType: _choice == _LinkChoice.paypayId ? TextInputType.text : TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: _choice == _LinkChoice.paypayId ? l10n.stlLinkIdHint : 'https://',
                errorText: showError ? l10n.stlLinkInvalid : null,
                errorMaxLines: 3,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(l10n.stlLinkAddNote, style: context.textStyles.captionRegular),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        TextButton(
          key: const Key('settlement-link-save'),
          onPressed: result == null ? null : () => Navigator.of(context).pop(result),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

/// 主催チームの一覧の1人。押すと確定・未払いに戻すのシート
class _ShareRow extends ConsumerWidget {
  const _ShareRow({
    required this.chatRoomId,
    required this.myAccountId,
    required this.share,
    required this.tier,
    required this.hasLeft,
    required this.canEdit,
  });

  final String chatRoomId;
  final String myAccountId;
  final SettlementShare share;
  final SettlementTier? tier;

  /// グループを抜けた人か
  final bool hasLeft;
  final bool canEdit;

  Future<void> _act(BuildContext context, WidgetRef ref, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showModalBottomSheet<({bool confirmed, PaymentMethod? method})>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.stlShareSheetTitle(groupPersonName(l10n, name), formatYen(context, l10n, share.amount)),
                style: sheetContext.textStyles.sectionHeader,
              ),
            ),
            if (share.status == PaymentStatus.reported)
              ListTile(
                key: const Key('settlement-confirm'),
                leading: const Icon(Icons.check_circle_outline),
                title: Text(l10n.stlConfirm),
                onTap: () => Navigator.of(sheetContext).pop((confirmed: true, method: null)),
              ),
            if (share.status == PaymentStatus.unpaid)
              for (final method in PaymentMethod.values)
                ListTile(
                  key: Key('settlement-confirm-${method.value}'),
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(l10n.stlConfirmWith(paymentMethodLabel(l10n, method))),
                  onTap: () => Navigator.of(sheetContext).pop((confirmed: true, method: method)),
                ),
            if (share.status != PaymentStatus.unpaid)
              ListTile(
                key: const Key('settlement-revert'),
                leading: const Icon(Icons.undo),
                title: Text(l10n.stlRevert),
                onTap: () => Navigator.of(sheetContext).pop((confirmed: false, method: null)),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    await runSettlementAction(
      context,
      ref,
      myAccountId,
      () => ref
          .read(groupRepositoryProvider)
          .confirmSettlementPayment(
            accountId: myAccountId,
            chatRoomId: chatRoomId,
            targetAccountId: share.accountId,
            confirmed: choice.confirmed,
            method: choice.method,
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(chatListPeerProvider(share.accountId)).account.value;
    final name = groupMemberName(ref, l10n, share.accountId);
    final details = [
      if (tier != null) l10n.stlTierLabel(tier!.name, tier!.percent),
      if (share.method != null && share.status != PaymentStatus.unpaid) paymentMethodLabel(l10n, share.method!),
      if (hasLeft) l10n.stlLeft,
    ];
    return ListTile(
      key: Key('settlement-share-${share.accountId}'),
      leading: AppAvatar(displayName: name, photoURL: account?.visiblePhotoURL, size: 36),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodyRegular),
      subtitle: details.isEmpty ? null : Text(details.join(' · '), style: context.textStyles.captionRegular),
      trailing: Text(formatYen(context, l10n, share.amount), style: context.textStyles.bodyRegular),
      onTap: canEdit && !share.isFree ? () => _act(context, ref, name) : null,
    );
  }
}
