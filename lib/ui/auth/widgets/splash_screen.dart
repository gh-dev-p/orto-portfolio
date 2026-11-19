import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_theme.dart';
import '../../../l10n/app_localizations.dart';

// ============================================================
// 画面
// ============================================================

/// 画面AUT-01：スプラッシュ画面（機能仕様書4.1.1 / 画面設計書5.1.1）
///
/// 画面操作を伴わず、ログイン状態の判定中に表示する。
/// 判定結果に応じた遷移先の出し分けは`AuthGate`（lib/app.dart）が行う。
///
/// ロゴの下に不定進捗のプログレスバーを常時表示し、処理が[_slowThreshold]以上続いた場合のみ、
/// その下に「読み込み中…」を追加表示して起動処理中であることを伝える。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.error, this.onRetry});

  /// 表示するエラーメッセージ
  /// nullなら読み込み中の表示、あればエラーと再試行ボタンを表示する
  final String? error;

  /// 再試行ボタンを押したときの処理
  /// 呼び出し元が渡す（[error]があるときだけ使う）
  final VoidCallback? onRetry;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// ============================================================
// State
// ============================================================

/// [SplashScreen]のState
/// 読み込みが長引いているかどうかを持つ
class _SplashScreenState extends State<SplashScreen> {

  // ---- 状態・初期化 ----

  /// 「読み込み中…」を追加表示するまでの時間
  static const _slowThreshold = Duration(milliseconds: 1500);

  /// プログレスバーの最大幅
  static const _progressBarMaxWidth = 200.0;

  /// [_slowThreshold]を計るタイマー
  Timer? _slowTimer;

  /// 読み込みが長引いているか
  /// trueになると「読み込み中…」を追加表示する
  bool _slow = false;

  /// 表示し始めたときに、長引いているかを計るタイマーを始める
  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(_slowThreshold, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  /// 画面が消えるときに、タイマーを止める
  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  // ---- 描画 ----

  /// ロゴと、読み込み中の表示（エラーのときはエラーと再試行ボタン）を描く
  /// ダークモードでもライトのテーマで表示する（ネイティブスプラッシュと見た目を揃えるため）
  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    // ネイティブスプラッシュ（ライトの色で固定）と見た目を揃えるため、ダークモードでもライトのテーマで表示する。
    return Theme(
      data: AppTheme.light,
      child: Builder(
        builder: (context) => Scaffold(
          // ネイティブスプラッシュ画面（起動直後、Flutterエンジン読み込み中にOSが表示する画面。
          // android/app/src/main/res/values/colors.xml・ios/.../LaunchScreen.storyboard参照）と
          // 背景色・アイコンを揃え、画面切り替わりの見た目の段差をなくす。
          backgroundColor: context.colors.splashBackground,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/icon/app_icon_foreground.png', width: 96, height: 96),
                const SizedBox(height: 16),
                Text('Orto', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                if (error == null) ...[
                  // ロゴの直下に、幅を抑えた不定進捗のバーを出す。
                  ConstrainedBox(
                    key: const Key('splash-progress-bar'),
                    constraints: const BoxConstraints(maxWidth: _progressBarMaxWidth),
                    child: LinearProgressIndicator(
                      color: context.colors.accent,
                      backgroundColor: context.colors.accent.withValues(alpha: 0.15),
                      minHeight: 4,
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  if (_slow) ...[
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.commonLoading, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(error, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: widget.onRetry, child: Text(AppLocalizations.of(context)!.commonRetry)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
