import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: brightness,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        surface: colors.surface,
        onSurface: colors.primaryText,
        error: colors.error,
      ),
      scaffoldBackgroundColor: colors.background,
      // fontFamilyは指定せず、端末のシステムフォントを使う（LINEに合わせる。AppTextStyles参照）。
    );

    return base.copyWith(
      extensions: [colors],
      // タップの波紋はAndroidらしさが強いため出さない。押下の反応はハイライト（Flutter既定の薄いグレー）で出す。
      // 塗りのある部品はハイライトが隠れるため、PressOpacityで薄くする。
      splashFactory: NoSplash.splashFactory,
      textTheme: base.textTheme.apply(bodyColor: colors.primaryText, displayColor: colors.primaryText),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.primaryText,
        elevation: 0,
        centerTitle: true,
        // スクロールしてもバーを染めない（Material 3既定では中身の下でアクセント色が乗る）。
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      // 区切り線はiOSのように細くする。
      dividerTheme: const DividerThemeData(thickness: 0.5),
      // ボトムシートはiOSのシートに合わせ、上端につまみを出す。
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        showDragHandle: true,
        dragHandleSize: const Size(36, 5),
        dragHandleColor: colors.secondaryText.withValues(alpha: 0.4),
      ),
      // OFF時のスイッチのトラックは既定色だと主張が強いため、画面背景色に寄せて控えめにする
      // （枠・つまみは既定色のまま）。iOSのSwitch.adaptiveにはこのテーマは効かず、iOS既定の色になる。
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? null : colors.background,
        ),
      ),
      // ポップアップ（AlertDialog・SimpleDialog共通）はLINEに寄せ、タイトルを太字・控えめなサイズ、
      // 本文を標準サイズにする（Material 3既定のタイトル24px細字は主張が強すぎるため）。
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.primaryText),
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: colors.primaryText,
        ),
      ),
      // SnackBarはiOSのトースト風にする（Material既定の画面下端いっぱいの帯は、Androidらしさが強いため）。
      // 画面下に浮かぶ角丸のカードにし、影は付けない。文言の中央寄せ・表示時間はbuildAppSnackBar（app_snack_bar.dart）。
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark ? const Color(0xF23A3A3C) : const Color(0xE6222222),
        contentTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // 欄の中のヒント（見本）はiOSのプレースホルダーのように薄いグレーにし、入力済みの文字と見分けられるようにする
        hintStyle: TextStyle(color: colors.secondaryText.withValues(alpha: 0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
