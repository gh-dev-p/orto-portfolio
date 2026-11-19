import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';

// ============================================================
// Provider
// ============================================================

/// 引き継ぎパスワードの案内を出す予定があるかを持つNotifier（機能仕様書4.1.4.1）
///
/// 最初のアカウントの作成でACC-02が消えた後に判定を終え、ホームで案内を出すため、画面より長く生存する
class TransferPasswordPromptNotifier extends Notifier<bool> {
  /// 最初は案内を出す予定がない
  @override
  bool build() => false;

  /// 未設定で、まだ案内を出していなければ、案内を出す予定にする
  /// 最初のアカウントの作成後に呼ぶ。設定の有無を確認できなければ出さない
  Future<void> offer() async {
    final auth = ref.read(authRepositoryProvider);
    final uid = auth.currentUser?.uid;
    if (uid == null || ref.read(transferPasswordPromptRepositoryProvider).wasShown(uid)) return;
    try {
      // 別の端末で設定した直後でも正しく判定できるよう、IDトークンを取り直す。
      final status = await auth.transferPasswordStatus(forceRefresh: true);
      if (status.registered) return;
    } catch (e) {
      debugPrint('[TransferPasswordPrompt] transferPasswordStatus failed: $e');
      return;
    }
    if (ref.mounted) state = true;
  }

  /// この起動の間は案内を出さないか（[deferToNextLaunch]を呼んだ）
  bool _deferredInThisLaunch = false;

  /// 招待から来た人の最初のアカウントの作成で、[offer]の代わりに呼ぶ
  /// 作成の直後は招待の先（GRP-05・PRO-01）へ直行するため、この起動の間は出さず、次の起動で出す
  Future<void> deferToNextLaunch() async {
    _deferredInThisLaunch = true;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    await ref.read(transferPasswordPromptRepositoryProvider).markDeferred(uid);
  }

  /// 前の起動で[deferToNextLaunch]していれば、[offer]する
  /// ホームが作られたときに呼ぶ。同じ起動の間に先送りした分は出さない
  Future<void> offerIfDeferred() async {
    if (_deferredInThisLaunch) return;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    final repository = ref.read(transferPasswordPromptRepositoryProvider);
    if (uid == null || !repository.isDeferred(uid)) return;
    await repository.clearDeferred(uid);
    await offer();
  }

  /// 案内を出したことを保存し、予定を消す
  /// 案内を出すときに呼ぶ（「あとで設定する」でも、途中でアプリを閉じても、2回目を出さない）
  Future<void> markShown() async {
    state = false;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid != null) await ref.read(transferPasswordPromptRepositoryProvider).markShown(uid);
  }
}

/// [TransferPasswordPromptNotifier]のProvider
final transferPasswordPromptProvider = NotifierProvider<TransferPasswordPromptNotifier, bool>(
  TransferPasswordPromptNotifier.new,
);
