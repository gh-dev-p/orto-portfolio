import 'package:flutter/material.dart';

/// テキストのみを表示する簡易SnackBarの共通ヘルパー。
void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(buildAppSnackBar(message));
}

/// テキストのみの簡易SnackBarを作る（[showAppSnackBar]と、ScaffoldMessengerを先に取得しておく呼び出し元で共通）
/// 見た目（画面下に浮かぶ角丸のカード）はAppThemeの`snackBarTheme`で決め、ここでは文言を中央寄せにし、表示時間を短めにする（iOSのトースト風）
SnackBar buildAppSnackBar(String message) {
  return SnackBar(
    content: Text(message, textAlign: TextAlign.center),
    duration: const Duration(seconds: 3),
  );
}
