import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../../config/legal_links.dart';
import '../../../utils/external_link.dart';
import 'auth_error_localization.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../../domain/models/verification_start.dart';
import '../view_models/phone_input_viewmodel.dart';
import 'verification_code_screen.dart';
import '../../core/ui/app_primary_button.dart';
import '../../friend/widgets/invite_paste_card.dart';

// ============================================================
// 画面
// ============================================================

/// 画面AUT-02：電話番号入力画面（機能仕様書4.1.1 / 画面設計書5.1.2）
/// サインインと、電話番号の変更（[phoneNumberChange]）の2つの用途で使う
class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key, this.phoneNumberChange = false});

  /// 電話番号の変更として開くか
  /// false：サインイン。true：電話番号の変更（SET-01「電話番号」から開く。AUT-03で認証できたら`true`を結果として閉じ、SET-01側で完了を通知する）
  final bool phoneNumberChange;

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

// ============================================================
// State
// ============================================================

/// [PhoneInputScreen]のState
/// 入力欄のコントローラだけを持つ（入力値・選んでいる国・地域などの状態は[PhoneInputViewModel]が持つ）
class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {

  // ---- 状態・初期化 ----

  /// 入力欄のコントローラ
  final _controller = TextEditingController();

  /// 画面が消えるときに、入力欄のコントローラを破棄する
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// この画面のViewModel
  PhoneInputViewModel get _viewModel => ref.read(phoneInputViewModelProvider(widget.phoneNumberChange).notifier);

  // ---- 操作 ----

  /// 国・地域の一覧（ボトムシート）を開く
  /// 国番号ボタンのタップ時に呼ぶ（選んだ国の番号として入力を解釈し直す）
  void _selectCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      favorite: const ['JP'],
      countryFilter: selectableCountryCodes,
      countryListTheme: CountryListThemeData(
        backgroundColor: context.colors.background,
        textStyle: context.textStyles.bodyRegular,
        searchTextStyle: context.textStyles.bodyRegular,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        bottomSheetHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      onSelect: _viewModel.selectCountry,
    );
  }

  /// 入力された番号宛にSMSを送り、AUT-03へ進む
  /// 「次へ」のタップ時に呼ぶ（電話番号の変更なら、AUT-03の結果を待って、変更できたら`true`を結果として閉じる）
  Future<void> _submit() async {
    final state = ref.read(phoneInputViewModelProvider(widget.phoneNumberChange));
    // 番号が無効、または送信中なら何もしない（連打で二重送信しないため）
    if (!state.isValid || state.sending) return;

    // ローディングを表示しながらSMSを送る
    final result = await ref.read(loadingOverlayProvider.notifier).run(_viewModel.submit);
    if (!mounted) return;

    // サインイン：SMSを送れたらAUT-03へ（端末の自動検証でサインインまで完了したときは、AuthGateが画面を切り替える）
    if (!widget.phoneNumberChange) {
      if (result == VerificationStart.codeSent) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerificationCodeScreen()));
      }
      return;
    }

    // 電話番号の変更：AUT-03を開いた場合は、その結果を待つ
    var changed = result == VerificationStart.verified;
    if (result == VerificationStart.codeSent) {
      changed =
          await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const VerificationCodeScreen())) ??
          false;
    }
    if (mounted && changed) Navigator.of(context).pop(true);
  }

  // ---- 描画 ----

  /// 見出し・国番号ボタン・入力欄・「次へ」ボタンを描く
  /// 電話番号の変更のときだけ、AppBarと説明文を出す
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneInputViewModelProvider(widget.phoneNumberChange));
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: context.colors.background,
      // 番号変更の時のみappBar表示
      appBar: widget.phoneNumberChange ? const AppScreenAppBar() : null,
      body: SafeArea(
        // 小さい画面でキーボードを開いても、同意の案内まで見られるようにスクロールできるようにする
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.phoneNumberChange) ...[
                // 番号変更画面
                Text(l10n.phoneChangeTitle, style: context.textStyles.h1),
                const SizedBox(height: 8),
                Text(l10n.phoneChangeDescription, style: context.textStyles.description),
              ] else ...[
                // サインイン画面
                const SizedBox(height: 48),
                Text(l10n.authPhoneInputTitle, style: context.textStyles.h1),
                // 案内ページで招待リンクをコピーしてからアプリを入れた人向け（機能仕様書4.3.5.2）
                const InvitePasteCard(),
              ],

              const SizedBox(height: 24),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    button: true,
                    label: l10n.authCountrySelectLabel,
                    child: Material(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _selectCountry,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.only(left: 16, right: 8),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 国旗
                              Text(state.country.flagEmoji, style: context.textStyles.titleMedium),
                              const SizedBox(width: 6),
                              // 番号接頭辞
                              Text('+${state.country.phoneCode}', style: context.textStyles.titleMedium),
                              // ドロップダウンアイコン
                              Icon(Icons.arrow_drop_down, color: context.colors.secondaryText),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.phone,
                      // 端末の電話番号を、キーボードの上の候補から入れられるようにする。変更モードでは出さない
                      autofillHints: widget.phoneNumberChange ? null : const [AutofillHints.telephoneNumber],
                      // `+`始まりで入力した場合は、選んだ国・地域より入力された国番号を優先する
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
                      style: context.textStyles.titleBold,
                      decoration: InputDecoration(
                        hintText: state.country.countryCode == 'JP' ? '090XXXXXXXX' : state.country.example,
                      ),
                      onChanged: _viewModel.updateInput,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              if (state.errorCode != null) ...[
                const SizedBox(height: 8),
                Text(
                  localizedAuthError(context, state.errorCode!),
                  style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
                ),
              ],

              const SizedBox(height: 32),

              // 次へボタン
              AppPrimaryButton(label: l10n.authNextButton, enabled: state.isValid && !state.sending, onTap: _submit),

              // 同意の案内（サインインのときだけ。電話番号の変更は同意の済んだ人が使う）
              if (!widget.phoneNumberChange) ...[
                const SizedBox(height: 16),
                Text(l10n.authLegalConsentNotice, style: context.textStyles.description),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () => openExternalLink(context, Uri.parse(LegalLinks.termsOfServiceUrl(languageCode))),
                      child: Text(l10n.setTermsOfServiceTile),
                    ),
                    TextButton(
                      onPressed: () => openExternalLink(context, Uri.parse(LegalLinks.privacyPolicyUrl(languageCode))),
                      child: Text(l10n.setPrivacyPolicyTile),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
