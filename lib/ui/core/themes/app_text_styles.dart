import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Figma のタイポグラフィトークン（H1 / Title-Medium / Body-Regular 等）に対応する。
///
/// 文字色が表示中のモード（ライト／ダーク）で変わるため、画面側では`context.textStyles.h1`のように
/// [AppColors]から組み立てたものを使う。
///
/// LINEに合わせ、見出し以外は端末のシステムフォント（iOSはSan Francisco＋ヒラギノ角ゴ、
/// AndroidはRoboto＋Noto Sans CJK）を使う。fontFamilyを指定しないことでシステムフォントになる。
class AppTextStyles {
  const AppTextStyles(this._colors);

  final AppColors _colors;

  // ---- 見出し系（Noto Sans JP） ----
  // システムフォントの日本語はLINEと比べて太さが足りないため、見出し系だけNoto Sans JPを使う。
  // フォントはassets/fonts/に同梱しており、使える太さはw700（Bold）だけ。それ以外の太さを指定すると、
  // 実行時取得を止めているため読み込みエラーになる（使う場合はそのファイルも同梱すること）。

  /// 画面・ヘッダーのタイトル。
  TextStyle get h1 => GoogleFonts.notoSansJp(fontSize: 18, fontWeight: FontWeight.w700, color: _colors.primaryText);

  /// 設定画面の項目名など、一覧の行の見出し。
  TextStyle get titleBold =>
      GoogleFonts.notoSansJp(fontSize: 16, fontWeight: FontWeight.w700, color: _colors.primaryText);

  /// アカウント名・表示名など、小さめの見出し。
  TextStyle get titleMedium =>
      GoogleFonts.notoSansJp(fontSize: 14, fontWeight: FontWeight.w700, color: _colors.primaryText);

  // ---- 本文・ラベル系（システムフォント） ----

  /// 一覧のプレビュー・ひとこと・行の下の補足など、行の中の補助的な文字（LINEの同じ役割の文字と同じ12pt）。
  /// 画面の説明文には[description]、設定画面の右側の値には[settingValue]を使う。
  TextStyle get bodyRegular =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5, color: _colors.secondaryText);

  /// 画面の説明文（見出しの下の案内・確認の文言・空の状態の案内）。
  /// LINEの同じ役割の文字（電話番号の変更画面の説明等）に合わせて14pt（実機のスクリーンショットで比較）。
  TextStyle get description =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: _colors.secondaryText);

  /// 設定画面の行の右側の値（「オン」「日本語」等）。
  /// LINEの設定画面の同じ役割の文字に合わせて15pt（実機のスクリーンショットで比較）。
  TextStyle get settingValue => TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: _colors.secondaryText);

  TextStyle get captionRegular =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: _colors.secondaryText.withValues(alpha: 0.6));

  /// 未読バッジ・ボタン等、アクセント色などで塗った面の上に置く文字。
  TextStyle get captionBold => TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _colors.onAccent);

  TextStyle get tabLabel => const TextStyle(fontSize: 12, fontWeight: FontWeight.w900);

  /// iOS設定画面風のリスト行における小ラベル（例：「name」「comment」「ID」）。
  TextStyle get listItemLabel => TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: _colors.secondaryText);

  /// 設定画面のグループの見出し（例：「このアカウント」）。
  /// LINEの設定画面の同じ役割の文字に合わせて12pt。
  TextStyle get sectionHeader => TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _colors.sectionHeaderText);

  /// AppHomeHeaderの＋メニュー項目ラベル。
  TextStyle get addMenuItemLabel =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.5, color: _colors.primaryText);
}

extension AppTextStylesContext on BuildContext {
  /// 表示中のモード（ライト／ダーク）の文字スタイル。
  AppTextStyles get textStyles => AppTextStyles(colors);
}
