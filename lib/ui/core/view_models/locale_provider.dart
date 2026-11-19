import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/preferences_provider.dart';

/// アプリの表示言語（機能仕様書4.6.2.1）。
/// ユーザーがSET-01で選んだ言語を優先し、未選択の間は端末の言語（[initialLocaleFor]）に従う。
/// 選択結果はローカルに永続化し、アプリ再起動後も保持する。
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final code = ref.watch(sharedPreferencesProvider).getString(_prefsKey);
    if (code != null) return Locale(code);
    return initialLocaleFor(WidgetsBinding.instance.platformDispatcher.locales);
  }

  static const _prefsKey = 'appLocaleLanguageCode';

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await ref.read(sharedPreferencesProvider).setString(_prefsKey, locale.languageCode);
  }
}

/// 表示言語を選んでいない間の言語。端末の言語の優先順（[deviceLocales]）で、最初に対応している言語
/// （日本語・英語）にする。どちらにも対応していない場合は英語にする。
Locale initialLocaleFor(List<Locale> deviceLocales) {
  for (final locale in deviceLocales) {
    if (locale.languageCode == 'ja') return const Locale('ja');
    if (locale.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
