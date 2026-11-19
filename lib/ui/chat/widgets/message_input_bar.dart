import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/sticker_pack.dart';
import '../../core/themes/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'sticker_picker_panel.dart';

/// メッセージの入力欄（画面設計書5.3.2）
/// 画像ボタン・入力欄（内側の右端にスタンプボタン）・送信ボタンを横に並べる
/// スタンプの選択パネルは、キーボードと入れ替わる形で入力欄の下に開く
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    required this.controller,
    required this.sending,
    required this.maxLength,
    required this.onSend,
    required this.onPickImage,
    this.preparingImage = false,
    this.stickerPacks = const [],
    this.onSelectSticker,
  });

  final TextEditingController controller;
  final bool sending;
  final int maxLength;
  final VoidCallback onSend;

  /// 入力欄の左の画像ボタンのタップ時に呼ぶ
  final VoidCallback onPickImage;

  /// 選んだ画像を読み込み・縮小しているか
  /// trueの間は入力欄の上に読み込み中の表示を出し、画像ボタンを押せなくする
  final bool preparingImage;

  /// 選択パネルに出すスタンプ（機能仕様書4.4.8）
  /// 空ならスタンプボタンを出さない
  final List<StickerPack> stickerPacks;

  /// 選択パネルでスタンプをタップしたときに呼ぶ
  final ValueChanged<StickerSelection>? onSelectSticker;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> with WidgetsBindingObserver {
  /// 開閉のアニメーションの長さ（キーボードが動いていないとき）
  static const _panelDuration = Duration(milliseconds: 220);

  /// キーボードへ切り替えるときに、パネルを閉じるまでの待ち時間
  /// キーボードが上がりきってから閉じ、入力欄の位置が動かないようにする
  /// ハードウェアキーボードではキーボードが上がらないため、時間で閉じる
  static const _keyboardRiseDuration = Duration(milliseconds: 350);

  /// パネルの高さ
  /// 直前のキーボードの高さに合わせ、切り替えても入力欄の位置が動かないようにする
  static double _panelHeight = 336;

  final _focusNode = FocusNode();

  /// 選択パネルを開いているか
  bool _panelOpen = false;

  /// パネルの中身を出しているか（閉じるアニメーションの間も出す）
  bool _panelContentVisible = false;

  /// 画面下から測ったキーボードの高さ
  /// 親のScaffoldが体裁を調整するため、MediaQueryではなく画面の値を読む
  double _keyboardInset = 0;

  /// 入力欄の下の高さを変えるアニメーションの長さ
  /// キーボードが動くときは0にして、その動きとずれないようにする
  Duration _bottomDuration = Duration.zero;

  Timer? _closeTimer;

  bool get _hasStickers => widget.stickerPacks.isNotEmpty && widget.onSelectSticker != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keyboardInset = _readKeyboardInset();
  }

  @override
  void didChangeMetrics() {
    final inset = _readKeyboardInset();
    if (inset == _keyboardInset) return;
    setState(() {
      _keyboardInset = inset;
      _bottomDuration = Duration.zero;
    });
  }

  double _readKeyboardInset() {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  /// 入力欄を操作してキーボードへ切り替わるときは、キーボードが上がってからパネルを閉じる
  void _handleFocusChange() {
    if (!_focusNode.hasFocus || !_panelOpen) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(_keyboardRiseDuration, _closePanel);
  }

  void _closePanel() {
    _closeTimer?.cancel();
    if (!mounted || !_panelOpen) return;
    setState(() {
      _panelOpen = false;
      _bottomDuration = _panelAnimationDuration;
      // キーボードの裏では閉じるアニメーションが動かないため、すぐ片付ける。
      if (_keyboardInset > 0) _panelContentVisible = false;
    });
  }

  /// パネルの開閉のアニメーションの長さ（キーボードの裏では動かさない）
  Duration get _panelAnimationDuration => _keyboardInset > 0 ? Duration.zero : _panelDuration;

  /// 閉じるアニメーションが終わったら、パネルの中身を片付ける
  /// 長さが0のときはビルド中に呼ばれるため、フレームの後で更新する
  void _handleBottomAnimationEnd() {
    if (_panelOpen || !_panelContentVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_panelOpen) setState(() => _panelContentVisible = false);
    });
  }

  /// スタンプボタンのタップ時に呼ぶ
  /// キーボードとパネルを切り替える
  void _togglePanel() {
    if (_panelOpen) {
      _focusNode.requestFocus();
      return;
    }
    _closeTimer?.cancel();
    if (_keyboardInset > 0) _panelHeight = _keyboardInset;
    setState(() {
      _panelOpen = true;
      _panelContentVisible = true;
      _bottomDuration = _panelAnimationDuration;
    });
    _focusNode.unfocus();
  }

  void _pickImage() {
    _closePanel();
    widget.onPickImage();
  }

  void _selectSticker(StickerSelection selection) {
    if (!widget.sending) widget.onSelectSticker?.call(selection);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final panelVisible = _hasStickers && _panelContentVisible;
    // 横画面でも、一覧と入力欄が見える高さに収める。
    final panelHeight = math.min(_panelHeight, MediaQuery.sizeOf(context).height / 2);
    // キーボードの動きに合わせて高さを変え、キーボードとパネルの上端を揃え続ける。
    final bottomHeight = _panelOpen && _hasStickers
        ? math.max(0.0, panelHeight - _keyboardInset)
        : MediaQuery.paddingOf(context).bottom;
    // 送信ボタン等を押しても入力を続けられるよう、入力バー全体を入力欄の内側として扱う。
    return TextFieldTapRegion(
      onTapOutside: (_) => _closePanel(),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          // 背景は入力バーから画面の下端まで1枚で塗り、境目を出さない。キーボードの裏まで塗っておくと、
          // キーボードの動きと1フレームずれても画面の背景が見えない。
          Positioned(
            key: const Key('message-input-background'),
            left: 0,
            right: 0,
            top: 0,
            bottom: -_keyboardInset,
            child: ColoredBox(color: context.colors.surface),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.preparingImage) _preparingImageRow(l10n),
              Container(
                padding: const EdgeInsets.fromLTRB(4, 7, 8, 7),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: context.colors.secondaryText.withValues(alpha: 0.2), width: 0.5),
                  ),
                ),
                child: Row(
                  // 入力欄が複数行に伸びても、左右のボタンは最終行の横（下端）に置く。
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _BarIconButton(
                      key: const Key('message-input-image'),
                      icon: CupertinoIcons.photo,
                      label: l10n.chaImageButtonTooltip,
                      onPressed: widget.sending || widget.preparingImage ? null : _pickImage,
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: _field(l10n)),
                    _sendButton(),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: _bottomDuration,
                curve: Curves.easeOut,
                height: bottomHeight,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                onEnd: _handleBottomAnimationEnd,
                child: panelVisible
                    ? OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: panelHeight,
                        maxHeight: panelHeight,
                        child: StickerPickerPanel(packs: widget.stickerPacks, onSelected: _selectSticker),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 選んだ画像の読み込み中の表示
  Widget _preparingImageRow(AppLocalizations l10n) {
    return Container(
      key: const Key('message-input-preparing-image'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.colors.secondaryText.withValues(alpha: 0.2), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(width: 8),
          Text(l10n.chaImagePreparing, style: TextStyle(fontSize: 13, color: context.colors.secondaryText)),
        ],
      ),
    );
  }

  /// 角丸の入力欄
  /// スタンプボタンは内側の右端に置き、複数行でも最終行の横に残す
  Widget _field(AppLocalizations l10n) {
    return DecoratedBox(
      key: const Key('message-input-field'),
      decoration: BoxDecoration(color: context.colors.background, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 8, _hasStickers ? 0 : 14, 8),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                maxLength: widget.maxLength,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                style: const TextStyle(fontSize: 16, height: 1.25),
                decoration: InputDecoration.collapsed(
                  hintText: l10n.chaMessageInputHint,
                  hintStyle: TextStyle(color: context.colors.secondaryText),
                ),
              ),
            ),
          ),
          if (_hasStickers)
            _BarIconButton(
              key: const Key('message-input-sticker'),
              icon: _panelOpen ? CupertinoIcons.keyboard : CupertinoIcons.smiley,
              label: l10n.chaStickerButtonTooltip,
              size: 24,
              extent: 36,
              onPressed: widget.sending ? null : _togglePanel,
            ),
        ],
      ),
    );
  }

  /// 入力欄の右に常に出す
  /// 入力が空のときは押せず、送信中はインジケーターに変わる
  Widget _sendButton() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        if (widget.sending) {
          return const SizedBox(width: 40, height: 36, child: CupertinoActivityIndicator());
        }
        final hasText = value.text.trim().isNotEmpty;
        return _BarIconButton(
          key: const Key('message-input-send'),
          icon: CupertinoIcons.paperplane_fill,
          label: AppLocalizations.of(context)!.chaSendButtonTooltip,
          color: context.colors.accent,
          onPressed: hasText ? widget.onSend : null,
        );
      },
    );
  }
}

/// 入力欄まわりのアイコンボタン
/// 押下中は薄くなる（インクの波紋は出さない）
class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 26,
    this.extent = 40,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final double extent;

  /// 指定がなければ[AppColors.secondaryText]
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ?? context.colors.secondaryText;
    return MergeSemantics(
      child: Semantics(
        label: label,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size(extent, 36),
          onPressed: onPressed,
          child: SizedBox(
            width: extent,
            height: 36,
            child: Icon(icon, size: size, color: onPressed == null ? base.withValues(alpha: 0.4) : base),
          ),
        ),
      ),
    );
  }
}
