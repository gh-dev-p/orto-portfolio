import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/chat_room.dart';
import '../../../domain/models/group.dart';
import '../../account/view_models/account_providers.dart';
import '../../block/view_models/block_providers.dart';
import '../../group/view_models/group_providers.dart';

// ============================================================
// 型
// ============================================================

/// アルバムを指す引数（トークのIDとアルバムのID）
typedef AlbumKey = ({String chatRoomId, String albumId});

/// アルバムの項目の取得の引数
typedef AlbumItemsKey = ({String chatRoomId, String albumId, int limit});

// ============================================================
// Provider
// ============================================================

/// トークのアルバムの一覧（更新の新しい順）
/// 引数はトークのID
final albumsProvider = StreamProvider.autoDispose.family<List<Album>, String>((ref, chatRoomId) {
  return ref.watch(albumRepositoryProvider).watchAlbums(chatRoomId);
});

/// アルバム（消されたらnull）
final albumProvider = StreamProvider.autoDispose.family<Album?, AlbumKey>((ref, key) {
  return ref.watch(albumRepositoryProvider).watchAlbum(chatRoomId: key.chatRoomId, albumId: key.albumId);
});

/// 画像・動画の表示用のURL
/// 引数は項目の`path`。URLはリポジトリの実装から取得する
final albumMediaUrlProvider = FutureProvider.autoDispose.family<String, String>((ref, path) {
  return ref.watch(albumRepositoryProvider).mediaUrl(path);
});

/// アルバムの項目（新しい順）
final albumItemsProvider = StreamProvider.autoDispose.family<List<AlbumItem>, AlbumItemsKey>((ref, key) {
  return ref
      .watch(albumRepositoryProvider)
      .watchItems(chatRoomId: key.chatRoomId, albumId: key.albumId, limit: key.limit);
});

/// アルバムの変更・追加の可否を決める引数（トークのID、自分のアカウント、相手（グループはnull））
typedef AlbumEditKey = ({String chatRoomId, String myAccountId, String? peerAccountId});

/// トークが閉じたオフ会グループなら、そのグループ（それ以外はnull。機能仕様書4.4.9.5）
/// 閉じたあとのアルバムは読むだけ（見る・端末に保存するだけ）で、閉じてから30日で消える
/// 引数はトークのID。1対1は閉じないので、ルームを読まない
final albumClosedRoomProvider = Provider.autoDispose.family<GroupRoom?, String>((ref, chatRoomId) {
  if (!isGroupChatRoomId(chatRoomId)) return null;
  final room = ref.watch(groupRoomProvider(chatRoomId)).value;
  return room != null && room.isClosedAt(DateTime.now()) ? room : null;
});

/// アカウントが、トークのアルバムを変更できるか（作成・追加・名前の変更。表示用）
/// 読み取り専用の間、1対1でブロック関係にある間、閉じたオフ会グループでは変更できない。拒否はサーバーが保証する
final canEditAlbumsProvider = Provider.autoDispose.family<bool, AlbumEditKey>((ref, key) {
  if (ref.watch(isReadOnlyProvider(key.myAccountId))) return false;
  if (ref.watch(albumClosedRoomProvider(key.chatRoomId)) != null) return false;
  final peerAccountId = key.peerAccountId;
  if (peerAccountId == null) return true;
  final blocked = ref.watch(blockedAccountsProvider).value ?? const [];
  if (blocked.any((account) => account.blockedAccountId == peerAccountId)) return false;
  return !(ref.watch(blockedByPeerProvider(peerAccountId)).value ?? false);
});

/// サムネイルのディスクキャッシュ
/// 開くたびにダウンロードすると通信量が増えるため、端末に残す
final albumThumbnailCacheProvider = Provider<BaseCacheManager>(
  (ref) => CacheManager(
    Config('albumThumbnails', stalePeriod: const Duration(days: 60), maxNrOfCacheObjects: 3000),
  ),
);

/// サムネイルの端末上のファイル
/// 引数は項目の`thumbnailPath`。キャッシュにあれば、URLも取得しない
final albumThumbnailFileProvider = FutureProvider.autoDispose.family<File, String>((ref, path) async {
  final cache = ref.watch(albumThumbnailCacheProvider);
  final cached = await cache.getFileFromCache(path);
  if (cached != null) return cached.file;
  final url = await ref.read(albumRepositoryProvider).mediaUrl(path);
  final info = await cache.downloadFile(url, key: path);
  return info.file;
});
