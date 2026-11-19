import 'package:flutter/material.dart';

import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/background_image.dart';

/// プロフィールの画面（PRO-01・PRO-02）の土台
/// 背景画像に下側を暗くするグラデーションを重ね、上端に[topBar]（閉じる・編集等のボタン）、中央に[center]、下端に[bottom]を置く
///
/// [center]・[bottom]は、アカウントを取得できるまでnullにする（背景とボタンだけを表示する）
class ProfileLayout extends StatelessWidget {
  const ProfileLayout({super.key, required this.backgroundURL, required this.topBar, this.center, this.bottom});

  final String? backgroundURL;
  final Widget topBar;
  final Widget? center;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final center = this.center;
    final bottom = this.bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        BackgroundImage(url: backgroundURL),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black45],
              stops: [0.4, 1.0],
            ),
          ),
        ),
        // Stack(fit: StackFit.expand)配下のため、Alignで包まないとフルサイズのtight制約が伝播し、
        // ボタンが画面中央に描画されてしまう。
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: topBar),
          ),
        ),
        // 画面の実際の中央に置く（2026-09-03、実機確認により修正。旧Alignment(0, 0.4)は「余白の70%の位置」
        // という意味になり、見た目上の中央よりかなり下寄りに表示されていた）。
        if (center != null) Align(alignment: Alignment.center, child: center),
        if (bottom != null)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(padding: const EdgeInsets.only(bottom: 24), child: bottom),
            ),
          ),
      ],
    );
  }
}

/// プロフィールの中央の表示
/// 白い縁取りのアバター・表示名（右に[nameTrailing]）・ひとこと（[bio]があるときだけ）と、その下の[actions]（トーク・友だち追加等）
class ProfileSummary extends StatelessWidget {
  const ProfileSummary({
    super.key,
    required this.displayName,
    required this.photoURL,
    this.nameTrailing,
    this.bio,
    this.actions,
  });

  final String displayName;
  final String? photoURL;
  final Widget? nameTrailing;
  final String? bio;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final bio = this.bio;
    final nameTrailing = this.nameTrailing;
    final actions = this.actions;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: AppAvatar(displayName: displayName, photoURL: photoURL, size: 82),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayName,
              style: context.textStyles.h1.copyWith(color: Colors.white, fontSize: 20),
            ),
            if (nameTrailing != null) ...[const SizedBox(width: 6), nameTrailing],
          ],
        ),
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
            ),
          ),
        ],
        if (actions != null) ...[const SizedBox(height: 24), actions],
      ],
    );
  }
}
