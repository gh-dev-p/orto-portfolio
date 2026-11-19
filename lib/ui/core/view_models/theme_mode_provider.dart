import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/preferences_provider.dart';

/// アプリの表示モード（ライト／ダーク）。未選択時は端末の設定に合わせる。
/// 選択結果はローカルに永続化し、アプリ再起動後も保持する（[LocaleNotifier]と同じ方式）。
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_prefsKey);
    return ThemeMode.values.asNameMap()[name] ?? ThemeMode.system;
  }

  static const _prefsKey = 'appThemeMode';

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_prefsKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
