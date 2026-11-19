/// プロフィール画像・背景画像・グループの画像に使ってよいURLの判定（データ設計書7.1）
///
/// ほかのサーバーのURLを読み込むと、画像を出しただけで端末のIPがそのサーバーに分かる。
/// バケットを所有していれば、Cloud Storageのログからも分かるため、ホストだけでなくバケットまで限る。
///
/// firestore.rulesの`isOwnImageUrl`にも同じ判定がある。変更時は両方を更新すること
library;

/// このアプリのバケット（dev・本番）
const _buckets = r'(?:example-orto-prod|example-orto-dev)\.firebasestorage\.app';
const _prefix = '^https://firebasestorage\\.googleapis\\.com/v0/b/$_buckets/o/';

/// Storageのファイル名と、続くクエリ（`alt=media`・`token`など）
const _suffix = r'%2F[A-Za-z0-9._-]+(?:\?[^#\s]*)?$';

final _accountImageUrl = RegExp('${_prefix}accounts%2F([A-Za-z0-9._-]+)$_suffix');
final _groupPhotoUrl = RegExp('${_prefix}chatRooms%2F[A-Za-z0-9_-]+%2Fphoto$_suffix');

/// [url]がアカウント[accountId]の画像のダウンロードURLか
bool isOwnImageUrl(String url, String accountId) => _accountImageUrl.firstMatch(url)?.group(1) == accountId;

/// [url]がこのアプリのアカウントかグループの画像のダウンロードURLか（アカウントは問わない）
bool isStorageImageUrl(String url) => _accountImageUrl.hasMatch(url) || _groupPhotoUrl.hasMatch(url);
