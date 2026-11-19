import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../../utils/image_pick.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/inline_spinner.dart';
import '../../../l10n/app_localizations.dart';
import '../view_models/account_creation_viewmodel.dart';
import '../view_models/account_providers.dart';
import '../../settings/view_models/transfer_password_prompt_provider.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../core/ui/app_primary_button.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/field_label.dart';
import '../../friend/view_models/invite_link_provider.dart';
import '../../group/view_models/group_invite_providers.dart';

// ============================================================
// 画面
// ============================================================

/// 画面ACC-02：アカウント作成画面（機能仕様書4.2.1 / 画面設計書5.2.2）
/// 表示名・アカウントID（使えるかの事前確認つき）・任意のプロフィール画像を入力して作成する
///
/// アカウント数の上限の案内は呼び出し元（ACC-01の「＋」）で行い、本画面では扱わない（最終的な拒否はfirestore.rules）
class AccountCreationScreen extends ConsumerStatefulWidget {
  const AccountCreationScreen({super.key});

  @override
  ConsumerState<AccountCreationScreen> createState() => _AccountCreationScreenState();
}

// ============================================================
// State
// ============================================================

/// [AccountCreationScreen]のState
/// 入力欄のコントローラだけを持つ（入力値・確認結果などの状態は[AccountCreationViewModel]が持つ）
class _AccountCreationScreenState extends ConsumerState<AccountCreationScreen> {

  // ---- 状態・初期化 ----

  /// 表示名の入力欄のコントローラ
  final _nameController = TextEditingController();

  /// アカウントIDの入力欄のコントローラ
  final _idController = TextEditingController();

  /// 作るアカウントが何件目になるか（タイトル用）
  /// アカウントの一覧を読み込むまではnull。作成で一覧が増えても番号が変わらないよう、最初に分かった値に固定する
  int? _accountNumber;

  /// 招待してくれた人のアカウントIDの入力欄を出すか（機能仕様書4.3.5.2）
  /// 1つ目のアカウントの作成で、招待リンク・貼り付けで受け取った招待が無いときだけ出す。入力中に消えないよう、最初に分かった値に固定する
  bool? _showInviterField;

  /// 画面が消えるときに、入力欄のコントローラを破棄する
  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  /// この画面のViewModel
  AccountCreationViewModel get _viewModel => ref.read(accountCreationViewModelProvider.notifier);

  // ---- 操作 ----

  /// プロフィール画像を選ぶ
  /// 画像の選び方（カメラ・ライブラリ）のシートを開き、選んだ画像をViewModelに渡す
  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(context);
    if (source == null) return;

    if (!mounted) return;
    final picked = await pickImageForUpload(context, source, maxWidth: 1080, imageQuality: 85);
    if (picked == null) return;
    _viewModel.selectImage(File(picked.path));
  }

  /// アカウントを作成する
  /// 「作成」のタップ時に呼ぶ（画像のアップロードだけ失敗したらSnackBarで知らせ、作成できたら閉じる）
  Future<void> _create() async {
    if (!ref.read(accountCreationViewModelProvider).canCreate) return;

    // 初回作成時は、作成完了と同時にAuthGateが本画面をホームへ差し替える（unmountされる）ため、
    // 画像アップロード失敗の通知に使うScaffoldMessenger・文言は先に取得しておく。
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isFirstAccount = _accountNumber == 1;
    final transferPasswordPrompt = ref.read(transferPasswordPromptProvider.notifier);
    // 招待から来た人（招待リンク・貼り付け・招待してくれた人のID）は、作成の直後に招待の先へ直行するため、
    // 引き継ぎパスワードの案内を次の起動に回す。作成の後はホームが招待を開いて消すため、先に見ておく。
    final fromInvite = ref.read(pendingInviteProvider) != null ||
        ref.read(pendingGroupInviteProvider) != null ||
        ref.read(accountCreationViewModelProvider).inviterAccountId.trim().isNotEmpty;
    final outcome = await ref.read(loadingOverlayProvider.notifier).run(_viewModel.create);

    // 本画面が消えた後も判定を続けるため、完了を待たない（案内はホームで出す）。
    if (isFirstAccount && outcome != AccountCreationOutcome.failed) {
      unawaited(fromInvite ? transferPasswordPrompt.deferToNextLaunch() : transferPasswordPrompt.offer());
    }
    if (outcome == AccountCreationOutcome.createdWithoutImage) {
      messenger.showSnackBar(buildAppSnackBar(l10n.accCreationImageUploadFailed));
    }
    if (!mounted || outcome == AccountCreationOutcome.failed) return;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  // ---- 描画 ----

  /// 画像・表示名・アカウントID（使えるかの確認つき）・「作成」ボタンを描く
  /// ViewModelの状態を監視し、入力の誤り・確認結果・作成の失敗を表示する
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountCreationViewModelProvider);
    final checking = state.busy;
    final l10n = AppLocalizations.of(context)!;
    final accountCount = ref.watch(accountsProvider).value?.length;
    if (accountCount != null) _accountNumber ??= accountCount + 1;
    final accountNumber = _accountNumber;
    if (accountNumber != null) {
      _showInviterField ??= accountNumber == 1 &&
          ref.read(pendingInviteProvider) == null &&
          ref.read(pendingGroupInviteProvider) == null;
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(
        title: accountNumber == null ? l10n.accCreationTitle : l10n.accCreationNumberedTitle('$accountNumber'),
      ),
      body: SafeArea(
        // キーボード表示で高さが縮んでも下端がはみ出さないよう、スクロールできるようにする。
        // 下にドラッグするとキーボードを閉じられる。
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    state.image != null
                        ? ClipOval(
                            child: Image.file(state.image!, width: 96, height: 96, fit: BoxFit.cover),
                          )
                        : const AppAvatar(displayName: '', size: 96),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: context.colors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt_outlined, color: context.colors.onAccent, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _pickImage, child: Text(l10n.accCreationPickImageButton)),
              const SizedBox(height: 24),
              FieldLabel(l10n.commonDisplayNameLabel),
              TextField(
                controller: _nameController,
                maxLength: 20,
                decoration: InputDecoration(hintText: l10n.commonDisplayNameHint, counterText: ''),
                onChanged: _viewModel.updateDisplayName,
              ),
              if (!state.displayNameValid && state.displayName.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.accCreationDisplayNameLengthError,
                    style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
                  ),
                ),
              const SizedBox(height: 16),
              FieldLabel(l10n.commonAccountIdLabel),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _idController,
                      maxLength: 20,
                      decoration: InputDecoration(hintText: l10n.commonAccountIdHint, counterText: ''),
                      onChanged: _viewModel.updateAccountId,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: state.accountIdUsable && !checking ? _viewModel.checkIdAvailability : null,
                    child: checking ? const InlineSpinner() : Text(l10n.accCreationCheckAvailability),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _idStatusText(l10n, state),
                  style: state.idAvailable == false || state.accountIdReserved
                      ? context.textStyles.captionRegular.copyWith(color: context.colors.error)
                      : context.textStyles.captionRegular,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.accCreationIdImmutableNote,
                style: context.textStyles.captionRegular,
                textAlign: TextAlign.center,
              ),
              if (_showInviterField ?? false) ...[
                const SizedBox(height: 24),
                FieldLabel(l10n.accCreationInviterLabel),
                TextField(
                  maxLength: 20,
                  decoration: InputDecoration(hintText: l10n.accCreationInviterHint, counterText: ''),
                  onChanged: _viewModel.updateInviterAccountId,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    state.inviterAccountIdValid ? l10n.accCreationInviterNote : l10n.accCreationIdFormatError,
                    style: state.inviterAccountIdValid
                        ? context.textStyles.captionRegular
                        : context.textStyles.captionRegular.copyWith(color: context.colors.error),
                  ),
                ),
              ],
              if (state.errorCode != null) ...[
                const SizedBox(height: 12),
                Text(
                  switch (state.errorCode!) {
                    AccountCreationError.idTaken => l10n.accCreationIdTakenOnSubmit,
                    AccountCreationError.blocked => l10n.accCreationBlocked,
                    AccountCreationError.unknown => l10n.accCreationFailedGeneric,
                  },
                  style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
                ),
              ],
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: l10n.accCreationSubmitButton,
                enabled: state.canCreate,
                onTap: _create,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// アカウントIDの入力欄の下に出す案内・確認結果の文言
  /// 入力の形式 → 予約されたID → 確認中 → 確認結果の順に判定する
  String _idStatusText(AppLocalizations l10n, AccountCreationState state) {
    if (state.accountId.isEmpty) return l10n.accCreationIdHintFormat;
    if (!state.accountIdFormatValid) return l10n.accCreationIdFormatError;
    if (state.accountIdReserved) return l10n.accCreationIdReserved;
    if (state.busy) return l10n.accCreationIdChecking;
    if (state.idAvailable == true) return l10n.accCreationIdAvailable;
    if (state.idAvailable == false) return l10n.accCreationIdTaken;
    return l10n.accCreationIdCheckHint;
  }
}
