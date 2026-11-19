import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/app_check_activation.dart';
import 'config/app_flavor.dart';
import 'l10n/app_localizations.dart';
import 'config/preferences_provider.dart';
import 'config/provider_retry.dart';
import 'data/services/common/firestore_cache_cleaner.dart';

/// main_dev.dart／main_prod.dartから呼び出す共通の起動処理（アーキテクチャ設計書6.3）。
/// [flavor]に応じたFirebaseプロジェクトへの接続とアプリ起動を行う。
///
/// [backgroundMessageHandler]は各エントリポイント側で`@pragma('vm:entry-point')`を
/// 付与したトップレベル関数として渡すこと。バックグラウンドメッセージ受信は別Isolateで
/// 実行されるため、このファイル内のクロージャ（[options]をキャプチャする関数）では
/// `PluginUtilities.getCallbackHandle`が解決できずFCM登録に失敗する。
/// 同梱フォント（SIL Open Font License）のライセンスを、ライセンス一覧画面に表示されるよう登録する。
void _registerFontLicenses() {
  const licenses = {
    'Noto Sans JP': 'assets/fonts/licenses/notosansjp-OFL.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final entry in licenses.entries) {
      yield LicenseEntryWithLineBreaks([entry.key], await rootBundle.loadString(entry.value));
    }
  });
}

/// Firebase App Checkを有効にする。Firestore・Storage・Authentication・Cloud Functionsへの
/// リクエストに、正規のアプリであることを示すトークンが付く（本番は強制済み）。プロバイダーの選び方と、
/// App Attestが通らないときのDeviceCheckへの切り替えは[AppCheckActivator]。
///
/// デバッグビルド（シミュレーター・エミュレーター含む）はDebug Provider。デバッグトークンは環境変数
/// `FIRAAppCheckDebugToken`で渡すか、初回起動時にログへ出るものをFirebaseコンソールに登録する。
///
/// 失敗しても起動は止めない。
Future<void> _activateAppCheck(SharedPreferences preferences) async {
  try {
    await AppCheckActivator(
      preferences: preferences,
      debug: kDebugMode,
      apple: defaultTargetPlatform == TargetPlatform.iOS,
      // App Attestのentitlement（RunnerProd.entitlements）とFirebaseへの登録は本番だけにある
      appAttest: currentFlavor == AppFlavor.prod,
    ).activate();
  } catch (error, stackTrace) {
    developer.log('App Check activation failed', name: 'Startup', error: error, stackTrace: stackTrace);
  }
}

/// 退会後の起動で、端末のFirestoreのキャッシュを消す。失敗しても起動は止めない（次の起動でやり直す）。
Future<void> _clearFirestoreCacheIfRequested(SharedPreferences preferences) async {
  try {
    await FirestoreCacheCleaner(preferences).clearIfRequested(FirebaseFirestore.instance);
  } catch (error, stackTrace) {
    developer.log('Firestore cache clear failed', name: 'Startup', error: error, stackTrace: stackTrace);
  }
}

void bootstrap({
  required FirebaseOptions options,
  required AppFlavor flavor,
  required Future<void> Function(RemoteMessage) backgroundMessageHandler,
}) {
  currentFlavor = flavor;

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // フォントはassets/fonts/に同梱したものだけを使い、実行時にGoogleのサーバーから取得しない
      // （オフラインの初回起動でも見た目を変えないため）。同梱するフォントのライセンスも登録する。
      GoogleFonts.config.allowRuntimeFetching = false;
      _registerFontLicenses();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        developer.log(
          details.exceptionAsString(),
          name: 'FlutterError',
          error: details.exception,
          stackTrace: details.stack,
        );
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        developer.log('Uncaught platform error', name: 'PlatformDispatcher', error: error, stackTrace: stack);
        return true;
      };

      Object? startupError;
      StackTrace? startupStackTrace;
      SharedPreferences? preferences;
      try {
        // アクティブアカウント・表示言語・画面モードを最初の描画から正しく出すため、先に読み込んでおく
        // （preferences_provider.dart）。
        preferences = await SharedPreferences.getInstance();
        // Firebase初期化がハングした場合でも真っ白のまま止まらないよう、タイムアウトを設ける。
        await Firebase.initializeApp(options: options).timeout(const Duration(seconds: 10));
        await _activateAppCheck(preferences);
        await _clearFirestoreCacheIfRequested(preferences);
        FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);
      } catch (error, stackTrace) {
        startupError = error;
        startupStackTrace = stackTrace;
        developer.log('Firebase initialization failed', name: 'Startup', error: error, stackTrace: stackTrace);
      }

      runApp(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [if (preferences != null) sharedPreferencesProvider.overrideWithValue(preferences)],
          child: startupError == null
              ? const MultiIdMsgApp()
              : _StartupErrorApp(error: startupError, stackTrace: startupStackTrace),
        ),
      );
    },
    (error, stackTrace) {
      developer.log('Uncaught zone error', name: 'main', error: error, stackTrace: stackTrace);
    },
  );
}

/// 起動時（main実行中）に致命的なエラーが発生した場合のフォールバック画面。
/// 白画面のまま止まらないよう、起動し直しを促す決まった文言を出す。例外とスタックトレースは画面に出さず、
/// ログ（[bootstrap]の`developer.log`）に残す。開発中に原因を見られるよう、デバッグビルドだけ画面にも出す。
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error, required this.stackTrace});

  final Object? error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Firebase初期化失敗という起動最早期のフォールバック画面のため、通常アプリ
      // （app.dart）と異なりlocaleProvider（Riverpod・SharedPreferences）には
      // 依存せず、端末のシステムロケールをそのまま使う簡易構成にする。
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // MaterialAppのLocalizationsはMaterialApp配下で確立されるため、AppLocalizations.of()に
      // 渡すcontextはこのbuild(context)自身（MaterialAppの親）ではなくBuilderで
      // 取得し直したMaterialApp配下のcontextでなければならない。
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFFFFF3F3),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.startupErrorTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.startupErrorMessage, style: const TextStyle(fontSize: 15)),
                  if (kDebugMode) ...[
                    const SizedBox(height: 12),
                    Text('$error', style: const TextStyle(fontFamily: 'monospace')),
                    if (stackTrace != null) ...[
                      const SizedBox(height: 12),
                      Text('$stackTrace', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
