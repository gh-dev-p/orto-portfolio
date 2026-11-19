import 'package:flutter/material.dart';

/// Figma "Multi_id_msg_app" のデザイントークンに対応する色定義（ライト／ダークの2セット）。
///
/// テーマ（[ThemeData.extensions]）に載せて使う。画面側では`context.colors.primaryText`のように、
/// 表示中のモードの色を取り出す。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primaryText,
    required this.secondaryText,
    required this.textMutedNeutral,
    required this.sectionHeaderText,
    required this.accent,
    required this.onAccent,
    required this.accentYellow,
    required this.background,
    required this.surface,
    required this.splashBackground,
    required this.offline,
    required this.error,
    required this.shadow,
  });

  /// 文字・アイコンなど「黒」系の要素はすべてこの色に統一する。
  final Color primaryText;
  final Color secondaryText;

  /// Figmaトークン `Text/Default/Secondary`。[secondaryText]とは別系統の
  /// ニュートラルグレーで、AppHomeHeaderの＋メニュー等の書き出しコンポーネントで使用する。
  final Color textMutedNeutral;

  /// 設定画面のグループの見出しの色。
  final Color sectionHeaderText;

  /// アプリのアクセントカラー。
  final Color accent;

  /// [accent]で塗った面の上に置く文字・アイコンの色。
  final Color onAccent;
  final Color accentYellow;

  final Color background;
  final Color surface;

  /// アプリアイコン（assets/icon/app_icon.png）の地色。ネイティブスプラッシュ画面
  /// （android/app/src/main/res/values/colors.xml の`launch_background`、
  /// ios/Runner/Base.lproj/LaunchScreen.storyboard）と同じ値を、AUT-01スプラッシュ画面
  /// （splash_screen.dart）の背景にも使い、起動時の画面切り替えを目立たなくする。
  final Color splashBackground;

  final Color offline;

  final Color error;

  final Color shadow;

  static const light = AppColors(
    primaryText: Color(0xFF111111),
    secondaryText: Color(0xFF4F5E7B),
    textMutedNeutral: Color(0xFF757575),
    sectionHeaderText: Color(0xFF6B6B6B),
    accent: Color(0xFF765767),
    onAccent: Colors.white,
    accentYellow: Color(0xFFF2C94C),
    background: Color(0xFFF4F4F4),
    surface: Colors.white,
    splashBackground: Color(0xFFE1DBE7),
    offline: Color(0xFFBDBDBD),
    error: Color(0xFFEB5757),
    shadow: Color(0x1A466087),
  );

  static const dark = AppColors(
    primaryText: Colors.white,
    secondaryText: Color(0xFFA3AEC4),
    textMutedNeutral: Color(0xFFA0A0A0),
    sectionHeaderText: Color(0xFFA0A0A0),
    accent: Color(0xFFA88597),
    onAccent: Colors.white,
    accentYellow: Color(0xFFF2C94C),
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    splashBackground: Color(0xFFE1DBE7),
    offline: Color(0xFF6B6B6B),
    error: Color(0xFFEB5757),
    shadow: Color(0x66000000),
  );

  @override
  AppColors copyWith({
    Color? primaryText,
    Color? secondaryText,
    Color? textMutedNeutral,
    Color? sectionHeaderText,
    Color? accent,
    Color? onAccent,
    Color? accentYellow,
    Color? background,
    Color? surface,
    Color? splashBackground,
    Color? offline,
    Color? error,
    Color? shadow,
  }) {
    return AppColors(
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      textMutedNeutral: textMutedNeutral ?? this.textMutedNeutral,
      sectionHeaderText: sectionHeaderText ?? this.sectionHeaderText,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentYellow: accentYellow ?? this.accentYellow,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      splashBackground: splashBackground ?? this.splashBackground,
      offline: offline ?? this.offline,
      error: error ?? this.error,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      textMutedNeutral: Color.lerp(textMutedNeutral, other.textMutedNeutral, t)!,
      sectionHeaderText: Color.lerp(sectionHeaderText, other.sectionHeaderText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentYellow: Color.lerp(accentYellow, other.accentYellow, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      splashBackground: Color.lerp(splashBackground, other.splashBackground, t)!,
      offline: Color.lerp(offline, other.offline, t)!,
      error: Color.lerp(error, other.error, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  /// 表示中のモード（ライト／ダーク）の色。テーマに[AppColors]が無い場合（テストで素の
  /// MaterialAppを使う場合など）はライトの色を返す。
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
