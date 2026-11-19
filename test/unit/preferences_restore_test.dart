import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
import 'package:multi_id_msg/ui/core/view_models/locale_provider.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/ui/core/view_models/theme_mode_provider.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(retry: noProviderRetry, overrides: [sharedPreferencesProvider.overrideWithValue(preferences)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('端末内の設定の復元（起動直後の最初の値から保存値を使う）', () {
    test('保存したアクティブアカウント・表示言語・画面モードを、最初に読んだ時点で返す', () async {
      final container = await _container({
        'activeAccountId': 'alice',
        'appLocaleLanguageCode': 'en',
        'appThemeMode': 'dark',
      });

      expect(container.read(activeAccountIdProvider), 'alice');
      expect(container.read(localeProvider), const Locale('en'));
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('保存値が無ければ、アカウント未選択・端末の設定に従う', () async {
      final container = await _container({});

      expect(container.read(activeAccountIdProvider), isNull);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('変更すると保存し、次に起動したときに復元される', () async {
      final container = await _container({});
      await container.read(activeAccountIdProvider.notifier).setActive('bob');
      await container.read(localeProvider.notifier).setLocale(const Locale('ja'));
      await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);

      final preferences = await SharedPreferences.getInstance();
      final restarted = ProviderContainer(retry: noProviderRetry, overrides: [sharedPreferencesProvider.overrideWithValue(preferences)]);
      addTearDown(restarted.dispose);
      expect(restarted.read(activeAccountIdProvider), 'bob');
      expect(restarted.read(localeProvider), const Locale('ja'));
      expect(restarted.read(themeModeProvider), ThemeMode.light);
    });

    test('サインアウト時のクリアで、アクティブアカウントの保存値も消える', () async {
      final container = await _container({'activeAccountId': 'alice'});
      await container.read(activeAccountIdProvider.notifier).clear();

      expect(container.read(activeAccountIdProvider), isNull);
      expect((await SharedPreferences.getInstance()).getString('activeAccountId'), isNull);
    });
  });
}
