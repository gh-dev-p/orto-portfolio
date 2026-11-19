import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../../utils/image_pick.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/text_edit_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../view_models/profile_edit_viewmodel.dart';
import '../../qr/widgets/qr_scan_screen.dart';
import 'allow_id_search_row.dart';
import 'banner_and_avatar.dart';
import 'list_row.dart';
import 'section_card.dart';

// ============================================================
// 画面
// ============================================================

/// 画面PRO-03：プロフィール編集
/// iOSの設定画面風のリスト。画面全体の保存ボタンは無く、各行を編集し終えたときにその項目だけをすぐに保存する
///
/// 機能仕様書：4.5.1 / 画面設計書：5.7.3
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key, required this.accountId});

  /// 編集するアカウント（使用中のアカウント）のID
  final String accountId;

  /// アバターの大きさ
  static const _avatarSize = 78.0;

  // ---- 操作 ----

  /// 画像を選び、背景画像・プロフィール画像として保存する
  /// 失敗したらSnackBarで知らせる
  Future<void> _pickImage(BuildContext context, WidgetRef ref, {required bool isBackground}) async {
    final source = await showImageSourceSheet(context);
    if (source == null) return;

    if (!context.mounted) return;
    final picked = await pickImageForUpload(context, source, maxWidth: 1080, imageQuality: 85);
    if (picked == null) return;

    final success = await ref
        .read(loadingOverlayProvider.notifier)
        .run(
          () => ref
              .read(profileEditViewModelProvider(accountId).notifier)
              .uploadImage(isBackground: isBackground, file: File(picked.path)),
        );
    if (!success && context.mounted) {
      showAppSnackBar(context, AppLocalizations.of(context)!.proEditImageSaveFailed);
    }
  }

  /// 表示名の編集シートを出し、確定したら保存する
  Future<void> _editName(BuildContext context, WidgetRef ref, String currentValue) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showTextEditSheet(
      context,
      title: l10n.proEditNameDialogTitle,
      initialValue: currentValue,
      maxLength: 20,
      minLength: 1,
      hintText: l10n.commonDisplayNameHint,
    );
    if (result == null) return;

    final success = await ref
        .read(loadingOverlayProvider.notifier)
        .run(() => ref.read(profileEditViewModelProvider(accountId).notifier).updateDisplayName(result));
    if (!success && context.mounted) {
      showAppSnackBar(context, AppLocalizations.of(context)!.proEditNameSaveFailed);
    }
  }

  /// ひとことの編集シートを出し、確定したら保存する
  Future<void> _editBio(BuildContext context, WidgetRef ref, String currentValue) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showTextEditSheet(
      context,
      title: l10n.proEditBioDialogTitle,
      initialValue: currentValue,
      maxLength: 100,
      hintText: l10n.proEditBioHint,
      maxLines: 4,
    );
    if (result == null) return;

    final success = await ref
        .read(loadingOverlayProvider.notifier)
        .run(() => ref.read(profileEditViewModelProvider(accountId).notifier).updateBio(result));
    if (!success && context.mounted) {
      showAppSnackBar(context, AppLocalizations.of(context)!.proEditBioSaveFailed);
    }
  }

  /// 「IDによる友だち追加を許可」を切り替えて保存する
  Future<void> _toggleAllowIdSearch(BuildContext context, WidgetRef ref, bool value) async {
    final success = await ref
        .read(loadingOverlayProvider.notifier)
        .run(() => ref.read(profileEditViewModelProvider(accountId).notifier).toggleAllowIdSearch(value));
    if (!success && context.mounted) {
      showAppSnackBar(context, AppLocalizations.of(context)!.proEditSettingsSaveFailed);
    }
  }

  /// アカウントIDをコピーする
  Future<void> _copyId(BuildContext context, String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!context.mounted) return;
    showAppSnackBar(context, AppLocalizations.of(context)!.commonIdCopied);
  }

  /// マイQRコード（QRC-01）を開く
  void _openQrCodeScreen(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => QrScanScreen(myAccountId: accountId)));
  }

  // ---- 画面 ----

  /// 画像・表示名・ひとこと・マイQRコード・アカウントID・ID検索の許可の行を描く
  /// アカウントの取得前は読み込み中を出す
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileEditViewModelProvider(accountId));
    final current = state.account;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(
        backgroundColor: context.colors.surface,
        titleWidget: Text(l10n.proEditAppBarTitle, style: context.textStyles.titleMedium),
        // PRO-02を経由せずSET-01まで一気に戻る（Issue: profile-edit-close-jumps-to-settings）。
        // SET-01はホーム画面（Navigatorの最初の画面）のタブのため、ホームより上の画面をすべて閉じる。
        onClose: () => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
      body: current == null
          ? const AppLoadingIndicator()
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BannerAndAvatar(
                    account: current,
                    uploadingBackground: state.uploadingBackground,
                    uploadingPhoto: state.uploadingPhoto,
                    avatarSize: _avatarSize,
                    onTapBackground: () => _pickImage(context, ref, isBackground: true),
                    onTapAvatar: () => _pickImage(context, ref, isBackground: false),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    children: [
                      ListRow(
                        label: l10n.commonDisplayNameLabel,
                        value: current.displayName,
                        onTap: () => _editName(context, ref, current.displayName),
                      ),
                      ListRow(
                        label: l10n.proEditBioLabel,
                        value: (current.bio == null || current.bio!.isEmpty) ? l10n.commonUnset : current.bio!,
                        onTap: () => _editBio(context, ref, current.bio ?? ''),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SectionCard(
                    children: [
                      ListRow(
                        leadingIcon: Icons.qr_code_2_outlined,
                        value: l10n.commonMyQrCode,
                        onTap: () => _openQrCodeScreen(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SectionCard(
                    children: [
                      ListRow(
                        label: l10n.commonAccountIdLabel,
                        value: current.id,
                        showChevron: false,
                        onTap: () => _copyId(context, current.id),
                        onLongPress: () => _copyId(context, current.id),
                      ),
                      AllowIdSearchRow(
                        value: state.allowIdSearch,
                        onChanged: (value) => _toggleAllowIdSearch(context, ref, value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
