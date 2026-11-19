import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

// ============================================================
// サービス
// ============================================================

/// 案内ページがコピーした招待リンクを受け取るサービス（機能仕様書4.3.5.2）
/// アプリはクリップボードの本文を自分では読まない（iOSの貼り付けの確認が出るため）。URLがあるかだけを確かめ、
/// 本文はシステムの貼り付けボタン（[InvitePasteButton]、iOSのUIPasteControl）が押されたときだけ受け取る（AppDelegate.swift）
class InviteClipboardService {
  InviteClipboardService() {
    if (Platform.isIOS) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'pasted' && call.arguments is String) _pasted.add(call.arguments as String);
      });
    }
  }

  // ---- 状態・初期化 ----

  /// iOSのネイティブ処理との通信路
  static const _channel = MethodChannel('com.example.orto/invite_clipboard');

  /// 貼り付けボタンで受け取った本文
  final _pasted = StreamController<String>.broadcast();

  // ---- 読み取り ----

  /// クリップボードにURLがありそうか（本文は読まないため、iOSの貼り付けの確認は出ない）
  /// 貼り付けボタンを出せない端末（iOS 15以前・iOS以外）ではfalse
  Future<bool> hasUrl() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('hasUrl') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 貼り付けボタンが押されたときの、クリップボードの本文
  Stream<String> get pasted => _pasted.stream;
}
