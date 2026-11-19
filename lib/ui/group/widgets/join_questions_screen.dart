import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import 'group_failure_message.dart';

// ============================================================
// 画面
// ============================================================

/// 画面GRP-10：参加時の質問（機能仕様書4.7.8.5 / 画面設計書5.10.10）
/// オフ会グループの主催チームの人が、招待リンクから申請する人への質問を0〜3問決める
class JoinQuestionsScreen extends ConsumerStatefulWidget {
  const JoinQuestionsScreen({
    super.key,
    required this.chatRoomId,
    required this.myAccountId,
    required this.initialQuestions,
  });

  final String chatRoomId;
  final String myAccountId;

  /// 今の質問
  final List<String> initialQuestions;

  @override
  ConsumerState<JoinQuestionsScreen> createState() => _JoinQuestionsScreenState();
}

class _JoinQuestionsScreenState extends ConsumerState<JoinQuestionsScreen> {
  /// 入力欄（少なくとも1つ出す）
  late final List<TextEditingController> _controllers = [
    for (final question in widget.initialQuestions.isEmpty ? const [''] : widget.initialQuestions)
      TextEditingController(text: question),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 保存する質問（前後の空白を除き、空の欄は外す）
  List<String> get _questions =>
      [for (final controller in _controllers) controller.text.trim()].where((text) => text.isNotEmpty).toList();

  bool get _changed {
    final current = _questions;
    final initial = widget.initialQuestions;
    if (current.length != initial.length) return true;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != initial[i]) return true;
    }
    return false;
  }

  void _add() {
    if (_controllers.length >= groupMaxJoinQuestions) return;
    setState(() => _controllers.add(TextEditingController()));
  }

  void _remove(int index) {
    setState(() {
      _controllers.removeAt(index).dispose();
      if (_controllers.isEmpty) _controllers.add(TextEditingController());
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .updateJoinQuestions(
                  accountId: widget.myAccountId,
                  chatRoomId: widget.chatRoomId,
                  questions: _questions,
                ),
          );
      messenger.showSnackBar(buildAppSnackBar(l10n.grpJoinQuestionsSaved));
      navigator.pop();
    } on GroupException catch (error) {
      messenger.showSnackBar(
        buildAppSnackBar(groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed)),
      );
    } catch (_) {
      messenger.showSnackBar(buildAppSnackBar(l10n.grpRequestFailed));
    }
  }

  /// 保存せずに戻るとき、変更があれば確かめる
  Future<void> _onPopInvoked(bool didPop, Object? _) async {
    if (didPop) return;
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final discard = await showConfirmDialog(
      context,
      title: l10n.grpJoinQuestionsDiscardTitle,
      message: '',
      confirmLabel: l10n.grpJoinQuestionsDiscard,
    );
    if (discard) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final changed = _changed;
    return PopScope(
      canPop: !changed,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppScreenAppBar(
          title: l10n.grpJoinQuestionsTitle,
          actions: [
            TextButton(
              key: const Key('join-questions-save'),
              onPressed: changed ? _save : null,
              child: Text(l10n.commonSave),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.grpJoinQuestionsDescription, style: context.textStyles.bodyRegular),
              const SizedBox(height: 16),
              for (final (index, controller) in _controllers.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: Key('join-question-$index'),
                          controller: controller,
                          maxLength: groupJoinTextMaxLength,
                          minLines: 1,
                          maxLines: 3,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: l10n.grpJoinQuestionsLabel(index + 1),
                            hintText: index == 0 ? l10n.grpJoinQuestionsExample : null,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.grpJoinQuestionsRemove,
                        icon: Icon(Icons.close, color: context.colors.secondaryText),
                        onPressed: () => _remove(index),
                      ),
                    ],
                  ),
                ),
              if (_controllers.length < groupMaxJoinQuestions)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('join-questions-add'),
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.grpJoinQuestionsAdd),
                  ),
                ),
              const SizedBox(height: 8),
              Text(l10n.grpJoinQuestionsNote, style: context.textStyles.captionRegular),
            ],
          ),
        ),
      ),
    );
  }
}
