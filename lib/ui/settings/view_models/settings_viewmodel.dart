import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../data/repositories/notification/notification_repository.dart';
import '../../../domain/models/account.dart';
import '../../account/view_models/account_providers.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../auth/view_models/auth_providers.dart';
import '../../core/view_models/locale_provider.dart';
import '../../core/view_models/theme_mode_provider.dart';
import '../../passcode/view_models/passcode_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// ログアウトの結果
enum LogoutResult {
  /// ログアウトした
  succeeded,

  /// サーバーに拒否された
  denied,

  /// それ以外の理由で失敗した
  failed,
}

/// SET-01（設定）の状態
class SettingsState {
  const SettingsState({
    required this.phoneNumber,
    required this.plan,
    required this.transferPasswordRegistered,
    required this.activeAccount,
    required this.passcodeEnabled,
    required this.locale,
    required this.themeMode,
    required this.isAdmin,
  });

  /// ログイン中の電話番号
  /// Firebase Authの値。取得前はnull
  final String? phoneNumber;

  /// プラン（`users/{uid}.plan`）
  /// `users/{uid}`の作成前・取得前はnull（無料プランとして表示する）
  final String? plan;

  /// 引き継ぎパスワードを登録済みか
  /// 取得前はnull（何も表示しない）
  final bool? transferPasswordRegistered;

  /// 使用中のアカウント
  /// アカウント削除（ACC-03）の対象。使用中のアカウントが無ければnull
  final Account? activeAccount;

  /// 使用中のアカウントにパスコードが設定されているか
  /// 取得前・使用中のアカウントが無ければfalse
  final bool passcodeEnabled;

  /// アプリの表示言語
  final Locale locale;

  /// 画面モード（ライト・ダーク・端末の設定に従う）
  final ThemeMode themeMode;

  /// ログイン中のユーザが管理者か（機能仕様書4.1.7）
  /// trueのときだけログアウトの項目を出す。取得前・取得の失敗はfalse
  final bool isAdmin;
}

// ============================================================
// ViewModel
// ============================================================

/// SET-01（設定、ホームのタブ本文）のViewModel
/// ユーザ単位の情報・パスコードロック・表示設定を表示し、表示言語・画面モード・パスコードの解除を扱う
///
/// 機能仕様書：4.6 / 画面設計書：5.6.1
class SettingsViewModel extends Notifier<SettingsState> {

  // ---- 状態・初期化 ----

  /// 表示内容を作る
  /// 表示する各項目を監視し、変わるたびに作り直す
  @override
  SettingsState build() {
    final activeAccount = ref.watch(activeAccountProvider);
    final activeAccountId = activeAccount?.id;
    return SettingsState(
      // 電話番号の変更後もすぐ反映されるよう、ユーザ情報の変化でも流れる[currentUserProvider]を使う。
      phoneNumber: ref.watch(currentUserProvider).value?.phoneNumber,
      plan: ref.watch(userPlanProvider).value,
      transferPasswordRegistered: ref.watch(transferPasswordStatusProvider).value?.registered,
      activeAccount: activeAccount,
      passcodeEnabled: activeAccountId != null && (ref.watch(passcodeEnabledProvider(activeAccountId)).value ?? false),
      locale: ref.watch(localeProvider),
      themeMode: ref.watch(themeModeProvider),
      isAdmin: ref.watch(isAdminProvider).value ?? false,
    );
  }

  // ---- 操作 ----

  /// アプリの表示言語を[locale]にする
  Future<void> setLocale(Locale locale) => ref.read(localeProvider.notifier).setLocale(locale);

  /// 画面モードを[mode]にする
  Future<void> setThemeMode(ThemeMode mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode);

  /// アカウント[accountId]のパスコードを削除する（パスコードロックのOFF）
  /// AUT-04（確認モード）で今のパスコードを入力できた後に呼ぶ
  Future<void> disablePasscode(String accountId) => ref.read(passcodeRepositoryProvider).remove(accountId);

  /// ログアウトする（管理者のみ、機能仕様書4.1.7）
  /// 成功したら[LogoutResult.succeeded]（AuthGateがAUT-02へ切り替える）。失敗したらログインしたままにする
  ///
  /// パスコードとその誤りの回数は消さない（消すと、ログアウトと再ログインでロックを回避できてしまうため）
  Future<LogoutResult> logout() async {
    final accounts = ref.read(accountsProvider).value;
    if (accounts == null) return LogoutResult.failed;
    // サインアウトするとAuthGateが画面を切り替えて本ViewModelが破棄され、破棄後のrefは使えないため、待つ前に取り出しておく。
    final logout = ref.read(logoutUseCaseProvider);
    final activeAccountId = ref.read(activeAccountIdProvider.notifier);
    try {
      await logout([for (final account in accounts) account.id]);
      // 使用中のアカウントが変わるため、パスコードの解除済みの状態もここで破棄される（UnlockedAccountNotifier）。
      await activeAccountId.clear();
      return LogoutResult.succeeded;
    } on TokenUnregisterDeniedException {
      debugPrint('[SettingsViewModel] logout failed: token unregister denied, accounts=${accounts.length}');
      return LogoutResult.denied;
    } catch (e) {
      // 例外の本文にはパスやトークンが入ることがあるため、種類だけを出す。
      debugPrint('[SettingsViewModel] logout failed: ${e.runtimeType}, accounts=${accounts.length}');
      return LogoutResult.failed;
    }
  }
}

// ============================================================
// Provider
// ============================================================

/// [SettingsViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final settingsViewModelProvider = NotifierProvider.autoDispose<SettingsViewModel, SettingsState>(
  SettingsViewModel.new,
);
