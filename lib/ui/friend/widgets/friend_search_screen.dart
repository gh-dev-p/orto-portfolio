import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/inline_spinner.dart';
import '../../core/ui/field_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/account.dart';
import '../view_models/friend_search_viewmodel.dart';
import '../../profile/widgets/friend_profile_screen.dart';

// ============================================================
// 画面
// ============================================================

/// 画面FRI-04：友だち検索
/// アカウントIDの完全一致で検索し、結果を表示するだけ（追加の確定はPRO-01で行う。結果のタップでPRO-01を開く）。FRI-02から開く
///
/// 機能仕様書：4.3.1 / 画面設計書：5.4.4
class FriendSearchScreen extends ConsumerStatefulWidget {
  const FriendSearchScreen({super.key, required this.myAccountId});

  final String myAccountId;

  @override
  ConsumerState<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends ConsumerState<FriendSearchScreen> {
  // ---- 状態・初期化 ----

  /// アカウントIDの入力欄
  final _idController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  // ---- 操作 ----

  /// 検索できる入力か（空白だけでない）
  bool get _isValid => _idController.text.trim().isNotEmpty;

  /// 入力したアカウントIDで検索する
  /// 検索ボタン・キーボードの確定から呼ぶ
  Future<void> _search() async {
    await ref
        .read(friendSearchViewModelProvider.notifier)
        .search(id: _idController.text.trim(), myAccountId: widget.myAccountId);
  }

  // ---- 画面 ----

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendSearchViewModelProvider);
    final searching = state.isLoading;
    final errorCode = state.hasError ? state.error as FriendSearchError : null;
    final result = state.value;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.friSearchTitle),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              FieldLabel(l10n.commonAccountIdLabel),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _idController,
                      decoration: InputDecoration(hintText: l10n.commonAccountIdHint),
                      onChanged: (_) {
                        ref.read(friendSearchViewModelProvider.notifier).reset();
                        setState(() {});
                      },
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isValid && !searching ? _search : null,
                    child: searching ? const InlineSpinner() : Text(l10n.commonSearch),
                  ),
                ],
              ),
              if (errorCode != null) ...[
                const SizedBox(height: 8),
                Text(
                  switch (errorCode) {
                    FriendSearchError.selfAdd => l10n.commonSelfAddNotAllowed,
                    FriendSearchError.searchFailed => l10n.friSearchFailed,
                    FriendSearchError.notFound => l10n.friSearchNotFound,
                  },
                  style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
                ),
              ],
              const SizedBox(height: 24),
              if (result != null) _SearchResultTile(peer: result, myAccountId: widget.myAccountId),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// 検索結果の1行
/// タップでPRO-01（相手のプロフィール）を開く
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.peer, required this.myAccountId});

  final Account peer;
  final String myAccountId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FriendProfileScreen(accountId: peer.id, myAccountId: myAccountId),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            AppAvatar(displayName: peer.displayName, photoURL: peer.photoURL, size: 48),
            const SizedBox(width: 16),
            Expanded(child: Text(peer.displayName, style: context.textStyles.titleMedium)),
            Icon(Icons.chevron_right, color: context.colors.secondaryText),
          ],
        ),
      ),
    );
  }
}
