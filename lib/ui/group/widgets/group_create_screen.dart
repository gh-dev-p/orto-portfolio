import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models/loading_overlay_provider.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/image_pick.dart';
import '../../chat/widgets/chat_screen.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/field_label.dart';
import '../../core/ui/press_opacity.dart';
import '../view_models/group_create_viewmodel.dart';
import 'group_failure_message.dart';
import 'group_friend_picker_screen.dart';

// ============================================================
// 画面
// ============================================================

/// 画面GRP-02：グループ作成（機能仕様書4.7.1.1 / 画面設計書5.10.2）
class GroupCreateScreen extends ConsumerStatefulWidget {
  const GroupCreateScreen({
    super.key,
    required this.myAccountId,
    required this.selected,
    this.kind = GroupKind.standard,
  });

  final String myAccountId;

  /// 作成するグループの種類（GRP-06で選んだもの）
  final GroupKind kind;

  /// GRP-01で選んだ友だち
  final List<GroupCandidate> selected;

  @override
  ConsumerState<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  GroupCreateViewModel get _viewModel => ref.read(groupCreateViewModelProvider.notifier);

  /// 画像を選ぶ
  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    final picked = await pickImageForUpload(context, source, maxWidth: 1080, imageQuality: 85);
    if (picked != null) _viewModel.selectImage(File(picked.path));
  }

  /// グループを作成してトークを開く（ホームより上の画面は閉じる）。失敗したら入力を残してSnackBarで知らせる
  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    try {
      final chatRoomId = await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => _viewModel.create(
              accountId: widget.myAccountId,
              kind: widget.kind,
              friendAccountIds: [for (final candidate in widget.selected) candidate.accountId],
            ),
          );
      navigator.popUntil((route) => route.isFirst);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatRoomId: chatRoomId, myAccountId: widget.myAccountId, peerAccountId: null),
        ),
      );
    } on GroupException catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, groupFailureMessage(l10n, error.failure, fallback: l10n.grpCreateFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(groupCreateViewModelProvider);
    final image = state.image;

    return Scaffold(
      appBar: AppScreenAppBar(
        title: l10n.addMenuCreateGroup,
        actions: [TextButton(onPressed: state.canCreate ? _create : null, child: Text(l10n.grpCreateAction))],
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: PressOpacity(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: context.colors.accent.withValues(alpha: 0.1),
                  backgroundImage: image == null ? null : FileImage(image),
                  child: image == null ? Icon(Icons.add_a_photo_outlined, color: context.colors.accent) : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(l10n.grpNameLabel),
            TextField(
              maxLength: groupNameMaxLength,
              decoration: InputDecoration(hintText: l10n.grpNameHint),
              onChanged: _viewModel.updateName,
            ),
            const SizedBox(height: 8),
            Text(l10n.grpPolicyLabel, style: context.textStyles.titleMedium),
            RadioGroup<GroupJoinPolicy>(
              groupValue: state.joinPolicy,
              onChanged: (value) {
                if (value != null) _viewModel.selectJoinPolicy(value);
              },
              child: Column(
                children: [
                  RadioListTile<GroupJoinPolicy>(
                    value: GroupJoinPolicy.approval,
                    title: Text(l10n.grpPolicyApproval),
                    subtitle: Text(l10n.grpPolicyApprovalDescription),
                  ),
                  RadioListTile<GroupJoinPolicy>(
                    value: GroupJoinPolicy.auto,
                    title: Text(l10n.grpPolicyAuto),
                    subtitle: Text(l10n.grpPolicyAutoDescription),
                  ),
                ],
              ),
            ),
            Text(l10n.grpPolicyFixedNote, style: context.textStyles.captionRegular),
            if (widget.selected.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final candidate in widget.selected)
                    AppAvatar(displayName: candidate.name, photoURL: candidate.photoURL, size: 40),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
