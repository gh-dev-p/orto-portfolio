import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../view_models/settings_viewmodel.dart';

// ============================================================
// 画面
// ============================================================

/// SET-01の画面モードを選ぶダイアログ（iOSの設定アプリの「外観モード」風）
/// ライト・ダークの見本を並べ、その下に「端末の設定に従う」のスイッチを置く。選んだモードはその場で反映し、右上の×か外側のタップで閉じる
///
/// 「端末の設定に従う」がオンの間は、今の端末の外観（ライト／ダーク）の側にチェックを付ける。
/// その状態でライト・ダークを選ぶと、スイッチはオフになり、選んだモードに固定する
class DisplayModeDialog extends ConsumerWidget {
  const DisplayModeDialog({super.key});

  /// 見本の大きさ
  static const _previewWidth = 72.0;
  static const _previewHeight = 150.0;

  // ---- 操作 ----

  /// 画面モードを[mode]にする
  void _setThemeMode(WidgetRef ref, ThemeMode mode) {
    ref.read(settingsViewModelProvider.notifier).setThemeMode(mode);
  }

  /// 「端末の設定に従う」を[followSystem]にする
  /// オフにしたときは、今の見た目が変わらないよう、今の端末の外観のモードに固定する
  void _setFollowSystem(BuildContext context, WidgetRef ref, bool followSystem) {
    if (followSystem) {
      _setThemeMode(ref, ThemeMode.system);
      return;
    }
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    _setThemeMode(ref, platformDark ? ThemeMode.dark : ThemeMode.light);
  }

  // ---- 画面 ----

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(settingsViewModelProvider.select((s) => s.themeMode));
    final followSystem = themeMode == ThemeMode.system;
    final dark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
      title: Row(
        children: [
          Expanded(child: Text(l10n.setDisplayModeTile)),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 画面の狭い端末や英語の表示でもはみ出さないよう、2つで幅を等分する
          Row(
            children: [
              Expanded(
                child: _ModeOption(
                  label: l10n.displayModeLightShort,
                  preview: const _ModePreview(dark: false, width: _previewWidth, height: _previewHeight),
                  selected: !dark,
                  onTap: () => _setThemeMode(ref, ThemeMode.light),
                ),
              ),
              Expanded(
                child: _ModeOption(
                  label: l10n.displayModeDarkShort,
                  preview: const _ModePreview(dark: true, width: _previewWidth, height: _previewHeight),
                  selected: dark,
                  onTap: () => _setThemeMode(ref, ThemeMode.dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            activeTrackColor: context.colors.accent,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.displayModeSystem, style: context.textStyles.titleMedium),
            value: followSystem,
            onChanged: (value) => _setFollowSystem(context, ref, value),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// 見本・名前・チェックの丸を縦に並べた、1つのモードの選択肢
class _ModeOption extends StatelessWidget {
  const _ModeOption({required this.label, required this.preview, required this.selected, required this.onTap});

  final String label;
  final Widget preview;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              preview,
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.textStyles.listItemLabel.copyWith(color: context.colors.primaryText),
              ),
              const SizedBox(height: 8),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? context.colors.accent : context.colors.offline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ライト・ダークの見た目の見本（設定画面を簡略化した絵）
/// 表示中のモードに関係なく、[AppColors.light]・[AppColors.dark]の実際の色で、ヘッダー・項目のカード・ボトムナビを描く
/// 文字・アイコンは重くならないよう淡い色の棒にし、アバター・未読バッジだけアクセント色にする（ボトムナビはAppBottomNavと同じ色）
class _ModePreview extends StatelessWidget {
  const _ModePreview({required this.dark, required this.width, required this.height});

  final bool dark;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = dark ? AppColors.dark : AppColors.light;
    final ink = colors.primaryText.withValues(alpha: dark ? 0.3 : 0.18);

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(12)),
      // 枠線は中身（ヘッダー・ボトムナビの面）の上に描く（decorationに付けると中身に隠れて途切れて見える）
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.offline.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          // ヘッダー（タイトルとアバター）
          Container(
            height: 22,
            color: colors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                _line(ink, 16, 4),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _card(colors, ink, rows: 3),
          const SizedBox(height: 6),
          _card(colors, ink, rows: 2),
          const Spacer(),
          // ボトムナビ（左端のタブを選んだ状態。右側に重さが寄らないよう左にする。色はAppBottomNavに合わせる）
          Container(
            height: 16,
            color: colors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final selected in [true, false, false])
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: selected ? colors.primaryText : colors.secondaryText.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 項目を[rows]行並べたカード
  /// 1行目の右端には、未読バッジを模したアクセント色の丸を置く
  Widget _card(AppColors colors, Color ink, {required int rows}) {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _line(ink, 5, 5),
                  const SizedBox(width: 4),
                  _line(ink, 26, 3),
                  const Spacer(),
                  if (i == 0)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                    )
                  else
                    _line(ink, 4, 3),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 文字・アイコンを模した角丸の棒
  static Widget _line(Color color, double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1.5)),
  );
}
