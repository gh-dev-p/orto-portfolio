import 'package:flutter/material.dart';

import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/empty_state_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/chat_list_sections.dart';
import '../../../domain/models/group.dart';
import '../../group/widgets/group_request_section.dart';
import '../../group/widgets/join_application_section.dart';
import 'request_section.dart';
import 'room_tile_loader.dart';

// ============================================================
// 画面の部品
// ============================================================

/// トークの一覧
/// 先頭に「未確認のトークリクエスト」（1件以上あるときだけ）、続けて通常のトークを並べる（画面設計書5.3.1）
class ChatRoomList extends StatelessWidget {
  const ChatRoomList({
    super.key,
    required this.sections,
    required this.myAccountId,
    this.groupRequests = const [],
    this.joinApplications = const [],
  });

  /// 表示区分ごとのトーク
  final ChatListSections sections;

  /// 届いているグループへの招待（1件以上あるときだけ先頭に出す。機能仕様書4.7.2.2）
  final List<GroupRequest> groupRequests;

  /// オフ会グループに出した参加の申請（1件以上あるときだけ、招待の下に出す。機能仕様書4.7.8.5）
  final List<JoinApplication> joinApplications;

  /// 使用中のアカウントID
  /// 取得前ならnull（読み込み中として表示する）
  final String? myAccountId;

  /// 一覧を描く
  /// トークが1件もなければ空の表示を出す
  @override
  Widget build(BuildContext context) {
    if (myAccountId == null) {
      return const AppLoadingIndicator();
    }
    final hasRequests = sections.requests.isNotEmpty;
    final hasGroupRequests = groupRequests.isNotEmpty;
    final hasJoinApplications = joinApplications.isNotEmpty;
    if (sections.normal.isEmpty && !hasRequests && !hasGroupRequests && !hasJoinApplications) {
      return EmptyStateView(message: AppLocalizations.of(context)!.chaListEmpty);
    }

    final headers = [
      if (hasGroupRequests) GroupRequestSection(requests: groupRequests, myAccountId: myAccountId!),
      if (hasJoinApplications) JoinApplicationSection(applications: joinApplications, myAccountId: myAccountId!),
      if (hasRequests) RequestSection(rooms: sections.requests, myAccountId: myAccountId!),
    ];
    final headerCount = headers.length;
    return ListView.builder(
      itemCount: headerCount + sections.normal.length,
      itemBuilder: (context, index) {
        if (index < headerCount) return headers[index];
        return RoomTileLoader(room: sections.normal[index - headerCount], myAccountId: myAccountId!);
      },
    );
  }
}
