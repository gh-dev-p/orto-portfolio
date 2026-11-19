import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/error_retry_view.dart';
import '../../../l10n/app_localizations.dart';
import '../view_models/chat_list_viewmodel.dart';
import 'chat_room_list.dart';

// ============================================================
// 画面
// ============================================================

/// 画面CHA-01：トーク一覧の本文（機能仕様書4.4.1 / 画面設計書5.3.1）
/// ヘッダー・ボトムナビは[HomeShell]が持つため、本Widgetはタブの本文だけを描く
class ChatListBody extends ConsumerWidget {
  const ChatListBody({super.key});

  /// トーク一覧を描く
  /// 読み込み中・読み込みの失敗（再試行つき）も表示する（フィルタのタブ（全て／個人／グループ）はMVPでは置かない。グループ機能がスコープ外のため）
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatListViewModelProvider);

    return state.sections.when(
      data: (sections) => ChatRoomList(
        sections: sections,
        myAccountId: state.myAccountId,
        groupRequests: state.groupRequests,
        joinApplications: state.joinApplications,
      ),
      loading: () => const AppLoadingIndicator(),
      error: (error, _) => ErrorRetryView(
        message: AppLocalizations.of(context)!.chaListLoadError,
        onRetry: ref.read(chatListViewModelProvider.notifier).retry,
      ),
    );
  }
}
