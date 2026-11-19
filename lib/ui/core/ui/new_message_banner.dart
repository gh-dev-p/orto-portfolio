import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../themes/app_colors.dart';

/// アプリを開いているときに新着を受信したことを知らせるアプリ内バナー（機能仕様書4.4.6.2）を出す。
/// リアクションの通知（[isReaction]）・グループへの招待の通知（[isGroupInvite]）・
/// 主催チームへの誘いの通知（[isOrganizerInvite]、機能仕様書4.7.8.2）・お知らせの通知（[isAnnouncement]、4.7.8.4）・
/// 友だち申請の通知（[isFriendRequest]、機能仕様書4.3.8.2）・参加の申請の通知（[isJoinRequest]）・
/// 申請の結果の通知（[joinResult]と[groupName]、4.7.8.5）・キャンセル待ちの繰り上げ（[joinResult]が承認待ち・
/// [isWaitlistPromoted]、4.7.8.10）・出欠の催促（[isAttendanceReminder]、4.7.8.9）・精算の催促（[isSettlementReminder]、
/// 4.7.8.12）では文言を変える。
/// [onTap]はバナーをタップしたときの処理（通知先を開く。開く先が無い通知ではnullで、タップしても閉じるだけ）。
/// 表示中に呼ぶと、重ねずに新しい内容へ差し替える。
void showNewMessageBanner(
  BuildContext context, {
  bool isReaction = false,
  bool isGroupInvite = false,
  bool isOrganizerInvite = false,
  bool isFriendRequest = false,
  bool isAnnouncement = false,
  bool isJoinRequest = false,
  bool isWaitlistPromoted = false,
  bool isAttendanceReminder = false,
  bool isSettlementReminder = false,
  int? closingHoursLeft,
  JoinStatus? joinResult,
  String? groupName,
  VoidCallback? onTap,
}) {
  final l10n = AppLocalizations.of(context)!;
  final name = groupName ?? '';
  final message =
      switch (joinResult) {
        JoinStatus.approved => l10n.pushJoinApprovedBanner(name),
        JoinStatus.waitlisted => l10n.pushJoinWaitlistedBanner(name),
        JoinStatus.declined => l10n.grpApplyDeclined(name),
        JoinStatus.closed => l10n.grpApplyClosed(name),
        JoinStatus.pending => l10n.pushJoinPromotedBanner(name),
        null => null,
      } ??
      (isWaitlistPromoted ? l10n.pushWaitlistPromotedBanner : null) ??
      (isJoinRequest ? l10n.pushJoinRequestBanner : null) ??
      (isAttendanceReminder ? l10n.pushAttendanceReminderBanner : null) ??
      (isSettlementReminder ? l10n.pushSettlementReminderBanner : null) ??
      // オフ会グループの閉じる前の知らせ（機能仕様書4.7.8.7）
      switch (closingHoursLeft) {
        1 => l10n.pushGroupClosing1hBanner(name),
        null => null,
        _ => l10n.pushGroupClosing24hBanner(name),
      } ??
      (isFriendRequest
          ? l10n.pushFriendRequestBanner
          : isGroupInvite
          ? l10n.pushGroupInviteBanner
          : isOrganizerInvite
          ? l10n.pushOrganizerInviteBanner
          : isAnnouncement
          ? l10n.pushAnnouncementBanner
          : isReaction
          ? l10n.pushReactionBanner
          : l10n.pushNewMessageBanner);
  context.findAncestorStateOfType<_NewMessageBannerHostState>()?._show(message, onTap);
}

/// アプリ内バナーの表示先。`MaterialApp.builder`から全画面共通で適用し、[child]の上に重ねて出す。
/// Navigatorの外側に置くため、ダイアログやバナーを出した後に開いた画面の裏に隠れない。
class NewMessageBannerHost extends StatefulWidget {
  const NewMessageBannerHost({super.key, required this.child});

  final Widget child;

  @override
  State<NewMessageBannerHost> createState() => _NewMessageBannerHostState();
}

class _NewMessageBannerHostState extends State<NewMessageBannerHost> with SingleTickerProviderStateMixin {
  /// 自動的に閉じるまでの時間。
  static const _displayDuration = Duration(seconds: 4);
  static const _slideInDuration = Duration(milliseconds: 450);
  static const _slideOutDuration = Duration(milliseconds: 250);

  /// 指を離したときに閉じる、上向きの速さ（dp/秒）。
  static const _flingVelocity = 300.0;

  /// 指を離したときに閉じる、バナーの高さに対する引き上げた割合。
  static const _dismissFraction = 0.35;

  /// バナーの縦の位置。表示位置が0、上に隠れた位置が-1で、単位はバナー（上の余白を含む）の高さ。
  late final _position = AnimationController(vsync: this, lowerBound: -1, upperBound: 0, value: -1);

  /// バナー（上の余白を含む）の高さを測るためのキー。
  final _bannerKey = GlobalKey();

  /// 表示中の文言とタップ時の処理（何も出していなければnull）。
  ({String message, VoidCallback? onTap})? _content;
  Timer? _dismissTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 最初のバナーで、アイコンだけ遅れて表示されないようにする。
    precacheImage(_BannerCard.icon, context);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _position.dispose();
    super.dispose();
  }

  void _show(String message, VoidCallback? onTap) {
    setState(() => _content = (message: message, onTap: onTap));
    _slideIn();
  }

  /// 表示位置まで動かし、一定時間後に閉じる予約をする（予約済みなら数え直す）。
  void _slideIn() {
    _position.animateTo(0, duration: _slideInDuration, curve: Curves.linearToEaseOut);
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_displayDuration, _dismiss);
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    // 閉じる途中で次の新着や指で止められた場合は、完了しないため消さない。
    _position.animateTo(-1, duration: _slideOutDuration, curve: Curves.easeInToLinear).then((_) {
      if (mounted) setState(() => _content = null);
    });
  }

  void _onTap() {
    _content?.onTap?.call();
    _dismiss();
  }

  /// 指で動かしている間は閉じる予約を止める。
  void _onDragStart(DragStartDetails _) {
    _dismissTimer?.cancel();
    _position.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _position.value += details.primaryDelta! / _bannerKey.currentContext!.size!.height;
  }

  void _onDragEnd(DragEndDetails details) {
    if (details.primaryVelocity! < -_flingVelocity || _position.value < -_dismissFraction) {
      _dismiss();
    } else {
      _slideIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (content != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _position,
              builder: (_, child) => FractionalTranslation(translation: Offset(0, _position.value), child: child),
              child: SafeArea(
                key: _bannerKey,
                bottom: false,
                minimum: const EdgeInsets.symmetric(horizontal: 8),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _onTap,
                        onVerticalDragStart: _onDragStart,
                        onVerticalDragUpdate: _onDragUpdate,
                        onVerticalDragEnd: _onDragEnd,
                        onVerticalDragCancel: _slideIn,
                        child: _BannerCard(message: content.message),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// iOSの通知に合わせた見た目のカード
/// 通知は送信者・宛先アカウント名・内容を含めない固定の文言のため、タイトルは送信者名ではなくアプリ名にする
class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.message});

  final String message;

  /// 元画像が大きいため、表示に足りる大きさで読み込む。
  static const icon = ResizeImage(AssetImage('assets/icon/app_icon.png'), width: 120);

  /// ダークモードの[AppColors.surface]はヘッダーと同じ色で見分けにくいため、iOSの通知に近い明るめのグレーにする。
  static const _darkTint = Color(0xFF3A3A3C);

  static const _iconSize = 38.0;
  static const _shape = RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(24)));
  static const _clipRadius = BorderRadius.all(Radius.circular(24));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          shape: _shape,
          shadows: [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 6))],
        ),
        child: ClipRSuperellipse(
          borderRadius: _clipRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: ColoredBox(
              color: (Theme.of(context).brightness == Brightness.dark ? _darkTint : colors.surface).withValues(
                alpha: 0.75,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    ClipRSuperellipse(
                      borderRadius: const BorderRadius.all(Radius.circular(9)),
                      child: const Image(image: icon, width: _iconSize, height: _iconSize),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      // Navigatorの外側にはMaterialが無く、既定の文字のスタイルが効かない。
                      child: DefaultTextStyle(
                        style: TextStyle(fontSize: 15, height: 1.25, color: colors.primaryText),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Orto',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
