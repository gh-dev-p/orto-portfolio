import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/account.dart';
import '../../../config/service_providers.dart';

// ============================================================
// enum
// ============================================================

/// FRI-04（友だち検索）の検索の失敗
/// Viewが表示の文言に変換する
enum FriendSearchError {
  /// 自分のアカウントIDを検索した
  selfAdd,
  /// 通信の失敗等で検索できなかった
  searchFailed,
  /// 見つからなかった（ID検索を許可していない・退会済み・ブロック関係にあるアカウントも含む）
  notFound,
}

// ============================================================
// ViewModel
// ============================================================

/// FRI-04（友だち検索）のViewModel
/// アカウントIDの完全一致で検索する（未検索・入力を変えた後はnull、見つかったらそのアカウント、失敗したら[FriendSearchError]を持つAsyncError）
///
/// 機能仕様書：4.3.1 / 画面設計書：5.4.4
class FriendSearchViewModel extends AsyncNotifier<Account?> {

  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  /// 未検索（null）から始める
  @override
  FutureOr<Account?> build() {
    return null;
  }

  // ---- 操作 ----

  /// アカウントID[id]で検索する
  /// 空・検索中なら何もしない
  Future<void> search({required String id, required String myAccountId}) async {
    if (id.isEmpty || state.isLoading) return;

    if (id == myAccountId) {
      state = AsyncError(FriendSearchError.selfAdd, StackTrace.current);
      return;
    }

    state = const AsyncLoading();

    Account? found;
    bool blocked;
    try {
      found = await ref.read(accountRepositoryProvider).getAccount(id);
      // ID検索を許可していない（allowIdSearchがfalse）アカウントは、無い場合と同じ扱いにする（
      // OFFのアカウントがあること自体を推測させないため）。退会済みのアカウントも友だち追加の対象外のため、同じ扱い。
      if (found == null || found.isDeleted || !found.allowIdSearch) {
        if (ref.mounted) state = AsyncError(FriendSearchError.notFound, StackTrace.current);
        return;
      }
      blocked = await ref.read(blockRepositoryProvider).isBlockedEitherWay(myAccountId, found.id);
    } catch (_) {
      if (ref.mounted) state = AsyncError(FriendSearchError.searchFailed, StackTrace.current);
      return;
    }
    if (!ref.mounted) return;

    // ブロック関係にあるアカウント同士は、ID検索の設定とは別に結果から除く（画面設計書5.6.2）。
    // ブロックした事実を悟らせないよう、これも「見つからない」扱い。
    if (blocked) {
      state = AsyncError(FriendSearchError.notFound, StackTrace.current);
      return;
    }

    state = AsyncData(found);
  }

  /// 前回の結果・失敗を消す
  /// 入力を変えたときに呼ぶ（検索中・既に空なら何もしない）
  void reset() {
    if (!state.hasError && state.value == null) return;
    state = const AsyncData(null);
  }
}

// ============================================================
// Provider
// ============================================================

/// [FriendSearchViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final friendSearchViewModelProvider = AsyncNotifierProvider.autoDispose<FriendSearchViewModel, Account?>(
  FriendSearchViewModel.new,
);
