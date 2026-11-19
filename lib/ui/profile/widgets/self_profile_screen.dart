import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/ui/header_icon_button.dart';
import '../view_models/self_profile_viewmodel.dart';
import 'profile_edit_screen.dart';
import 'profile_layout.dart';

// ============================================================
// 画面
// ============================================================

/// 画面PRO-02：自分のプロフィール
/// 使用中のアカウントの背景・アバター・表示名・ひとことを表示し、右上から編集（PRO-03）を開く
///
/// アカウントIDは表示しない（IDの共有・コピーはPRO-03のIDの行にまとめる）
///
/// 機能仕様書：4.5.1 / 画面設計書：5.7.2
class SelfProfileScreen extends ConsumerWidget {
  const SelfProfileScreen({super.key});

  /// プロフィールを描く
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(selfProfileViewModelProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: ProfileLayout(
        backgroundURL: account?.backgroundURL,
        topBar: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 左上は「閉じる」（右上は編集のため）。挙動はpopのまま。
            HeaderIconButton(icon: Icons.close, onTap: () => Navigator.of(context).pop()),
            if (account != null)
              HeaderIconButton(
                icon: Icons.edit,
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileEditScreen(accountId: account.id))),
              ),
          ],
        ),
        center: account == null
            ? null
            : ProfileSummary(displayName: account.displayName, photoURL: account.photoURL, bio: account.bio),
      ),
    );
  }
}
