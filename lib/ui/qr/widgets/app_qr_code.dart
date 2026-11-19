import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ============================================================
// 部品
// ============================================================

/// 中央にアプリアイコンを重ねたQRコード（LINE風）
/// QRC-01のマイQRコードとGRP-04のグループの招待で共通に使う
///
/// アイコンで隠れる部分を読み取り時に復元できるよう、誤り訂正レベルを最大のH（約30%まで復元可能）にしている。
/// アイコンは一辺をQRの約2割（[size]の48/220）に抑え、隠れる面積を1割未満にしている。
class AppQrCode extends StatelessWidget {
  const AppQrCode({super.key, required this.data, required this.size, this.errorStateBuilder});

  /// QRコードにする文字列
  final String data;

  /// QRコードの一辺
  final double size;

  /// 生成できないときの表示（QrImageViewにそのまま渡す）
  final QrErrorBuilder? errorStateBuilder;

  /// 誤り訂正レベル（アイコンで隠れる部分を復元するため最大のH）
  static const errorCorrectionLevel = QrErrorCorrectLevel.H;

  /// アイコンの一辺の、QRコードの一辺に対する割合（QRC-01の220に対する48）
  static const iconRatio = 48 / 220;

  /// [data]からQRコードを生成できるか
  /// 生成できないときはQrImageViewがエラー表示に切り替わるため、その上に中央のアイコンが重ならないようにする
  static bool canRender(String data) =>
      QrValidator.validate(data: data, version: QrVersions.auto, errorCorrectionLevel: errorCorrectionLevel).isValid;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * iconRatio;
    final scale = iconSize / 48;
    return Stack(
      alignment: Alignment.center,
      children: [
        QrImageView(
          data: data,
          version: QrVersions.auto,
          errorCorrectionLevel: errorCorrectionLevel,
          size: size,
          backgroundColor: Colors.white,
          errorStateBuilder: errorStateBuilder,
        ),
        if (canRender(data))
          Container(
            width: iconSize,
            height: iconSize,
            padding: EdgeInsets.all(3 * scale),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12 * scale)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9 * scale),
              child: Image.asset('assets/icon/app_icon.png'),
            ),
          ),
      ],
    );
  }
}
