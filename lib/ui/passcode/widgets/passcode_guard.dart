import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../view_models/passcode_guard_viewmodel.dart';
import '../view_models/passcode_providers.dart';
import 'passcode_entry_screen.dart';

// ============================================================
// 画面
// ============================================================

/// アカウントごとのパスコードロック（機能仕様書4.2.4）のガード
/// 使用中のアカウントにパスコードが設定されていて、今回まだ解除していない間だけ、画面全体をAUT-04（パスコード入力画面）で覆う
///
/// `MaterialApp.builder`で画面全体（Navigator）を包むため、画面遷移の構造（起動時のゲート、ACC-01の初回選択、アカウント切り替えのシート等）に関わらず、起動時・アカウント切り替え時のどの経路でも同じ場所で止められる。下のNavigatorは破棄せずそのまま保つ
class PasscodeGuard extends ConsumerStatefulWidget {
  const PasscodeGuard({super.key, required this.child});

  /// 覆われる側の画面全体
  final Widget child;

  @override
  ConsumerState<PasscodeGuard> createState() => _PasscodeGuardState();
}

class _PasscodeGuardState extends ConsumerState<PasscodeGuard> {
  /// バックグラウンドからの復帰を受け取る
  /// ガードはアプリの全体を包むため、どの画面にいても動く
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final unlocked = ref.read(unlockedAccountIdProvider.notifier);
    _lifecycle = AppLifecycleListener(onHide: unlocked.onHidden, onResume: unlocked.onResumed);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// 画面全体の上に、ガードの状態に応じた覆いを重ねる
  /// 確認中は背景色で隠し、入力が必要ならAUT-04を出す
  @override
  Widget build(BuildContext context) {
    // 下の画面の入力欄がキーボードを出したまま残らないよう、ロックしたらフォーカスを外す。
    ref.listen(passcodeGuardStatusProvider, (_, next) {
      if (next == PasscodeGuardStatus.locked) FocusManager.instance.primaryFocus?.unfocus();
    });
    final state = ref.watch(passcodeGuardViewModelProvider);
    final status = state.status;
    final activeAccountId = state.accountId;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // パスコードの有無を確認できるまでは、画面の内容を見せない。
        if (status == PasscodeGuardStatus.checking)
          Positioned.fill(child: ColoredBox(color: context.colors.background)),
        if (status == PasscodeGuardStatus.locked && activeAccountId != null)
          Positioned.fill(
            child: _LockedOverlay(key: ValueKey(activeAccountId), accountId: activeAccountId),
          ),
      ],
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// ガード中のAUT-04
/// SMS再認証（認証コード入力画面）へ進めるよう、専用のNavigatorを持つ
class _LockedOverlay extends StatefulWidget {
  const _LockedOverlay({super.key, required this.accountId});

  final String accountId;

  @override
  State<_LockedOverlay> createState() => _LockedOverlayState();
}

class _LockedOverlayState extends State<_LockedOverlay> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Androidの戻るボタンの処理
  /// 認証コード入力画面からAUT-04へ戻す。AUT-04自体では何もせず、アプリを閉じる（ガードを迂回して下の画面へは戻らない）
  @override
  Future<bool> didPopRoute() async => await _navigatorKey.currentState?.maybePop() ?? false;

  @override
  Widget build(BuildContext context) {
    // HeroControllerはMaterialAppのNavigatorが持っており、複数のNavigatorでは共有できない。
    return HeroControllerScope.none(
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => PasscodeEntryScreen(accountId: widget.accountId, mode: PasscodeEntryMode.guard),
        ),
      ),
    );
  }
}
