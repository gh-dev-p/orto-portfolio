import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'bootstrap.dart';
import 'config/app_flavor.dart';
import 'firebase_options_dev.dart';

/// バックグラウンド／終了時のメッセージ受信ハンドラ（機能仕様書4.4.6.1）。
/// 別Isolateで実行されうるためFirebaseの初期化が必要。通知本文の表示自体は
/// FCMの`notification`ペイロードによりOSが自動で行うため、ここでは追加処理を行わない。
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() {
  bootstrap(
    options: DefaultFirebaseOptions.currentPlatform,
    flavor: AppFlavor.dev,
    backgroundMessageHandler: _firebaseMessagingBackgroundHandler,
  );
}
