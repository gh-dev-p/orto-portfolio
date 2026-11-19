import 'dart:io';

import '../../../domain/models/album.dart';
import '../../../domain/models/report_reason.dart';

// ============================================================
// リポジトリ
// ============================================================

/// トークのアルバムのリポジトリの窓口
/// 画面からは保存先が見えないよう、引数と戻り値はドメインのモデルと端末のファイルだけにする（サーバーの実装は差し替えられる）
///
/// 共通の約束：
/// - [Album]の`itemCount`・`coverThumbnailPath`、ルームごとの上限はサーバー側が集計・判定する
/// - uidを扱わない。操作した人は常にアカウントIDで渡す
/// - `path`・`thumbnailPath`は保存先を指すキーで、中身は実装だけが扱う
///
/// 機能仕様書：4.4.9
abstract interface class AlbumRepository {
  // ---- 読み込み ----

  /// トークのアルバムを、更新の新しい順に監視する
  Stream<List<Album>> watchAlbums(String chatRoomId);

  /// アルバムを監視する（無ければ、消されたらnull）
  Stream<Album?> watchAlbum({required String chatRoomId, required String albumId});

  /// アルバムの新しい順の項目を[limit]件監視する
  Stream<List<AlbumItem>> watchItems({required String chatRoomId, required String albumId, required int limit});

  /// 項目の`path`・`thumbnailPath`から、表示用のURLを取得する
  Future<String> mediaUrl(String path);

  /// 項目の`path`のファイルを、端末の[file]へダウンロードする
  Future<void> downloadFile(String path, File file);

  // ---- アルバムの操作 ----

  /// アルバムを作り、そのIDを返す
  /// 1対1の最初のトークでは、[peerAccountId]との間のルームも作る
  Future<String> createAlbum({
    required String chatRoomId,
    required String name,
    required String accountId,
    required String? peerAccountId,
  });

  /// アルバムの名前を変える
  Future<void> renameAlbum({
    required String chatRoomId,
    required String albumId,
    required String name,
    required String accountId,
  });

  /// アルバムを、中の項目とファイルごと消す
  Future<void> deleteAlbum({required String chatRoomId, required String albumId});

  // ---- 項目の操作 ----

  /// 変換済みの[media]をアップロードし、項目を作る
  /// 上限・ブロック・読み取り専用で拒否されたら`AlbumAddFailure.rejected`、通信の失敗は`AlbumAddFailure.failed`の[AlbumAddException]を投げる
  /// [onProgress]には本体のアップロードの進み具合（0〜1）を渡す
  Future<void> addItem({
    required String chatRoomId,
    required String albumId,
    required String accountId,
    required PreparedAlbumMedia media,
    void Function(double progress)? onProgress,
  });

  /// 項目をファイルごと消す
  Future<void> deleteItem({required String chatRoomId, required String albumId, required String itemId});

  // ---- トークとの連携 ----

  /// アルバムの作成・追加の案内をトークに送る
  /// 1回の操作につき1件。通常のメッセージとして未読・通知・トーク一覧に反映される
  Future<void> sendNotice({
    required String chatRoomId,
    required String senderAccountId,
    required String? peerAccountId,
    required String albumId,
    required String albumName,
    required AlbumEvent event,
    required int itemCount,
  });

  /// 項目を通報する
  /// 通報された項目は、削除されても運営者が確認できるよう保全する
  Future<void> reportItem({
    required String chatRoomId,
    required String albumId,
    required String itemId,
    required String reporterAccountId,
    required String targetAccountId,
    required ReportReason reason,
    String? detail,
  });
}
