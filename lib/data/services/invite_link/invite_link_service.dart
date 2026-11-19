import 'package:app_links/app_links.dart';

// ============================================================
// サービス
// ============================================================

/// アプリを開いたリンク（Universal Links／App Links、カスタムURLスキーム）を受け取るサービス
/// 状態を持たず、受け取ったリンクをそのまま返す
class InviteLinkService {
  InviteLinkService(this._appLinks);

  /// リンクの受け取り口
  final AppLinks _appLinks;

  // ---- 受け取り ----

  /// アプリを開いたリンク
  /// リンクから起動した場合の、起動時のリンクも流れる
  Stream<Uri> get links => _appLinks.uriLinkStream;
}
