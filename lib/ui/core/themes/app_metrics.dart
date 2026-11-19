import 'package:flutter/widgets.dart';

/// Figma の寸法のうち、部品の外からも参照する値や、数字だけでは意味が分からない値。
class AppMetrics {
  const AppMetrics._();

  // ---- 一覧の行（ChatRoomTile・FriendTile） ----

  /// 1行の高さ。
  static const double tileHeight = 64;

  /// 行のアバターの大きさ。
  static const double avatarSize = 48;

  /// アバターと文字の間隔。
  static const double avatarGap = 16;

  /// 行の内側の余白。
  static const EdgeInsets tilePadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  /// 友だち一覧の外側の余白。
  static const EdgeInsets friendListPadding = EdgeInsets.symmetric(vertical: 8);

  // ---- ボトムナビ（AppBottomNav） ----

  /// 項目の並びの左右の余白。
  static const double bottomNavHorizontalPadding = 40;

  /// アイコンの左端からバッジの左端までの距離。
  static const double bottomNavBadgeLeft = 14;

  // ---- その他の行・部品 ----

  /// 日付の区切りの上下の余白。
  static const EdgeInsets dateDividerPadding = EdgeInsets.only(top: 12, bottom: 6);

  /// 設定の行（SettingsTile）の高さ。
  static const double settingsTileHeight = 56;

  /// プロフィール編集のラベルつきの行の高さが60になる上下の余白。
  static const double profileLabeledRowVerticalPadding = 9.5;

  /// ブロックボタンの高さ。
  static const double blockButtonHeight = 38;

  /// 友だち追加メニューの項目の並びの左右の余白（シートの余白16の内側）。
  static const double addFriendMenuHorizontalPadding = 45;
}
