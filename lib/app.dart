import 'dart:developer' as developer;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/core/themes/app_theme.dart';
import 'ui/core/ui/dev_env_banner.dart';
import 'ui/core/ui/keyboard_dismiss_on_tap.dart';
import 'ui/core/ui/loading_overlay_host.dart';
import 'ui/core/ui/new_message_banner.dart';
import 'ui/account/widgets/account_creation_screen.dart';
import 'ui/account/widgets/account_list_screen.dart';
import 'ui/auth/widgets/app_update_screen.dart';
import 'ui/auth/widgets/phone_input_screen.dart';
import 'ui/auth/widgets/splash_screen.dart';
import 'ui/auth/widgets/transfer_password_entry_screen.dart';
import 'ui/home/widgets/home_shell.dart';
import 'ui/passcode/widgets/passcode_guard.dart';
import 'ui/account/view_models/account_providers.dart';
import 'ui/core/ui/confirm_dialog.dart';
import 'ui/plan/widgets/kept_accounts_screen.dart';
import 'l10n/app_localizations.dart';
import 'ui/account/view_models/account_gate_viewmodel.dart';
import 'ui/core/view_models/loading_overlay_provider.dart';
import 'ui/friend/view_models/invite_link_provider.dart';
import 'ui/core/view_models/locale_provider.dart';
import 'ui/notification/view_models/notification_open_provider.dart';
import 'ui/notification/view_models/push_notification_init.dart';
import 'ui/auth/view_models/auth_gate_viewmodel.dart';
import 'ui/settings/widgets/home_notices_listener.dart';
import 'ui/settings/widgets/transfer_password_prompt.dart';
import 'ui/core/view_models/theme_mode_provider.dart';

class MultiIdMsgApp extends ConsumerWidget {
  const MultiIdMsgApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 招待リンクは、ログイン前に開いたものもログイン・アカウント作成の後に処理するため、
    // ログイン状態に関係なく最上位で受け取り始める。
    ref.listen(inviteLinkInitProvider, (_, _) {});
    ref.listen(inviteClipboardInitProvider, (_, _) {});
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Orto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        // AUT-02の国・地域の一覧（country_picker）の国名・検索欄の文言
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // パスコードロックは画面遷移の構造に依存しないよう、Navigatorの外側で全体を覆う。
      // 読み込み中表示（SMS再認証の送信中等）はガードの上にも出す。
      // ステータスバー（時刻・電池等）の文字色を、表示中のモードに合わせる（AppBarの無いホーム等の画面向け。
      // AppBarのある画面はAppBar側の設定が優先される）。
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: KeyboardDismissOnTap(
          child: DevEnvBanner(
            child: Consumer(
              builder: (context, ref, guarded) => LoadingOverlayHost(
                visible: ref.watch(loadingOverlayProvider.select((count) => count > 0)),
                child: guarded!,
              ),
              // アップデートの案内（機能仕様書4.1.6）はログインやパスコードより優先する。
              child: AppUpdateGate(
                child: NewMessageBannerHost(child: PasscodeGuard(child: child!)),
              ),
            ),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// 起動時の入口（画面設計書5.1.1 スプラッシュ画面の判定ロジック）。
/// [AuthGateViewModel]が決めた画面の種類に応じて、未ログインなら電話番号入力画面（AUT-02）、引き継ぎパスワードの
/// 確認が済んでいなければAUT-05、ログイン済みならAccount保有状況に応じて[_AccountGate]で振り分ける。
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(authGateViewModelProvider)) {
      AuthGateStatus.loading => const SplashScreen(),
      AuthGateStatus.signedOut => const PhoneInputScreen(),
      AuthGateStatus.transferPasswordRequired => const TransferPasswordEntryScreen(),
      AuthGateStatus.signedIn => const _AccountGate(),
    };
  }
}

/// ログイン後の入口（画面遷移図4章）
/// 保有するアカウントに応じて画面を出し分ける（未作成ならACC-02、使用中のアカウントがあればホーム、無ければACC-01）
class _AccountGate extends ConsumerWidget {
  const _AccountGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watchではなくlistenで起動する。watchは、上に別の画面が積まれて本画面が見えない間は一時停止し、その間は
    // アカウント一覧・表示言語の変化によるトークンの再登録も止まるが、listenは止まらない。
    ref.listen(pushNotificationInitProvider, (_, _) {});
    // プランが下がった後の案内。起動時の取得でも、起動中のプランの変化でもここを通る（機能仕様書4.2.1.3）
    ref.listen(canChooseKeptAccountsProvider, (previous, next) async {
      if (!next || previous == true) return;
      final l10n = AppLocalizations.of(context)!;
      final choose = await showConfirmDialog(
        context,
        title: l10n.keptAccountsPromptTitle,
        message: l10n.keptAccountsPromptMessage,
        confirmLabel: l10n.keptAccountsPromptChoose,
      );
      if (choose && context.mounted) await openKeptAccountsScreen(context);
    });
    // アプリを開いているときの新着は、アプリ内バナーで知らせる（機能仕様書4.4.6.2）。タップで通知先を開く。
    ref.listen<ForegroundNotification>(foregroundNotificationProvider, (_, next) {
      final target = next.target;
      final opener = ref.read(notificationOpenerProvider);
      showNewMessageBanner(
        context,
        isReaction: target?.isReaction ?? false,
        isGroupInvite: target?.isGroupInvite ?? false,
        isOrganizerInvite: target?.isOrganizerInvite ?? false,
        isJoinRequest: target?.isJoinRequest ?? false,
        isWaitlistPromoted: target?.isWaitlistPromoted ?? false,
        isAttendanceReminder: target?.isAttendanceReminder ?? false,
        isSettlementReminder: target?.isSettlementReminder ?? false,
        joinResult: target?.joinResult,
        groupName: target?.groupName,
        isFriendRequest: target?.isFriendRequest ?? false,
        isAnnouncement: target?.isAnnouncement ?? false,
        closingHoursLeft: target?.closingHoursLeft,
        // ログアウト等で本画面が無くなった後のタップでも動くよう、refではなくopenerを持たせる。
        onTap: target == null ? null : () => opener.open(target).catchError((Object _) {}),
      );
    });
    // アカウントが0件になったら（削除・他端末での削除等）、上に積まれている画面をすべて閉じ、
    // 下記の分岐で表示されるACC-02（アカウント作成画面）へ強制的に着地させる。使用中のアカウントが
    // 無くなったとき（AUT-04を閉じた等）も同様に、前のアカウントの画面を残さずACC-01へ着地させる。
    // アカウント情報の取得に失敗したときは、例外の中身をログにだけ残す（画面には決まった文言だけを出す）。
    ref.listen(accountGateViewModelProvider, (previous, next) {
      if (next is AsyncError && previous is! AsyncError) {
        developer.log('Account fetch failed', name: 'AccountGate', error: next.error, stackTrace: next.stackTrace);
      }
    });
    ref.listen(accountGateViewModelProvider, (previous, next) {
      if (next.value == AccountGateStatus.noAccount || next.value == AccountGateStatus.selectAccount) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    return ref
        .watch(accountGateViewModelProvider)
        .when(
          data: (status) => switch (status) {
            AccountGateStatus.noAccount => const AccountCreationScreen(),
            AccountGateStatus.selectAccount => const AccountListScreen(),
            AccountGateStatus.home => const HomeNoticesListener(child: TransferPasswordPromptListener(child: HomeShell())),
          },
          loading: () => const SplashScreen(),
          error: (_, _) => SplashScreen(
            error: AppLocalizations.of(context)!.accountFetchFailedMessage,
            onRetry: ref.read(accountGateViewModelProvider.notifier).retry,
          ),
        );
  }
}
