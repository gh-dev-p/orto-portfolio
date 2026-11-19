import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/announcement.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import 'group_failure_message.dart';

// ============================================================
// 画面
// ============================================================

/// 画面GRP-07：お知らせの編集（機能仕様書4.7.8.4 / 画面設計書5.10.7）
/// [announcement]があれば直し、無ければ新しく出す。[initialText]はメッセージから「お知らせにする」ときの本文
class AnnouncementEditScreen extends ConsumerStatefulWidget {
  const AnnouncementEditScreen({
    super.key,
    required this.chatRoomId,
    required this.myAccountId,
    this.announcement,
    this.initialText,
  });

  final String chatRoomId;
  final String myAccountId;
  final Announcement? announcement;
  final String? initialText;

  @override
  ConsumerState<AnnouncementEditScreen> createState() => _AnnouncementEditScreenState();
}

class _AnnouncementEditScreenState extends ConsumerState<AnnouncementEditScreen> {
  late final _textController = TextEditingController(
    text: widget.announcement?.text ?? _clip(widget.initialText ?? '', announcementMaxTextLength),
  );
  late final _placeController = TextEditingController(text: widget.announcement?.place ?? '');

  /// 新しく出すときは既定で通知する、直すときはしない（機能仕様書4.7.8.4）
  late bool _notify = widget.announcement == null;

  bool get _isEdit => widget.announcement != null;

  /// メッセージ（最大2000文字）から作るとき、本文の上限に収める
  static String _clip(String text, int max) {
    final chars = text.characters;
    return chars.length <= max ? text : chars.take(max).toString();
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final repository = ref.read(groupRepositoryProvider);
    final text = _textController.text.trim();
    final place = _placeController.text.trim();
    final existing = widget.announcement;
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => existing == null
                ? repository.postAnnouncement(
                    accountId: widget.myAccountId,
                    chatRoomId: widget.chatRoomId,
                    text: text,
                    place: place,
                    notify: _notify,
                  )
                : repository.updateAnnouncement(
                    accountId: widget.myAccountId,
                    chatRoomId: widget.chatRoomId,
                    announcementId: existing.announcementId,
                    text: text,
                    place: place,
                    notify: _notify,
                  ),
          );
      navigator.pop(true);
    } on GroupException catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed));
      // 消えたお知らせは直せないので閉じる
      if (error.failure == GroupFailure.announcementNotFound) navigator.pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canSave = _textController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppScreenAppBar(
        title: _isEdit ? l10n.annEditTitle : l10n.annAdd,
        actions: [
          TextButton(
            key: const Key('announcement-save'),
            onPressed: canSave ? _save : null,
            child: Text(_isEdit ? l10n.commonSave : l10n.annPost),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('announcement-text'),
              controller: _textController,
              autofocus: !_isEdit && widget.initialText == null,
              minLines: 4,
              maxLines: 10,
              maxLength: announcementMaxTextLength,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(hintText: l10n.annTextHint),
            ),
            const SizedBox(height: 8),
            MeetupPlaceField(controller: _placeController),
            const SizedBox(height: 8),
            NotifyMembersSwitch(value: _notify, onChanged: (value) => setState(() => _notify = value)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 部品（GRP-07・GRP-08で使う）
// ============================================================

/// 場所の入力欄（店名か住所、任意）と注意書き
class MeetupPlaceField extends StatelessWidget {
  const MeetupPlaceField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('meetup-place'),
          controller: controller,
          maxLength: announcementMaxPlaceLength,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: l10n.annPlaceHint, prefixIcon: const Icon(Icons.place_outlined)),
        ),
        Text(l10n.annPlaceNote, style: context.textStyles.captionRegular),
      ],
    );
  }
}

/// 「メンバーに通知する」のスイッチ
class NotifyMembersSwitch extends StatelessWidget {
  const NotifyMembersSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      key: const Key('notify-members'),
      contentPadding: EdgeInsets.zero,
      title: Text(AppLocalizations.of(context)!.annNotifyMembers, style: context.textStyles.bodyRegular),
      value: value,
      onChanged: onChanged,
    );
  }
}
