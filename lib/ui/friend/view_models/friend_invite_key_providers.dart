import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_flavor.dart';
import '../../../config/invite_links.dart';
import '../../../config/preferences_provider.dart';
import '../../../config/service_providers.dart';

// ============================================================
// 自分の招待キー
// ============================================================

/// 自分のアカウント（引数のアカウントID）の招待キー（データ設計書3.14）
/// マイQRコード・招待リンクに入れる。アプリを開いている間はアカウントごとに持ち続ける（キーは作り直さない限り変わらない）
final myFriendInviteKeyProvider = FutureProvider.family<String, String>(
  (ref, accountId) => ref.watch(friendRepositoryProvider).fetchInviteKey(accountId),
);

// ============================================================
// 受け取った招待キー
// ============================================================

/// 受け取った招待キー（招待したアカウントのID → キー）
/// マイQRコードの読み取り・招待リンクで受け取ったキーを、友だち追加（PRO-01）まで持っておく
///
/// 招待リンクは、SMS認証やアカウント作成を挟んでから開くことがあるため（[pendingInviteProvider]と同じく）端末にも保存する
class ReceivedInviteKeysNotifier extends Notifier<Map<String, String>> {
  // ---- 状態・初期化 ----

  /// 端末に保存するキー
  static const _prefsKey = 'receivedFriendInviteKeys';

  /// 持っておく数の上限（古いものから捨てる）
  static const _maxEntries = 20;

  /// 最初の状態を作る
  /// 端末に保存したものがあれば、そこから始める（読めなければ空）
  @override
  Map<String, String> build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_prefsKey);
    if (saved == null) return const {};
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
      };
    } catch (_) {
      return const {};
    }
  }

  // ---- 操作 ----

  /// アカウント[accountId]の招待キー[inviteKey]を覚える（同じアカウントは新しいキーで上書きする）
  void remember(String accountId, String inviteKey) {
    final next = Map<String, String>.of(state)..remove(accountId);
    next[accountId] = inviteKey;
    while (next.length > _maxEntries) {
      next.remove(next.keys.first);
    }
    state = next;
    ref.read(sharedPreferencesProvider).setString(_prefsKey, jsonEncode(next));
  }

  /// 招待リンク[uri]に招待キーが付いていれば覚える
  void rememberFromLink(Uri uri) {
    final accountId = InviteLinks.accountIdFrom(uri, currentFlavor);
    final inviteKey = InviteLinks.inviteKeyFrom(uri);
    if (accountId != null && inviteKey != null) remember(accountId, inviteKey);
  }
}

/// [ReceivedInviteKeysNotifier]のProvider
/// アプリ全体で共有するため、破棄しない
final receivedInviteKeysProvider = NotifierProvider<ReceivedInviteKeysNotifier, Map<String, String>>(
  ReceivedInviteKeysNotifier.new,
);
