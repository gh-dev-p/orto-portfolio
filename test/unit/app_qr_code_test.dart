import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/app_flavor.dart';
import 'package:multi_id_msg/config/invite_links.dart';
import 'package:multi_id_msg/ui/qr/widgets/app_qr_code.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zxing2/qrcode.dart';

/// [AppQrCode]と同じ誤り訂正レベルで作ったQRコードを、中央のアイコンの範囲を塗りつぶした画像にして読み取る
/// 塗りつぶしは白と黒の両方で試す（実際のアイコンは色が混ざるため、どちらでも読めれば足りる）
String? decodeWithCenterCovered(String data, {required double widgetSize, required bool coverDark}) {
  final qr = QrImage(QrCode.fromData(data: data, errorCorrectLevel: AppQrCode.errorCorrectionLevel));
  const moduleScale = 8;
  const quietModules = 4;
  final modules = qr.moduleCount;
  final side = (modules + quietModules * 2) * moduleScale;
  final pixels = Int32List(side * side)..fillRange(0, side * side, 0xFFFFFFFF);
  for (var y = 0; y < modules; y++) {
    for (var x = 0; x < modules; x++) {
      if (!qr.isDark(y, x)) continue;
      for (var dy = 0; dy < moduleScale; dy++) {
        for (var dx = 0; dx < moduleScale; dx++) {
          pixels[((y + quietModules) * moduleScale + dy) * side + (x + quietModules) * moduleScale + dx] = 0xFF000000;
        }
      }
    }
  }
  // QrImageViewは既定で周囲に10の余白を取るため、模様の一辺はwidgetSize - 20
  final coverRatio = widgetSize * AppQrCode.iconRatio / (widgetSize - 20);
  final qrPixels = modules * moduleScale;
  final cover = (qrPixels * coverRatio).ceil();
  final start = quietModules * moduleScale + (qrPixels - cover) ~/ 2;
  for (var y = start; y < start + cover; y++) {
    for (var x = start; x < start + cover; x++) {
      pixels[y * side + x] = coverDark ? 0xFF000000 : 0xFFFFFFFF;
    }
  }
  final bitmap = BinaryBitmap(HybridBinarizer(RGBLuminanceSource(side, side, pixels)));
  try {
    return QRCodeReader().decode(bitmap).text;
  } on ReaderException {
    return null;
  }
}

void main() {
  // 招待トークンは32バイトのBase64URL（43文字）。アカウントIDは最長の20文字で試す
  const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ';
  final accountId = 'a' * 20;
  // QRコードには招待リンク（https）を入れる。本番のドメインのほうが長いため、両方の環境で試す
  for (final flavor in AppFlavor.values) {
    final groupData = InviteLinks.groupQrData(token, flavor);
    final friendData = InviteLinks.friendQrData(accountId, flavor);

    test('${flavor.name}：QRコードの中身は招待リンクと同じhttpsのURL', () {
      expect(groupData, InviteLinks.forGroup(token, flavor));
      expect(friendData, InviteLinks.forAccount(accountId, flavor));
      expect(groupData, startsWith('https://'));
      expect(friendData, startsWith('https://'));
    });

    for (final (label, data, size) in [('GRP-04（グループの招待）', groupData, 200.0), ('QRC-01（マイQRコード）', friendData, 220.0)]) {
      test('${flavor.name}・$label：中央のアイコンで隠れても、招待リンクとして読み取れる', () {
        expect(AppQrCode.canRender(data), isTrue);
        for (final coverDark in [false, true]) {
          final decoded = decodeWithCenterCovered(data, widgetSize: size, coverDark: coverDark);
          expect(decoded, data);
          // 読んだ中身を、アプリのスキャナーと同じ読み方で招待として読める
          final invite = InviteLinks.qrInviteFrom(decoded!, flavor);
          if (data == groupData) {
            expect((invite as GroupQrInvite).token, token);
          } else {
            expect((invite as FriendQrInvite).accountId, accountId);
          }
        }
      });
    }
  }
}
