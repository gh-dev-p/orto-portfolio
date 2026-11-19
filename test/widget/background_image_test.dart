import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/core/ui/background_image.dart';

void main() {
  testWidgets('画像がなければ、右上と左下の角が同じ色になるグラデーションを出す', (tester) async {
    const size = Size(375, 150);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(width: 375, height: 150, child: BackgroundImage()),
        ),
      ),
    );

    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final gradient = (box.decoration as BoxDecoration).gradient! as LinearGradient;
    final begin = (gradient.begin as Alignment).alongSize(size);
    final end = (gradient.end as Alignment).alongSize(size);

    double position(Offset point) {
      final line = end - begin;
      final toPoint = point - begin;
      return (toPoint.dx * line.dx + toPoint.dy * line.dy) / line.distanceSquared;
    }

    expect(gradient.stops, [0, 0.7071]);
    expect(position(Offset(size.width, 0)), closeTo(0.5, 0.0001));
    expect(position(Offset(0, size.height)), closeTo(0.5, 0.0001));
    expect(position(Offset(size.width, size.height)), closeTo(1, 0.0001));
  });

  testWidgets('このアプリのStorageでないURLは読み込まない', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: BackgroundImage(url: 'https://attacker.example/t/1.jpg'),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byType(DecoratedBox), findsOneWidget);
  });
}
