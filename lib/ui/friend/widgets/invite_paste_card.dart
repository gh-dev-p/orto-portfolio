import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../group/view_models/group_invite_providers.dart';
import '../view_models/invite_link_provider.dart';

// ============================================================
// 部品
// ============================================================

/// 招待の貼り付けボタンの案内（AUT-02、機能仕様書4.3.5.2）
/// 案内ページで招待リンクをコピーしてからアプリを入れた人が、招待を引き継ぐためのもの
/// クリップボードにURLがありそうなとき（[InvitePasteStatus.offered]）だけ出す
class InvitePasteCard extends ConsumerWidget {
  const InvitePasteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(invitePasteProvider);
    if (status == InvitePasteStatus.hidden) return const SizedBox.shrink();
    final pendingAccountId = ref.watch(pendingInviteProvider);
    final pendingGroup = ref.watch(pendingGroupInviteProvider) != null;
    // 招待リンクで開いた後は、貼り付けは要らない。
    if (status != InvitePasteStatus.received && (pendingAccountId != null || pendingGroup)) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final restorer = ref.read(inviteClipboardRestorerProvider);
    final received = status == InvitePasteStatus.received;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      // 余白は上下左右とも16にそろえる。×は右上の角に寄せ、見出しの行と高さをそろえる
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (received) ...[
                Icon(Icons.check_circle, size: 20, color: context.colors.accent),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  received ? l10n.invitePasteReceivedTitle : l10n.invitePasteTitle,
                  style: context.textStyles.titleBold,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: _closeSize,
                child: IconButton(
                  tooltip: l10n.invitePasteClose,
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: Icon(Icons.close, color: context.colors.secondaryText),
                  onPressed: restorer.dismiss,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            switch ((received, pendingAccountId)) {
              (true, final String accountId) => l10n.invitePasteReceivedFriend(accountId),
              (true, _) => l10n.invitePasteReceivedGroup,
              _ => l10n.invitePasteMessage,
            },
            style: context.textStyles.description,
          ),
          if (!received) ...[
            const SizedBox(height: 16),
            const InvitePasteButton(),
            if (status == InvitePasteStatus.notInvite) ...[
              const SizedBox(height: 8),
              Text(
                l10n.invitePasteNotInvite,
                textAlign: TextAlign.center,
                style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// 閉じるボタン（×）の大きさ。見出しの行の高さに収める
  static const double _closeSize = 32;
}

/// 貼り付けボタンの背景色と文字色
/// 背景は画面のほかのボタン（[AppPrimaryButton]）と同じアクセントの色。文字は、ライトでは白、
/// ダークでは淡いアクセントの上で白が読みにくいため、画面の背景の暗い色にする
({Color background, Color foreground}) invitePasteButtonColors(AppColors colors, Brightness brightness) => (
  background: colors.accent,
  foreground: brightness == Brightness.dark ? colors.background : colors.onAccent,
);

/// システムの貼り付けボタン（iOSのUIPasteControl、InvitePasteButton.swift）
/// 押されたときだけ本文が渡るため、iOSの貼り付けの確認が出ない。受け取った本文は[InviteClipboardService.pasted]に届く
class InvitePasteButton extends StatelessWidget {
  const InvitePasteButton({super.key});

  /// ネイティブ側の部品の名前（AppDelegate.swiftと揃える）
  static const viewType = 'com.example.orto/invite_paste_button';

  /// ボタンの高さ（[AppPrimaryButton]と同じ）
  static const double _height = 48;

  @override
  Widget build(BuildContext context) {
    // iOS以外では[InvitePasteStatus.offered]にならないため、出さない。
    if (defaultTargetPlatform != TargetPlatform.iOS) return const SizedBox.shrink();
    final colors = invitePasteButtonColors(context.colors, Theme.of(context).brightness);
    // 画面のほかのボタンと同じ高さ48・カードの幅いっぱい（UIPasteControlのcapsuleで角丸は高さの半分になる）
    return SizedBox(
      height: _height,
      child: UiKitView(
        // 色は作るときにだけ渡すため、ライト・ダークが切り替わったら作り直す
        key: ValueKey(colors),
        viewType: viewType,
        creationParams: {
          'background': colors.background.toARGB32(),
          'foreground': colors.foreground.toARGB32(),
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
