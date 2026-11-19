// SET-01の一番下のバージョン表示（機能仕様書4.6・画面設計書5.10.1）
// 「バージョン 1.1.1 (25)」の形で出し、取得できないときは何も出さないことを確かめる。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/auth/view_models/app_update_providers.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/settings/view_models/settings_viewmodel.dart';
import 'package:multi_id_msg/ui/settings/widgets/settings_body.dart';

class _FakeSettingsViewModel extends SettingsViewModel {
  @override
  SettingsState build() => SettingsState(
    phoneNumber: null,
    plan: null,
    transferPasswordRegistered: null,
    activeAccount: null,
    passcodeEnabled: false,
    locale: const Locale('ja'),
    themeMode: ThemeMode.system,
    isAdmin: false,
  );
}

void main() {
  Future<void> pumpSettings(WidgetTester tester, Future<({String version, String buildNumber})> Function() load) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
          currentAppBuildProvider.overrideWith((ref) => load()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SettingsBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('プライバシーポリシー'), find.byType(ListView), const Offset(0, -200));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }

  testWidgets('バージョンとビルド番号を「バージョン 1.1.1 (25)」の形で出す', (tester) async {
    await pumpSettings(tester, () async => (version: '1.1.1', buildNumber: '25'));

    expect(find.byKey(const Key('settings-app-version')), findsOneWidget);
    expect(find.text('バージョン 1.1.1 (25)'), findsOneWidget);
  });

  testWidgets('取得に失敗したら、何も出さない（画面は止めない）', (tester) async {
    await pumpSettings(tester, () async => throw StateError('no package info'));

    expect(find.byKey(const Key('settings-app-version')), findsNothing);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
  });
}
