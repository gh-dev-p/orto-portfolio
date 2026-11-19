import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/chat_room.dart';
import '../../../domain/models/report_reason.dart';
import '../../services/common/firestore_paths.dart';

// ============================================================
// リポジトリ
// ============================================================

/// 通報のリポジトリ
/// 通報（`reports`、データ設計書3.6）の作成を扱う。アプリからは作成だけを行い、読み取らない（作成するとサーバーが運営者へ通知し、運営者がコンソールで確認する）
class ReportRepository {
  ReportRepository(this._paths);

  // ---- 状態・初期化 ----

  /// Firestoreのパス（接続先）
  final FirestorePaths _paths;

  // ---- 通報 ----

  /// アカウント[reporterAccountId]から、相手[targetAccountId]を通報する
  /// メッセージから通報した場合は、そのメッセージ[messageId]と、チャットルームのIDも記録する。[detail]は空なら記録しない
  /// アルバムの項目から通報した場合は、[chatRoomId]と、項目の[albumId]・[albumItemId]も記録する（項目のファイルはCloud Functionsが保全する）
  /// グループでは[chatRoomId]を渡す。[targetAccountId]がnullならグループを対象にした通報になる（機能仕様書4.7.6）
  Future<void> report({
    required String reporterAccountId,
    required String? targetAccountId,
    required ReportReason reason,
    String? detail,
    String? messageId,
    String? chatRoomId,
    String? albumId,
    String? albumItemId,
  }) {
    final ref = _paths.reports.doc();
    return ref.set({
      'reportId': ref.id,
      'reporterAccountId': reporterAccountId,
      'targetAccountId': ?targetAccountId,
      if (targetAccountId == null) 'targetChatRoomId': chatRoomId,
      'reason': reason.value,
      if (detail != null && detail.isNotEmpty) 'detail': detail,
      if (messageId != null) ...{
        'chatRoomId': chatRoomId ?? buildChatRoomId(reporterAccountId, targetAccountId!),
        'messageId': messageId,
      },
      if (albumItemId != null) ...{'chatRoomId': chatRoomId, 'albumId': albumId, 'albumItemId': albumItemId},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
