import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_metrics.dart';
import '../../../config/legal_links.dart';
import '../../core/themes/app_colors.dart';
import '../../../utils/external_link.dart';
import '../../../utils/phone_number_format.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../view_models/settings_viewmodel.dart';
import '../../account/widgets/account_deletion_screen.dart';
import '../../auth/view_models/app_update_providers.dart';
import '../../auth/widgets/phone_input_screen.dart';
import '../../passcode/widgets/passcode_entry_screen.dart';
import '../../plan/widgets/plan_screen.dart';
import '../../profile/widgets/section_card.dart';
import '../../profile/widgets/self_profile_screen.dart';
import 'block_list_screen.dart';
import 'display_mode_dialog.dart';
import 'notification_settings_screen.dart';
import 'passcode_setup_screen.dart';
import 'transfer_password_setup_screen.dart';
import 'withdrawal_screen.dart';

// ============================================================
// 画面
// ============================================================

/// 画面SET-01：設定（ハブ）の本文（画面設計書5.6.1）
/// 14項目を、反映される範囲で「このアカウント」「すべてのアカウント」「アプリ情報」の3つのカードに分けて並べる
/// 管理者には、ログアウトの項目を加える（機能仕様書4.1.7）
///
/// 通知は、SET-06（通知設定）への入口だけ（機能仕様書4.6.1）
/// ヘッダー・ボトムナビは[HomeShell]が持つため、本Widgetはタブの本文だけを描く
class SettingsBody extends ConsumerWidget {
  const SettingsBody({super.key});

  // ---- 操作 ----

  /// 表示言語を選ぶダイアログを出し、選んだ言語にする
  Future<void> _selectLanguage(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<Locale>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.setLanguageTile),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(const Locale('ja')),
            child: Text(l10n.languageJapanese),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(const Locale('en')),
            child: Text(l10n.languageEnglish),
          ),
        ],
      ),
    );
    if (selected == null) return;
    await ref.read(settingsViewModelProvider.notifier).setLocale(selected);
  }

  /// 画面モード（ライト・ダーク・端末の設定に従う）を選ぶダイアログ（[DisplayModeDialog]）を出す
  /// 選んだモードはダイアログの中でその場で反映する
  Future<void> _selectDisplayMode(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const DisplayModeDialog());

  /// 電話番号の変更を開く
  /// 新しい番号でSMS認証できたら、完了をSnackBarで知らせる
  Future<void> _changePhoneNumber(BuildContext context) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PhoneInputScreen(phoneNumberChange: true)));
    if (changed == true && context.mounted) {
      showAppSnackBar(context, AppLocalizations.of(context)!.phoneChangeCompleted);
    }
  }

  /// 引き継ぎパスワードの登録・変更（SET-05）を開く
  /// 登録できたら、完了をSnackBarで知らせる
  Future<void> _setTransferPassword(BuildContext context) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const TransferPasswordSetupScreen()));
    if (saved == true && context.mounted) {
      showAppSnackBar(context, AppLocalizations.of(context)!.transferPasswordSaved);
    }
  }

  /// 画面モードの表示名
  static String _displayModeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
    ThemeMode.light => l10n.displayModeLight,
    ThemeMode.dark => l10n.displayModeDark,
    ThemeMode.system => l10n.displayModeSystem,
  };

  /// パスコードロックをON・OFFする（画面設計書5.6.1）
  /// 使用中のアカウントが対象。ONにするとSET-03で新しいパスコードを設定し、OFFにするとAUT-04（確認モード）で今のパスコードを入力できた場合だけ解除する（どちらもキャンセルされたら変わらない）
  Future<void> _setPasscodeEnabled(BuildContext context, WidgetRef ref, String accountId, bool enable) async {
    final navigator = Navigator.of(context);
    if (enable) {
      await navigator.push<bool>(MaterialPageRoute(builder: (_) => PasscodeSetupScreen(accountId: accountId)));
      return;
    }
    final confirmed = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => PasscodeEntryScreen(accountId: accountId, mode: PasscodeEntryMode.confirm),
      ),
    );
    if (confirmed == true) {
      await ref.read(settingsViewModelProvider.notifier).disablePasscode(accountId);
    }
  }

  /// 使用中のアカウントの削除（ACC-03）を開く
  void _openAccountDeletion(BuildContext context, WidgetRef ref) {
    final account = ref.read(settingsViewModelProvider).activeAccount;
    if (account == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountDeletionScreen(account: account)));
  }

  /// 確認のダイアログを出して、ログアウトする（管理者のみ、機能仕様書4.1.7）
  /// 成功したらAuthGateがAUT-02へ切り替える。失敗したらSnackBarで知らせる
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.setLogoutConfirmTitle,
      message: l10n.setLogoutConfirmMessage,
      confirmLabel: l10n.setLogoutTile,
    );
    if (!confirmed || !context.mounted) return;
    final loading = ref.read(loadingOverlayProvider.notifier);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final result = await loading.run(viewModel.logout);
    if (!context.mounted) return;
    switch (result) {
      case LogoutResult.succeeded:
        break;
      case LogoutResult.denied:
        showAppSnackBar(context, l10n.setLogoutDenied);
      case LogoutResult.failed:
        showAppSnackBar(context, l10n.setLogoutFailed);
    }
  }

  /// お問い合わせ（端末のメールアプリ）を開く
  /// 宛先はLegalLinks.contactEmailだけを指定し、件名・本文は付けない
  Future<void> _openContactMail(BuildContext context) =>
      openExternalLink(context, Uri(scheme: 'mailto', path: LegalLinks.contactEmail));

  /// プライバシーポリシーを、表示言語のページで開く
  Future<void> _openPrivacyPolicy(BuildContext context) =>
      openExternalLink(context, Uri.parse(LegalLinks.privacyPolicyUrl(Localizations.localeOf(context).languageCode)));

  /// 利用規約を、表示言語のページで開く
  Future<void> _openTermsOfService(BuildContext context) =>
      openExternalLink(context, Uri.parse(LegalLinks.termsOfServiceUrl(Localizations.localeOf(context).languageCode)));

  // ---- 画面 ----

  /// 設定の項目を並べて描く
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    final locale = state.locale;
    final themeMode = state.themeMode;
    final activeAccountId = state.activeAccount?.id;
    final passcodeEnabled = state.passcodeEnabled;
    final phoneNumber = state.phoneNumber;
    final transferPasswordRegistered = state.transferPasswordRegistered;

    // 項目数が多く、画面の低い端末では収まらないため、スクロールできるようにする。
    // 反映される範囲で3つに分け、見出しを付けたカードに入れる（使用中のアカウントだけ／全アカウント共有／アプリ情報）。
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _SectionHeader(l10n.setSectionThisAccount),
        SectionCard(
          children: [
            // プロフィール
            _SettingsTile(
              icon: Icons.person_outline,
              label: l10n.setProfileTile,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SelfProfileScreen())),
            ),

            // パスコードロック
            _SettingsTile(
              icon: Icons.lock_outline,
              label: l10n.setPasscodeTile,
              showChevron: false,
              trailing: Switch.adaptive(
                value: passcodeEnabled,
                activeTrackColor: context.colors.accent,
                onChanged: activeAccountId == null
                    ? null
                    : (value) => _setPasscodeEnabled(context, ref, activeAccountId, value),
              ),
              onTap: () {
                if (activeAccountId != null) {
                  _setPasscodeEnabled(context, ref, activeAccountId, !passcodeEnabled);
                }
              },
            ),

            // 通知（機能仕様書4.6.1）。タップでSET-06を開く。
            // 端末の許可とアカウントの設定の2段があり、1つの「オン」／「オフ」では誤解を生むため、右端に状態は出さない。
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: l10n.setNotificationTile,
              onTap: () {
                if (activeAccountId == null) return;
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => NotificationSettingsScreen(accountId: activeAccountId)));
              },
            ),

            // ブロックリスト
            _SettingsTile(
              icon: Icons.block,
              label: l10n.setBlockListTitle,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BlockListScreen())),
            ),

            // アカウント削除
            _SettingsTile(
              icon: Icons.delete_outline,
              label: l10n.setAccountDeletionTile,
              destructive: true,
              onTap: () => _openAccountDeletion(context, ref),
            ),
          ],
        ),
        _SectionHeader(l10n.setSectionAllAccounts),
        SectionCard(
          children: [
            // プラン（ユーザ単位）。タップでSET-07を開く。
            _SettingsTile(
              icon: Icons.workspace_premium_outlined,
              label: l10n.planTitle,
              trailing: Text(planDisplayName(l10n, state.plan), style: context.textStyles.settingValue),
              onTap: () => openPlanScreen(context),
            ),

            // 電話番号（ユーザ単位の情報）。タップで変更できる。
            _SettingsTile(
              icon: Icons.phone_outlined,
              label: l10n.setPhoneNumberTile,
              trailing: Text(
                phoneNumber == null ? '' : formatMaskedPhoneNumber(phoneNumber),
                style: context.textStyles.settingValue,
              ),
              onTap: () => _changePhoneNumber(context),
            ),

            // 引き継ぎパスワード（ユーザ単位）。未設定なら登録を促すため赤字で表示する。
            _SettingsTile(
              icon: Icons.key_outlined,
              label: l10n.setTransferPasswordTile,
              trailing: transferPasswordRegistered == null
                  ? null
                  : Text(
                      transferPasswordRegistered
                          ? l10n.setTransferPasswordRegistered
                          : l10n.setTransferPasswordNotRegistered,
                      style: context.textStyles.settingValue.copyWith(
                        color: transferPasswordRegistered ? null : context.colors.error,
                      ),
                    ),
              onTap: () => _setTransferPassword(context),
            ),

            // 言語
            _SettingsTile(
              icon: Icons.language_outlined,
              label: l10n.setLanguageTile,
              trailing: Text(
                locale.languageCode == 'en' ? l10n.languageEnglish : l10n.languageJapanese,
                style: context.textStyles.settingValue,
              ),
              onTap: () => _selectLanguage(context, ref),
            ),

            // 画面モード
            _SettingsTile(
              icon: Icons.brightness_6_outlined,
              label: l10n.setDisplayModeTile,
              trailing: Text(_displayModeLabel(l10n, themeMode), style: context.textStyles.settingValue),
              onTap: () => _selectDisplayMode(context),
            ),

            // ログアウト（ユーザ単位。管理者にだけ出す）
            if (state.isAdmin)
              _SettingsTile(
                icon: Icons.logout,
                label: l10n.setLogoutTile,
                destructive: true,
                onTap: () => _logout(context, ref),
              ),

            // 退会（ユーザ単位。保有する全アカウントを削除する）
            _SettingsTile(
              icon: Icons.person_remove_outlined,
              label: l10n.setWithdrawalTile,
              destructive: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WithdrawalScreen())),
            ),
          ],
        ),
        _SectionHeader(l10n.setSectionAppInfo),
        SectionCard(
          children: [
            // お問い合わせ
            _SettingsTile(icon: Icons.mail_outline, label: l10n.setContactTile, onTap: () => _openContactMail(context)),

            // 利用規約
            _SettingsTile(
              icon: Icons.description_outlined,
              label: l10n.setTermsOfServiceTile,
              onTap: () => _openTermsOfService(context),
            ),

            // プライバシーポリシー
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              label: l10n.setPrivacyPolicyTile,
              onTap: () => _openPrivacyPolicy(context),
            ),
          ],
        ),
        const _AppVersionLabel(),
      ],
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// 設定のグループ（[SectionCard]）の上に置く見出し
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(label, style: context.textStyles.sectionHeader),
    );
  }
}

/// 動いているアプリのバージョンとビルド番号（「バージョン 1.1.1 (25)」）
/// 問い合わせやTestFlightの確認で、どのビルドかを画面で分かるようにする。取得できない間・失敗したときは何も出さない
class _AppVersionLabel extends ConsumerWidget {
  const _AppVersionLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final build = ref.watch(currentAppBuildProvider).value;
    if (build == null) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Text(
        AppLocalizations.of(context)!.setAppVersion(build.version, build.buildNumber),
        key: const Key('settings-app-version'),
        textAlign: TextAlign.center,
        style: context.textStyles.captionRegular.copyWith(color: context.colors.secondaryText),
      ),
    );
  }
}

/// 設定の1行
/// アイコン・ラベルと、右端の現在値・シェブロンを並べる（削除・退会の行は赤字）
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
    this.trailing,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;

  /// タップ時に呼ぶ
  /// nullなら表示だけの項目（プラン等）
  final VoidCallback? onTap;
  final bool destructive;

  /// 行の右端（シェブロンの手前）に置くWidget
  /// 今の値の表示など（例：今の言語）
  final Widget? trailing;

  /// 行の右端のシェブロン（遷移を示す矢印）を出すか
  /// スイッチ等で行の中で完結する項目ではfalse
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.colors.error : context.colors.primaryText;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        constraints: const BoxConstraints(minHeight: AppMetrics.settingsTileHeight),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label, style: context.textStyles.titleBold.copyWith(color: color)),
            ),
            if (trailing != null) ...[trailing!, if (showChevron) const SizedBox(width: 8)],
            if (!destructive && showChevron) Icon(Icons.chevron_right, color: context.colors.secondaryText),
          ],
        ),
      ),
    );
  }
}
