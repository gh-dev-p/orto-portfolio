import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';
import 'app_avatar.dart';
import 'count_badge.dart';

/// ヘッダー、追加メニューの左右の余白
const _horizontalPadding = 16.0;

/// アイコンのサイズ
const _iconSize = 28.0;

/// アバターサイズ（アイコンに比べ領域いっぱいに表示されるため、実機確認の上で調整）
const _avatarSize = _iconSize * 0.9;

/// ホーム画面共通ヘッダー（CHA-01・FRI-01、画面設計書5.8.1）。
///
/// タイトル以外の要素（＋／QR／アバターの3アイコン）はタブの状態に依らず、常時表示。
/// 実際の画面遷移・モーダル表示とアバター・未読数の取得は、[AppBottomNav]と同じ設計方針に倣い
/// 呼び出し元に委譲する（共通Widget（`lib/ui/core/ui/`）は各機能に依存させないため、
/// 各機能の画面やview_models/配下のProviderを本Widgetから直接importしない）。
class AppHomeHeader extends StatelessWidget {
  const AppHomeHeader({
    super.key,
    required this.title,
    required this.avatarDisplayName,
    required this.avatarPhotoURL,
    required this.otherAccountsUnread,
    required this.otherAccountsHaveGroupRequest,
    required this.onAdd,
    required this.onInvite,
    required this.onCreateGroup,
    required this.onTapQr,
    required this.onTapAvatar,
  });

  final String title;

  /// アクティブなAccountの表示名・画像。表示名がnullの場合（アクティブなAccountが無い）は
  /// アバターを表示しない。
  final String? avatarDisplayName;
  final String? avatarPhotoURL;

  /// アクティブなAccount以外の全Accountの未読合計。0の場合はバッジを表示しない。
  final int otherAccountsUnread;

  /// アクティブなAccount以外のどれかにグループへの招待が届いているか。trueなら未読合計に代えて「!」を表示する。
  final bool otherAccountsHaveGroupRequest;

  /// ＋メニューの「友だち追加」選択時。nullの場合はアクティブなAccountが無いと
  /// みなし、「友だち追加」項目を無効化する。
  final VoidCallback? onAdd;

  /// ＋メニューの「招待」選択時。[onAdd]と同じく、nullの場合は項目を無効化する。
  final VoidCallback? onInvite;

  /// ＋メニューの「グループ作成」選択時。[onAdd]と同じく、nullの場合は項目を無効化する。
  final VoidCallback? onCreateGroup;
  final VoidCallback onTapQr;
  final VoidCallback onTapAvatar;

  @override
  Widget build(BuildContext context) {
    final avatarDisplayName = this.avatarDisplayName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(_horizontalPadding, 16, _horizontalPadding, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: context.textStyles.h1),
          IconTheme(
            data: IconThemeData(size: _iconSize, color: context.colors.primaryText),
            child: Row(
              children: [
                // 追加アイコン
                _AddMenuButton(onAdd: onAdd, onInvite: onInvite, onCreateGroup: onCreateGroup),

                const SizedBox(width: 12),

                // QRアイコン
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTapQr,
                  child: const Icon(Icons.qr_code_2_outlined),
                ),

                const SizedBox(width: 12),

                // アカウントアバター（アクティブアカウントを除く他アカウントの未読合計バッジ）
                // アクティブなAccountが無い（アバターが空欄の）ときも、その位置のタップでACC-01を開ける
                // （画面設計書5.8.1.3）。中身の無い領域もタップを受けるよう、opaqueにする。
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTapAvatar,
                  child: avatarDisplayName == null
                      ? const SizedBox.square(dimension: _avatarSize)
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AppAvatar(displayName: avatarDisplayName, photoURL: avatarPhotoURL, size: _avatarSize),
                            // 未読バッジ（アクティブアカウントを除くすべてのアカウントの未読数を合算表示。招待があれば「!」）
                            if (otherAccountsUnread > 0 || otherAccountsHaveGroupRequest)
                              Positioned(
                                right: -6,
                                top: -4,
                                child: CountBadge(count: otherAccountsUnread, attention: otherAccountsHaveGroupRequest),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//ポップアップメニュー
/// 追加アイコンタップでボタン直下に半透明オーバーレイ付きのポップアップメニューを表示
/// メニュー外タップでdismiss
class _AddMenuButton extends StatefulWidget {
  const _AddMenuButton({required this.onAdd, required this.onInvite, required this.onCreateGroup});

  final VoidCallback? onAdd;
  final VoidCallback? onInvite;
  final VoidCallback? onCreateGroup;

  @override
  State<_AddMenuButton> createState() => _AddMenuButtonState();
}

enum _AddMenuAction { addFriend, createGroup, invite }

class _AddMenuButtonState extends State<_AddMenuButton> {
  final _buttonKey = GlobalKey();

  Future<void> _openMenu() async {
    final renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final buttonTopLeft = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    final action = await showGeneralDialog<_AddMenuAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dialogContext, _, _) {
        return Stack(
          children: [
            Positioned(
              top: buttonTopLeft.dy + buttonSize.height + 8,
              right: _horizontalPadding,
              child: _AddMenuCard(
                canAddFriend: widget.onAdd != null,
                canInvite: widget.onInvite != null,
                canCreateGroup: widget.onCreateGroup != null,
                onSelect: (action) => Navigator.of(dialogContext).pop(action),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    switch (action) {
      case _AddMenuAction.addFriend:
        widget.onAdd?.call();
      case _AddMenuAction.createGroup:
        widget.onCreateGroup?.call();
      case _AddMenuAction.invite:
        widget.onInvite?.call();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: _buttonKey,
      customBorder: const CircleBorder(),
      onTap: _openMenu,
      child: const Icon(Icons.add_circle_outline),
    );
  }
}

/// 追加メニューのカード
///
/// 白カードにアイコン＋ラベル縦積みの項目（「友だち追加」「グループ作成」「招待」（FRI-03））を横並び（gap 24）で配置する。
/// 旧Figmaデザインの「トークルーム作成」は未設計のため置いていない。
/// 高さはFigma上は60だが、日本語ラベルは実機フォントで折り返されると60に収まらない
/// ことがあるため、固定せずコンテンツに応じて決まる高さにしている。
class _AddMenuCard extends StatelessWidget {
  const _AddMenuCard({
    required this.canAddFriend,
    required this.canInvite,
    required this.canCreateGroup,
    required this.onSelect,
  });

  final bool canAddFriend;
  final bool canInvite;
  final bool canCreateGroup;
  final ValueChanged<_AddMenuAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: context.colors.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AddMenuItem(
              width: 64,
              icon: Icons.person_outline,
              iconSize: 24,
              label: l10n.addMenuAddFriendLabel,
              onTap: canAddFriend ? () => onSelect(_AddMenuAction.addFriend) : null,
            ),
            const SizedBox(width: 24),
            _AddMenuItem(
              width: 64,
              icon: Icons.group_add_outlined,
              iconSize: 24,
              label: l10n.addMenuCreateGroupLabel,
              onTap: canCreateGroup ? () => onSelect(_AddMenuAction.createGroup) : null,
            ),
            const SizedBox(width: 24),
            _AddMenuItem(
              width: 64,
              icon: Icons.mail_outline,
              iconSize: 24,
              label: l10n.addMenuInvite,
              onTap: canInvite ? () => onSelect(_AddMenuAction.invite) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMenuItem extends StatelessWidget {
  const _AddMenuItem({
    required this.width,
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final double iconSize;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 20,
              child: Center(
                child: Icon(icon, size: iconSize, color: context.colors.primaryText),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: context.textStyles.addMenuItemLabel),
          ],
        ),
      ),
    );
  }
}
