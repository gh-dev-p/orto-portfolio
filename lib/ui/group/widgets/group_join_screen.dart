import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/view_models/account_providers.dart';
import '../../chat/widgets/chat_screen.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_primary_button.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../view_models/group_invite_providers.dart';
import 'group_failure_message.dart';

// ============================================================
// 画面
// ============================================================

/// 画面GRP-05：参加確認（機能仕様書4.7.2.5 / 画面設計書5.10.5）
/// グループの内容と参加するアカウントを見せる。メンバーの一覧は見せない。
/// オフ会グループは、質問に答えて参加を申請し、申請の状態を出す（機能仕様書4.7.8.5）
class GroupJoinScreen extends ConsumerStatefulWidget {
  const GroupJoinScreen({super.key, required this.token, required this.myAccountId});

  final String token;
  final String myAccountId;

  @override
  ConsumerState<GroupJoinScreen> createState() => _GroupJoinScreenState();
}

class _GroupJoinScreenState extends ConsumerState<GroupJoinScreen> {
  /// 参加の失敗の文言（出ていれば「閉じる」だけを出す）
  String? _error;

  /// オフ会グループの申請の状態（最初はプレビューの値。申請・取り消しで変える）
  JoinStatus? _status;

  /// [_status]をプレビューの値で初期化したか
  bool _statusLoaded = false;

  /// 断られた後に「もう一度申請する」を選んだか（答えの欄を出す）
  bool _reapplying = false;

  /// 答えの入力欄（質問の数だけ）
  List<TextEditingController> _answers = const [];

  @override
  void dispose() {
    for (final controller in _answers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadStatus(GroupInvitePreview preview) {
    if (_statusLoaded) return;
    _statusLoaded = true;
    _status = preview.applicationStatus;
    _answers = [for (final _ in preview.joinQuestions) TextEditingController()];
  }

  bool get _answersFilled => _answers.every((controller) => controller.text.trim().isNotEmpty);

  /// 質問に答えて参加を申請する（オフ会グループ）
  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final status = await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .applyToJoin(
                  accountId: widget.myAccountId,
                  token: widget.token,
                  answers: [for (final controller in _answers) controller.text.trim()],
                ),
          );
      if (!mounted) return;
      setState(() {
        _status = status;
        _reapplying = false;
      });
    } on GroupException catch (error) {
      if (!mounted) return;
      setState(() => _error = groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed));
    }
  }

  /// 承認待ち・キャンセル待ちの申請を取り消す
  Future<void> _cancel(String chatRoomId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.grpApplyCancelConfirmTitle,
      message: l10n.grpApplyCancelConfirmMessage,
      confirmLabel: l10n.grpApplyCancelConfirm,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .cancelApplication(accountId: widget.myAccountId, chatRoomId: chatRoomId),
          );
      if (mounted) Navigator.of(context).pop();
    } on GroupException catch (error) {
      if (!mounted) return;
      setState(() => _error = groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed));
    }
  }

  /// 結果（断られた・閉じた）を見終えて閉じる。CHA-01の「参加の申請」からも消す（失敗しても閉じる）
  void _dismissResult(String chatRoomId) {
    ref
        .read(groupRepositoryProvider)
        .cancelApplication(accountId: widget.myAccountId, chatRoomId: chatRoomId)
        .catchError((Object _) {});
    Navigator.of(context).pop();
  }

  /// トークを開いてこの画面を閉じる
  void _openChat(String chatRoomId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatRoomId: chatRoomId, myAccountId: widget.myAccountId, peerAccountId: null),
      ),
    );
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final chatRoomId = await ref
          .read(loadingOverlayProvider.notifier)
          .run(() => ref.read(groupRepositoryProvider).joinByLink(accountId: widget.myAccountId, token: widget.token));
      if (mounted) _openChat(chatRoomId);
    } on GroupException catch (error) {
      if (!mounted) return;
      setState(() => _error = groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed));
    }
  }

  Widget _errorView(String message) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, textAlign: TextAlign.center, style: context.textStyles.titleMedium),
        const SizedBox(height: 24),
        AppPrimaryButton(label: l10n.commonClose, enabled: true, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }

  /// オフ会グループの、質問と答えの欄（機能仕様書4.7.8.5）
  List<Widget> _applyForm(GroupInvitePreview preview) {
    final l10n = AppLocalizations.of(context)!;
    return [
      for (final (index, question) in preview.joinQuestions.indexed) ...[
        Text(question, style: context.textStyles.bodyRegular),
        TextField(
          key: Key('join-answer-$index'),
          controller: _answers[index],
          maxLength: groupJoinTextMaxLength,
          minLines: 1,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: l10n.grpApplyAnswerHint),
        ),
        const SizedBox(height: 8),
      ],
      Text(l10n.grpApplyNote, textAlign: TextAlign.center, style: context.textStyles.captionRegular),
      const SizedBox(height: 16),
      AppPrimaryButton(key: const Key('join-apply'), label: l10n.grpApplyJoin, enabled: _answersFilled, onTap: _apply),
      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonClose)),
    ];
  }

  /// オフ会グループの、申請の状態の表示
  List<Widget> _statusView(GroupInvitePreview preview, JoinStatus status) {
    final l10n = AppLocalizations.of(context)!;
    final message = switch (status) {
      JoinStatus.waitlisted => l10n.grpApplyWaitlisted,
      JoinStatus.declined => l10n.grpApplyDeclined(preview.name),
      JoinStatus.closed => l10n.grpApplyClosed(preview.name),
      JoinStatus.pending || JoinStatus.approved => l10n.grpApplyPending,
    };
    return [
      Text(message, key: const Key('join-status'), textAlign: TextAlign.center, style: context.textStyles.bodyRegular),
      const SizedBox(height: 24),
      if (status.isOpen) ...[
        AppPrimaryButton(label: l10n.commonClose, enabled: true, onTap: () => Navigator.of(context).pop()),
        TextButton(
          onPressed: () => _cancel(preview.chatRoomId),
          child: Text(l10n.grpApplyCancel, style: TextStyle(color: context.colors.secondaryText)),
        ),
      ] else ...[
        if (status == JoinStatus.declined)
          AppPrimaryButton(label: l10n.grpApplyAgain, enabled: true, onTap: () => setState(() => _reapplying = true)),
        TextButton(onPressed: () => _dismissResult(preview.chatRoomId), child: Text(l10n.commonClose)),
      ],
    ];
  }

  Widget _previewView(GroupInvitePreview preview) {
    final l10n = AppLocalizations.of(context)!;
    // 参加するアカウント（QRの読み取りは使用中のアカウントで固定、外部の招待はシートで選んだアカウント）
    final account = ref.watch(
      accountsProvider.select((async) => async.value?.where((own) => own.id == widget.myAccountId).firstOrNull),
    );
    _loadStatus(preview);
    if (preview.isMember) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openChat(preview.chatRoomId);
      });
      return const AppLoadingIndicator();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: AppAvatar(displayName: preview.name, photoURL: preview.photoURL, size: 88),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.grpTitleWithCount(preview.name, preview.memberCount),
          textAlign: TextAlign.center,
          style: context.textStyles.titleMedium,
        ),
        // 定員と満員の注意（機能仕様書4.7.8.10）。満員の注意は、まだ申請していないときだけ
        if (preview.capacity case final capacity?) ...[
          const SizedBox(height: 4),
          Text(l10n.capPreview(capacity), textAlign: TextAlign.center, style: context.textStyles.captionRegular),
        ],
        if (preview.isMeetup && preview.isFull && _status == null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.capPreviewFull,
            key: const Key('group-join-full'),
            textAlign: TextAlign.center,
            style: context.textStyles.bodyRegular,
          ),
        ],
        const SizedBox(height: 24),
        if (account != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppAvatar(displayName: account.displayName, photoURL: account.photoURL, size: 24),
              const SizedBox(width: 8),
              Flexible(child: Text(l10n.grpJoinAccount(account.displayName), style: context.textStyles.bodyRegular)),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (!preview.isMeetup) ...[
          AppPrimaryButton(label: l10n.grpRequestJoin, enabled: true, onTap: _join),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonClose)),
        ] else if (_status case final status? when !(_reapplying && status == JoinStatus.declined))
          ..._statusView(preview, status)
        else
          ..._applyForm(preview),
      ],
    );
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context)!;
    final error = _error;
    if (error != null) return _errorView(error);
    return ref
        .watch(groupInvitePreviewProvider((widget.myAccountId, widget.token)))
        .when(
          data: _previewView,
          loading: () => const AppLoadingIndicator(),
          error: (failure, _) => _errorView(
            failure is GroupException
                ? groupFailureMessage(l10n, failure.failure, fallback: l10n.grpRequestFailed)
                : l10n.grpRequestFailed,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.grpJoinTitle),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: _body()),
        ),
      ),
    );
  }
}
