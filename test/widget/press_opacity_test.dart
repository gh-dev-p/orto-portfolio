import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/core/ui/press_opacity.dart';

void main() {
  testWidgets('押している間だけ薄くなり、離すとタップが通知される', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PressOpacity(onTap: () => tapped++, child: const SizedBox(width: 100, height: 100)),
        ),
      ),
    );
    double opacity() => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PressOpacity)));
    await tester.pump();
    expect(opacity(), lessThan(1));

    await gesture.up();
    await tester.pump();
    expect(opacity(), 1);
    expect(tapped, 1);
  });

  test('テーマはタップの波紋を出さず、スクロールでAppBarを染めない', () {
    final theme = AppTheme.light;
    expect(theme.splashFactory, NoSplash.splashFactory);
    expect(theme.appBarTheme.scrolledUnderElevation, 0);
    expect(theme.appBarTheme.centerTitle, isTrue);
  });
}
