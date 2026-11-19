import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'message_action.dart';
import 'message_actions_menu.dart';
import 'reaction_picker_row.dart';

/// メッセージの長押しメニュー（画面設計書5.3.2.3）を長押しした位置（[globalPosition]）の近くに出し、選ばれた操作を返す
/// 外側のタップで閉じたらnull。相手のメッセージ（[isMine]がfalse）ではリアクションの行を上に出し、画像メッセージ（[isImage]）には「コピー」「部分コピー」が無い
///
/// ボトムシートではなく、LINE・iOS風のコンテキストメニューとして重ねる。下に余白があれば直下、無ければ上側に出し、画面端にはみ出さないよう位置を補正する
Future<MessageAction?> showMessageActionsPopup(
  BuildContext context, {
  required bool isMine,
  required bool isImage,
  required Offset globalPosition,
  bool canAnnounce = false,
  bool isClosedRoom = false,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<MessageAction?>();
  late OverlayEntry entry;

  void close(MessageAction? result) {
    if (entry.mounted) entry.remove();
    if (!completer.isCompleted) completer.complete(result);
  }

  final l10n = AppLocalizations.of(context)!;
  final mediaQuery = MediaQuery.of(context);
  final screenSize = mediaQuery.size;

  // AppHomeHeaderの＋メニューと同じ横並びアイコン＋ラベル項目の
  // レイアウトを採用するため、項目数に応じて幅を決める。画像メッセージには
  // 「コピー」「部分コピー」が無い。最後の1項目は、自分のメッセージなら「送信取消」、相手のメッセージなら「通報」。
  // オフ会グループの主催チームには、テキストのメッセージの先頭に「お知らせにする」を足す。
  // 閉じたオフ会グループ（機能仕様書4.7.8.6）では、リアクションと送信取消を出さない。
  final canReact = !isMine && !isClosedRoom;
  final canUnsend = isMine && !isClosedRoom;
  final itemCount = (canAnnounce ? 1 : 0) + (isImage ? 0 : 2) + 1 + (isMine && !canUnsend ? 0 : 1);
  final menuWidth = switch (itemCount) {
    5 => 320.0,
    4 => 260.0,
    3 => 240.0,
    2 => 170.0,
    _ => 110.0,
  };
  // リアクション行（LINE準拠）：
  // 白カードの中に収めず、ポップアップ上部に背景透過の状態で独立して表示する。
  const reactionRowHeight = 56.0;
  const reactionGap = 10.0;
  const actionsCardHeight = 76.0; // アイコン(20)＋ラベル最大2行＋カード上下パディング分の目安
  final estimatedHeight = (canReact ? reactionRowHeight + reactionGap : 0.0) + actionsCardHeight;

  var left = globalPosition.dx - menuWidth / 2;
  left = left.clamp(12.0, (screenSize.width - menuWidth - 12.0).clamp(12.0, double.infinity));

  final spaceBelow = screenSize.height - mediaQuery.padding.bottom - 12 - (globalPosition.dy + 16);
  final double top;
  if (spaceBelow >= estimatedHeight) {
    top = globalPosition.dy + 16;
  } else {
    final topAbove = globalPosition.dy - 16 - estimatedHeight;
    top = topAbove < mediaQuery.padding.top + 12 ? mediaQuery.padding.top + 12 : topAbove;
  }
  final actionsCardTop = canReact ? top + reactionRowHeight + reactionGap : top;

  entry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => close(null),
            child: Container(color: Colors.black.withValues(alpha: 0.15)),
          ),
        ),
        if (canReact)
          // 絵文字6個分の実際の幅はフォント・端末により変動し、menuWidthに収まりきらず
          // RenderFlexオーバーフローになることがあったため、幅は強制せず内容に応じて
          // 自然に収縮させる（`ReactionPickerRow`側もmainAxisSize.min）。
          Positioned(
            left: left,
            top: top,
            child: ReactionPickerRow(onSelect: (emoji) => close(MessageAction.react(emoji))),
          ),
        Positioned(
          left: left,
          top: actionsCardTop,
          width: menuWidth,
          child: MessageActionsMenu(
            isMine: isMine,
            isImage: isImage,
            canAnnounce: canAnnounce,
            canUnsend: !isClosedRoom,
            l10n: l10n,
            onSelect: close,
          ),
        ),
      ],
    ),
  );

  overlay.insert(entry);
  return completer.future;
}

/// リアクションの絵文字だけを選ぶポップアップを、タップした位置（[globalPosition]）の近くに出し、選ばれた絵文字を返す
/// 吹き出しの下のリアクションのタップで、付けたリアクションを変える・外すために使う。外側のタップで閉じたらnull
///
/// 位置の決め方は[showMessageActionsPopup]と同じ（下に余白があれば直下、無ければ上側。画面端にはみ出さないよう補正する）
Future<String?> showReactionPickerPopup(BuildContext context, {required Offset globalPosition}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<String?>();
  late OverlayEntry entry;

  void close(String? result) {
    if (entry.mounted) entry.remove();
    if (!completer.isCompleted) completer.complete(result);
  }

  final mediaQuery = MediaQuery.of(context);
  final screenSize = mediaQuery.size;

  // 絵文字6個分の幅の目安（実際の幅は内容に応じて収縮させる）。
  const rowWidth = 260.0;
  const rowHeight = 56.0;

  var left = globalPosition.dx - rowWidth / 2;
  left = left.clamp(12.0, (screenSize.width - rowWidth - 12.0).clamp(12.0, double.infinity));

  final spaceBelow = screenSize.height - mediaQuery.padding.bottom - 12 - (globalPosition.dy + 16);
  final double top;
  if (spaceBelow >= rowHeight) {
    top = globalPosition.dy + 16;
  } else {
    final topAbove = globalPosition.dy - 16 - rowHeight;
    top = topAbove < mediaQuery.padding.top + 12 ? mediaQuery.padding.top + 12 : topAbove;
  }

  entry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => close(null),
            child: Container(color: Colors.black.withValues(alpha: 0.15)),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: ReactionPickerRow(onSelect: close),
        ),
      ],
    ),
  );

  overlay.insert(entry);
  return completer.future;
}
