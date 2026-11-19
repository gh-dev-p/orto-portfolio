import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/account.dart';
import 'account_providers.dart';
import 'active_account_provider.dart';
import '../../../config/service_providers.dart';
import '../../passcode/view_models/passcode_providers.dart';

// ============================================================
// ViewModel
// ============================================================

/// ACC-03（アカウント削除画面）のViewModel
/// 待機中は`AsyncData(null)`、実行中は`AsyncLoading`、失敗時は`AsyncError`（エラーは1種類のため、View側で`hasError`から文言にする）
///
/// 機能仕様書：4.2.3 / 画面設計書：5.2.3
class AccountDeletionViewModel extends AsyncNotifier<void> {

  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  /// 待機中（`AsyncData(null)`）から始める
  @override
  FutureOr<void> build() {}

  // ---- 操作 ----

  /// [account]の削除の前に、パスコードの確認が要るか
  /// パスコードを設定したアカウントは、解除済みでなければ今のパスコードを求める（ロック中のアカウントをACC-01から消せないようにする）
  Future<bool> needsPasscode(Account account) async {
    if (ref.read(unlockedAccountIdProvider) == account.id) return false;
    return ref.read(passcodeRepositoryProvider).isEnabled(account.id);
  }

  /// [account]を削除する
  /// 成功したらtrue。実行中なら何もせずfalse（使用中のアカウントを削除したら、残りのアカウントに切り替えるか未選択に戻す）
  Future<bool> delete(Account account) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();

    final remaining = (ref.read(accountsProvider).value ?? const <Account>[])
        .where((a) => a.id != account.id)
        .toList();
    final wasActive = ref.read(activeAccountIdProvider) == account.id;

    final next = await AsyncValue.guard(() async {
      await ref.read(accountRepositoryProvider).softDeleteAccount(account.id);
      // 削除したアカウントのデバイスローカルのパスコード設定も消す。失敗しても削除自体は成功として扱う。
      try {
        await ref.read(passcodeRepositoryProvider).remove(account.id);
      } catch (_) {}

      // 削除したAccountがアクティブだった場合、他に有効なAccountがあれば自動切替、
      // 無ければAccount未選択状態に戻す（機能仕様書4.2.3処理フロー4）。
      if (wasActive) {
        if (remaining.isNotEmpty) {
          await ref.read(activeAccountIdProvider.notifier).setActive(remaining.first.id);
        } else {
          await ref.read(activeAccountIdProvider.notifier).clear();
        }
      }
    });

    if (ref.mounted) state = next;
    return !next.hasError;
  }
}

// ============================================================
// Provider
// ============================================================

/// [AccountDeletionViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final accountDeletionViewModelProvider =
    AsyncNotifierProvider.autoDispose<AccountDeletionViewModel, void>(AccountDeletionViewModel.new);
