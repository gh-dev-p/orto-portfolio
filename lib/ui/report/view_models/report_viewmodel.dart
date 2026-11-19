import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/report_reason.dart';

// ============================================================
// enum・定数
// ============================================================

/// 通報の詳しい内容（任意）の最大文字数（firestore.rulesの`reports`と揃える）
const reportDetailMaxLength = 500;

/// 通報の結果
/// Viewが閉じ方・表示の文言を決める
enum ReportOutcome {
  /// 通報した（ブロックはしていない）
  reported,

  /// 通報し、ブロックもした
  reportedAndBlocked,

  /// 通報したが、ブロックに失敗した
  blockFailed,

  /// 通報に失敗した（何も記録されていない）
  failed,
}

// ============================================================
// 状態クラス
// ============================================================

/// REP-01（通報）を開くときの引数
/// 自分のアカウントID・通報する相手のアカウントIDと、メッセージから通報した場合はそのメッセージのID
/// グループでは[chatRoomId]にグループのIDを渡す。[targetAccountId]がnullならグループを対象にした通報
/// アルバムの項目から通報した場合は、[chatRoomId]と[albumId]・[albumItemId]を渡す（1対1でも[chatRoomId]を渡す）
typedef ReportArgs = ({
  String myAccountId,
  String? targetAccountId,
  String? messageId,
  String? chatRoomId,
  String? albumId,
  String? albumItemId,
});

/// REP-01（通報）の状態
class ReportState {
  const ReportState({this.reason, this.detail = '', this.alsoBlock = false, this.submitting = false});

  /// 選んだ理由
  /// 未選択ならnull（送信できない）
  final ReportReason? reason;

  /// 詳しい内容（任意）
  final String detail;

  /// 通報と同時に相手をブロックするか
  final bool alsoBlock;

  /// 送信中か（二重送信の防止）
  final bool submitting;

  /// 送信できるか
  bool get canSubmit => reason != null && !submitting;

  /// 指定した項目だけを変えた、新しい状態を作る
  ReportState copyWith({ReportReason? reason, String? detail, bool? alsoBlock, bool? submitting}) {
    return ReportState(
      reason: reason ?? this.reason,
      detail: detail ?? this.detail,
      alsoBlock: alsoBlock ?? this.alsoBlock,
      submitting: submitting ?? this.submitting,
    );
  }
}

// ============================================================
// ViewModel
// ============================================================

/// REP-01（通報）のViewModel
/// 理由・詳しい内容・同時にブロックするかを受け取り、通報を記録する（必要ならブロックもする）
///
/// 機能仕様書：4.3.6 / 画面設計書：5.9.1
class ReportViewModel extends Notifier<ReportState> {
  ReportViewModel(this.args);

  // ---- 状態・初期化 ----

  /// 自分と通報する相手（メッセージから通報した場合はそのメッセージ）
  final ReportArgs args;

  /// 最初の状態を作る
  /// 理由は未選択、ブロックはしない状態から始める
  @override
  ReportState build() => const ReportState();

  // ---- 入力 ----

  /// 理由を選ぶ
  void selectReason(ReportReason reason) => state = state.copyWith(reason: reason);

  /// 詳しい内容を更新する
  void updateDetail(String detail) => state = state.copyWith(detail: detail);

  /// 同時にブロックするかを切り替える
  void setAlsoBlock(bool alsoBlock) => state = state.copyWith(alsoBlock: alsoBlock);

  // ---- 送信 ----

  /// 通報を記録し、選んでいれば相手をブロックする
  /// 結果を返す。理由が未選択・送信中なら何もせずnull
  Future<ReportOutcome?> submit() async {
    final reason = state.reason;
    if (reason == null || state.submitting) return null;
    state = state.copyWith(submitting: true);

    try {
      final albumId = args.albumId;
      final albumItemId = args.albumItemId;
      if (albumId != null && albumItemId != null) {
        await ref
            .read(albumRepositoryProvider)
            .reportItem(
              chatRoomId: args.chatRoomId!,
              albumId: albumId,
              itemId: albumItemId,
              reporterAccountId: args.myAccountId,
              targetAccountId: args.targetAccountId!,
              reason: reason,
              detail: state.detail.trim(),
            );
      } else {
        await ref
            .read(reportRepositoryProvider)
            .report(
              reporterAccountId: args.myAccountId,
              targetAccountId: args.targetAccountId,
              reason: reason,
              detail: state.detail.trim(),
              messageId: args.messageId,
              chatRoomId: args.chatRoomId,
            );
      }
    } catch (_) {
      if (ref.mounted) state = state.copyWith(submitting: false);
      return ReportOutcome.failed;
    }

    if (!state.alsoBlock) return ReportOutcome.reported;
    try {
      await ref
          .read(blockRepositoryProvider)
          .blockAccount(accountId: args.myAccountId, targetAccountId: args.targetAccountId!);
      return ReportOutcome.reportedAndBlocked;
    } catch (_) {
      return ReportOutcome.blockFailed;
    }
  }
}

// ============================================================
// Provider
// ============================================================

/// [ReportViewModel]のProvider
/// 引数は自分と通報する相手。誰も監視しなくなったら破棄される（autoDispose）
final reportViewModelProvider = NotifierProvider.autoDispose.family<ReportViewModel, ReportState, ReportArgs>(
  ReportViewModel.new,
);
