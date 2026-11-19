# Orto

1台の端末で複数のアカウントを切り替えて使える、メッセージアプリです（iOS・Android）。電話番号（SMS認証）でログインし、他の人から見えるアカウントを場面ごとに作って、アカウントごとに友だちとトークを持てます。アカウント同士が同じ人のものだとは、他の人には分かりません。

## このコピーについて

- 作品の紹介のために公開している、閲覧用のコピーです。開発しているリポジトリから、クライアント（Flutter）と仕様・設計の文書だけを取り出しています。履歴は持ち込んでいません。
- サーバ側の実装（Cloud Functions、Firestore・Storage のセキュリティルール）と、運用・ストア掲載の情報は含みません。文書やコメントに出てくる `firebase/` のパスは、このコピーにはありません。
- 接続設定が空なので、実機では動きません。`lib/firebase_options_{dev,prod}.dart` は値が空の見本で、`google-services.json` も含まないため、Android のビルドは通りません。
- Firebase と RevenueCat の接続先、署名（Team ID を含む）は設定していません。バンドルID・パッケージ名（`com.example.orto`）と、招待リンク・規約のドメイン（`example.com`）は見本の値です。

## 主な機能

- 電話番号の SMS 認証によるログイン、電話番号の変更、引き継ぎパスワード、退会
- アカウントの作成・切り替え・削除と、アカウントごとの未読数、パスコードロック
- アカウントID検索・QRコード・招待リンクでの友だち追加と、ニックネーム
- 1対1とグループのトーク（テキスト・画像・スタンプ、既読、リアクション、送信取消）、写真と動画のアルバム
- 友だち申請、友だちでない相手からのトークリクエスト、ブロック・通報
- オフ会グループ：期限付きのグループ、参加の申請と承認、定員とキャンセル待ち、お知らせと会の日時、出欠と催促、精算（外部の送金サービスへの案内と、払った記録）、次の回の作成
- 新着とリアクションのプッシュ通知（アカウントごとのオン・オフ）
- 有料プラン（月額サブスクリプション）
- 日本語・英語の切り替え、ライト・ダークの画面モード

機能の一覧は [要件定義書](docs/requirements/requirements.md) の4章、挙動の詳細は [機能仕様書](docs/specs/functional-spec.md) にあります。

## 技術スタック

| 分類 | 内容 |
| --- | --- |
| クライアント | Flutter（Dart）、対象は iOS・Android |
| 状態管理 | flutter_riverpod |
| バックエンドのクライアント | Firebase（Authentication・Firestore・Storage・Cloud Functions・Cloud Messaging・App Check） |
| 課金 | purchases_flutter（RevenueCat） |
| 招待とQRコード | app_links、mobile_scanner、qr_flutter |
| 画像・動画 | image_picker、flutter_image_compress、video_player |
| 多言語化 | flutter_localizations、intl（ARB） |

依存の全体は [pubspec.yaml](pubspec.yaml) にあります。

## ディレクトリ構成

```
lib/
  ui/        画面と ViewModel。機能ごとのフォルダーに分ける（共通は core/）
  domain/    ドメインモデルと、複数の Repository にまたがる UseCase
  data/      Repository と Service
  config/    Provider、定数、環境ごとの設定
  utils/     層や機能に属さない処理
  l10n/      表示文言（日本語・英語）
  app.dart、bootstrap.dart、main_dev.dart、main_prod.dart
  firebase_options_{dev,prod}.dart   接続設定の見本（値は空）
test/        単体テストとウィジェットテスト
integration_test/   実機・シミュレーターで動かすテスト
android/、ios/      ネイティブの設定と、動画の処理・招待の貼り付けなどのネイティブ実装
docs/        仕様書・設計書
scripts/     Firebase の設定ファイルを環境ごとに作り直す道具
```

## アーキテクチャの要点

- Flutter 公式のアーキテクチャガイドに沿った MVVM です。状態管理は Riverpod で統一しています。
- 依存の向きは、View → ViewModel → Model の一方向だけです。
- Repository と Service は、`lib/config/service_providers.dart` で Provider として公開します。
- ViewModel と Model は表示文言を持たず、エラーは種別で返し、View が文言に変えます。
- dev・prod の2つの環境を、Flutter の flavor で分けています（エントリポイント・バンドルID・接続先を分ける）。
- 他の人に内部の識別子（uid）を見せないデータ構造にし、アカウント数の上限やブロック中の送信拒否などの制約は、アプリではなくサーバ側のルールで守ります。

詳しくは [アーキテクチャ・フォルダ構成定義書](docs/design/architecture/architecture-design.md) と [データ設計書](docs/design/data/data-design.md) にあります。

## 文書

文書の入口は [docs/README.md](docs/README.md) です。要件定義書、機能仕様書、データ設計書、画面設計書、アーキテクチャ・フォルダ構成定義書、多言語対応（i18n）設計書があります。

## 確認の手順

```bash
flutter pub get
flutter analyze
flutter test
```

## ライセンス

[LICENSE](LICENSE) を参照してください。
