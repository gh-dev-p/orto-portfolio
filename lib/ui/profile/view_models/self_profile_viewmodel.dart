import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/account.dart';
import '../../account/view_models/account_providers.dart';

// ============================================================
// ViewModel
// ============================================================

/// PRO-02（自分のプロフィール）のViewModel
/// 使用中のアカウントを渡す（状態はそのアカウント。使用中のアカウントが無ければnull）
///
/// 機能仕様書：4.5.1 / 画面設計書：5.7.2
class SelfProfileViewModel extends Notifier<Account?> {

  // ---- 状態・初期化 ----

  /// 表示内容を作る
  /// 使用中のアカウントを監視し、変わるたびに作り直す
  @override
  Account? build() => ref.watch(activeAccountProvider);
}

// ============================================================
// Provider
// ============================================================

/// [SelfProfileViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final selfProfileViewModelProvider = NotifierProvider.autoDispose<SelfProfileViewModel, Account?>(
  SelfProfileViewModel.new,
);
