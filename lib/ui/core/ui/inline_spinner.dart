import 'package:flutter/cupertino.dart';

/// ボタン内などテキストの代わりに表示する、16×16の小さなローディングスピナー。
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 16, height: 16, child: CupertinoActivityIndicator(radius: 8));
  }
}
