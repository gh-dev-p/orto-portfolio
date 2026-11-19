/// 実行中のFlutter build flavor（アーキテクチャ設計書6章「環境分離（dev / prod）」）。
enum AppFlavor { dev, prod }

/// 各エントリポイント（main_dev.dart／main_prod.dart）が起動時に一度だけセットする。
/// [AppFlavor.dev]の場合のみdev_env_banner.dart等がバナー表示等の分岐を行う。
late final AppFlavor currentFlavor;
