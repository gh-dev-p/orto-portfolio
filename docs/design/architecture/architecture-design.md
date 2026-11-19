# アーキテクチャ・フォルダ構成定義書

**複数アカウント切替メッセージアプリ（Orto）** 

- 対象プロジェクト：Orto
- 本書の位置付け：アプリのアーキテクチャ（MVVM）と、それに対応するフォルダ構成・命名規約・依存関係のルール、dev／prodの環境分離を定義する
- 技術スタック：Flutter / Firebase（状態管理：flutter_riverpod 3系）

---

## 目次

1. [本書の目的・範囲](#1-本書の目的範囲)
2. [採用アーキテクチャ：MVVM + Riverpod](#2-採用アーキテクチャmvvm--riverpod)
3. [フォルダ構成](#3-フォルダ構成)
4. [命名・実装規約](#4-命名実装規約)
  - [4.1 View](#41-view)
  - [4.2 ViewModel](#42-viewmodel)
  - [4.3 Model](#43-model)
  - [4.4 共通（ui/core・config・utils）](#44-共通uicoreconfigutils)
5. [新機能追加時のチェックリスト](#5-新機能追加時のチェックリスト)
6. [環境分離（dev / prod）](#6-環境分離dev--prod)
  - [6.1 目的・範囲](#61-目的範囲)
  - [6.2 採用方式：Flutter build flavor](#62-採用方式flutter-build-flavor)
  - [6.3 Flutter側の構成](#63-flutter側の構成)
  - [6.4 Androidネイティブ設定](#64-androidネイティブ設定)
  - [6.5 iOSネイティブ設定](#65-iosネイティブ設定)
  - [6.6 起動コマンド](#66-起動コマンド)
  - [6.7 dev環境の視覚的警告（誤操作混同防止）](#67-dev環境の視覚的警告誤操作混同防止)

---

## 1. 本書の目的・範囲

本書は、本プロジェクトが採用するアプリケーションアーキテクチャ（MVVM）と、それに対応するフォルダ構成・命名規約・依存関係のルールを定義する。今後の機能追加・リファクタリングは本書のルールに従う。

項目・構成・遷移・データ等の詳細仕様は、要件定義書（docs/requirements/）・機能仕様書（docs/specs/）・データ設計書（docs/design/data/）・画面設計書（docs/design/screens/）で定義するため、本書では扱わない。表示文言の多言語対応は多言語対応（i18n）設計書（docs/design/architecture/i18n-design.md）、Firebaseの構成・デプロイはFirebase構成まとめ（docs/dev/firebase-configuration.md）とリポジトリ直下のREADMEを参照。

---

## 2. 採用アーキテクチャ：MVVM + Riverpod

Flutter公式のアーキテクチャガイド（docs.flutter.dev の App architecture）に従う。状態管理に`flutter_riverpod`を採用しているため、Riverpodの標準的な役割分担をMVVMの各層にそのまま対応させる。

| MVVM層 | 公式の層 | 実体 | 責務 |
|---|---|---|---|
| View | UI層 | `lib/ui/<機能>/widgets/` 配下のScreen・Body・Widget（共通Widgetは`lib/ui/core/ui/`）、`lib/app.dart`（起動時の振り分け・全画面共通のラップ） | 画面の描画のみ。ViewModelが公開するstate・Providerをwatchして表示し、ユーザー操作はViewModelのメソッド呼び出しに変換する |
| ViewModel | UI層 | `lib/ui/<機能>/view_models/` 配下のProvider/Notifier（アプリ全体の状態は`lib/ui/core/view_models/`） | 画面用の状態保持・加工、ユーザー操作の受け口。Modelを呼び出し、結果をUI表示用のstateに変換してViewへ公開する |
| Model | データ層 | `lib/data/repositories/<機能>/`（Repository）＋ `lib/data/services/<機能>/`（外部サービス） | データの取得・更新（Firestore/Storage/Cloud Functions/外部SDK） |

データの形を表すドメインモデルは、データ層とUI層の両方から使うため、`lib/domain/models/`に置く。公式のドメイン層（UseCase）は任意のため、必要になったもの（複数のViewModelで使い回す・複数のRepositoryを組み合わせる処理）だけを`lib/domain/use_cases/`に置き、それ以外の組み合わせの処理はViewModelが行う（4.3）。

依存の向きは **View → ViewModel → Model** の一方向のみ。**Viewが `data/` 配下を直接importすることは禁止**する。Repository/Serviceのインスタンスは`lib/config/service_providers.dart`でProviderとして公開するが、Viewは`service_providers.dart`をimportせず、必ずViewModel（操作用ViewModel・読み取り用Provider）を経由する。

ViewModel・Model層は`BuildContext`に依存しない。表示文言を持たず、エラーは種別（enum）やエラーコードとして返し、文言への変換はView層で`AppLocalizations`を使って行う（多言語対応（i18n）設計書参照）。

特定の画面に属さない出来事（例：アプリを開いているときのプッシュ通知の受信）から表示を出す場合も、ViewModelは出来事を状態として公開するだけにし、`MaterialApp`配下のViewが`ref.listen`して自分の`context`で表示する（例：`push_notification_init.dart`の`foregroundMessageCountProvider`と、`lib/app.dart`のアプリ内バナー）。

---

## 3. フォルダ構成

```
lib/
  ui/                         # UI層（View・ViewModel）。機能ごとのフォルダに分ける（4.1・4.2）
    core/                      # 機能をまたいで使うもの
      ui/                      # 共通Widget（アバター・ボトムナビ・全幅ボタン・件数バッジ・ダイアログ・SnackBar・
                               #   読み込み中表示・新着のアプリ内バナー・確定のスライド・devバナー（6.7）等）
      themes/                  # 色・文字スタイル・テーマ
      view_models/             # アプリ全体の状態（読み込み中表示・表示言語・画面モード）
    account/                   # ACC-01〜03
      view_models/
      widgets/
    auth/                      # AUT-01〜03・AUT-05
      view_models/
      widgets/
    block/                     # ブロックの確認〜実行の共通フロー（CHA-02・PRO-01から使う。実行は各画面のViewModelが渡す）
      view_models/
      widgets/
    chat/                      # CHA-02・CHA-03、画像送信プレビュー
      view_models/             #   トーク一覧（chat_list）のProviderもここに置く
      widgets/
    chat_list/                 # CHA-01（ホームのタブ本文）
      widgets/
    friend/                    # FRI-01（ホームのタブ本文）・FRI-02〜04
      view_models/
      widgets/
    home/                      # ホーム（タブ切替の枠）
      widgets/
    notification/              # プッシュ通知の初期化・通知タップで開くトーク（画面は持たない）
      view_models/
    passcode/                  # AUT-04、パスコードロックのガード
      view_models/
      widgets/
    profile/                   # PRO-01〜03
      view_models/
      widgets/
    qr/                        # QRC-01
      view_models/
      widgets/
    settings/                  # SET-01（ホームのタブ本文）〜SET-05
      view_models/
      widgets/

  domain/
    models/                    # ドメインモデル（データの形）・エラー種別・例外（4.3）
    use_cases/                 # UseCase（複数のViewModelで使い回す、複数のRepositoryを組み合わせる処理。4.3）

  data/                       # データ層（Model）。種類（repositories・services）ごとに分け、その中を機能ごとに分ける（4.3）
    repositories/              # データの種類ごと
      auth/  user/  account/  block/  chat/  friend/  notification/  passcode/
    services/                  # データの出どころごと（Firebase Auth・Cloud Functions・Storage・FCM・端末の保存領域）
      auth/  chat/  profile/  notification/  passcode/
      common/                  # 複数の機能から使うもの（Cloud Functions・Firestore/Storageのパス）

  config/                     # アプリの設定（4.4）
    service_providers.dart     # Repository/ServiceのProvider（Viewからは使わない）
    preferences_provider.dart  # 端末内の設定の保存先（起動時に読み込んだSharedPreferences）
    provider_retry.dart        # Providerの自動再試行を行わない設定
    app_flavor.dart            # 実行中のFlavor（dev/prod）を保持するグローバル変数（6.3）
    （定数）                    # プラン別上限・予約ID・引き継ぎパスワードの文字数・リアクション絵文字・
                               #   規約／ストアのURL等

  utils/                      # 日付・電話番号の書式、電話番号の正規化、バリデーション、画像選択、外部リンク等（4.4）

  l10n/                       # 翻訳データ（ARB）と生成コード（i18n設計書）

  app.dart                    # MaterialApp（テーマ・言語・全画面共通のラップ）と、起動時の振り分け
                              #   （ログイン状態・引き継ぎパスワード・アカウントの有無）
  bootstrap.dart              # dev/prod共通の起動処理（6.3）
  firebase_options_dev.dart   # devプロジェクト向けFirebase設定（6.3）
  firebase_options_prod.dart  # prodプロジェクト向けFirebase設定（6.3）
  main_dev.dart               # dev Flavorのエントリポイント（6.3）
  main_prod.dart              # prod Flavorのエントリポイント（6.3）
```

公式の構成のうち、`data/model/`（APIモデル）は置かない（ドメインモデルがFirestoreとの変換も兼ねる）。ルーターを使っていないため`routing/`も置かない。

---

## 4. 命名・実装規約

### 4.1 View

| 種類 | 命名 | 内容 |
|---|---|---|
| Screen | `xxx_screen.dart` | Navigatorでpushして開く画面。 |
| Body | `xxx_body.dart` | ホームのタブ本文（チャット・友だち・設定）。ホーム（`home_shell.dart`）が`IndexedStack`で切り替え、Navigatorのpush/popは使わない。 |
| フロー | `xxx_flow.dart`など | 複数の画面から呼ぶ、確認ダイアログ〜実行〜結果表示までの一連の流れや、OSの共有シートを開く処理（例：`block_flow.dart`・`invite_share.dart`）。 |
| 画面の枠・ガード | － | ホームの枠（`home_shell.dart`：ヘッダー・タブ本文・ボトムナビ）、全画面を覆うパスコードのガード（`passcode_guard.dart`）。 |
| エラー文言変換 | `xxx_error_localization.dart` | ViewModel・Modelが返すエラー種別を、`AppLocalizations`で表示文言に変換する。 |
| 画面専用の小部品 | － | その機能でだけ使うWidget。画面と同じ`widgets/`に置く。複数機能で使うものは`lib/ui/core/ui/`に置く。 |

Viewはロジックを持たず、`ref.watch`でViewModelのstateを読み、ユーザー操作はViewModelのメソッド呼び出しに変換する。入力欄の内容・部分コピー中のメッセージなど、その画面内で完結する表示用の状態はViewが持ってよい。

Viewが受け取るデータは、自分のViewModelから受け取る（Flutter公式）。共有の読み取り用Provider（`xxx_providers.dart`）は、ViewModelの中で使い、Viewから直接`watch`しない（例：起動時の入口`AuthGate`は、`auth_gate_viewmodel.dart`が決めた画面の種類だけを受け取る）。ただし、アプリ全体の状態（表示言語・画面モード・読み込み中表示）と、画面が見えない間も続ける副作用（プッシュ通知の初期化・アプリ内バナー）は、アプリの土台（`app.dart`）が直接監視する。

### 4.2 ViewModel

ViewModel層には次の2種類がある。

| 種類 | 命名 | 内容 |
|---|---|---|
| 読み取り用Provider | `xxx_providers.dart`・`xxx_provider.dart` | ドメイン単位で、複数画面で共有するリアクティブなデータ（一覧・ストリーム）を公開する。例：`account_providers.dart`、`chat_providers.dart`、`friend_providers.dart` |
| 操作用ViewModel | `xxx_viewmodel.dart` | 画面の操作（入力値・ローディング／エラー状態・Repository呼び出し）をまとめる。`xxxViewModelProvider`として公開する。 |

ファイルは、その機能の画面と同じ機能フォルダの`view_models/`（`lib/ui/<機能>/view_models/`）に置く（トーク一覧の`chat_list/`のProviderは`chat/`にまとめる）。複数の機能から使うものは、主に扱うデータの機能に置き、どの機能にも属さないアプリ全体の状態（読み込み中表示・表示言語・画面モード）は`lib/ui/core/view_models/`に置く。

操作用ViewModelは、状態を持つかどうかで実装を分ける。

- 入力値・ローディング・エラーを画面に表示する場合：`AsyncNotifier`（`AsyncNotifierProvider.autoDispose`）で、状態として公開する（例：`account_creation_viewmodel.dart`）。独立したローディング表示が複数ある・タイマーで毎秒更新するなど、1つの`AsyncValue`に収まらない状態は、`Notifier`（`NotifierProvider.autoDispose`）で独自の状態クラスを公開する（例：`verification_code_viewmodel.dart`・`profile_edit_viewmodel.dart`）。
- 画面を閉じると破棄するかどうかは、Notifierの型ではなくProviderの宣言（`.autoDispose`）で決める（`AutoDisposeNotifier`等の型は使わない）。キーを取るViewModel（`.family`）は、キーをコンストラクタで受け取り、フィールドとして持つ（例：`NotifierProvider.autoDispose.family<ProfileEditViewModel, ProfileEditState, String>(ProfileEditViewModel.new)`と`ProfileEditViewModel(this.accountId)`。`FamilyNotifier`等の型は使わない）。
- `await`の後に`state`・`ref`を使う前は、`ref.mounted`で画面が閉じられて破棄されていないか確かめる（破棄後の`ref`の使用は例外になる）。`ref.mounted`は作り直し（rebuild）の後は新しい`Ref`を指してtrueになるため、作り直す前に始めた処理の結果を捨てたい場合は、別に確かめる（例：`chat_providers.dart`の`MessagesNotifier.loadMore`）。
- 状態を持たず操作だけを受け持つ画面でも、`Notifier`で公開する（例：`chat_image_viewer_viewmodel.dart`）。失敗は結果の値（bool・enum）で返し、View側で文言に変換して表示する。

読み取り用Provider・アプリ全体の状態のうち、値を書き換える操作を持つもの（アクティブアカウント・表示言語等）も`Notifier`で書く。`StateNotifier`は使わない。

Riverpod 3の既定の挙動のうち、次の2つはアプリの挙動に関わるため、次のように扱う。

- **失敗したProviderの自動再試行**：行わない。`ProviderScope`（`bootstrap.dart`）に`retry: noProviderRetry`（`provider_retry.dart`）を渡し、エラーはそのまま画面へ出す。テストの`ProviderContainer`・`ProviderScope`にも同じものを渡す。
- **見えない画面の監視の一時停止**：上に別の画面が積まれて見えない画面の`ref.watch`は一時停止し、監視先のStreamProviderも値を流さなくなる（見えるようになると再開する）。`ref.listen`・`ref.listenManual`は止まらない。画面が見えない間も続ける必要がある副作用（既読処理・通知のタップで開くトーク・アカウントが0件になったときの画面の戻し・FCMトークンの登録）は、`ref.watch`ではなく`ref.listen`・`ref.listenManual`で監視する。

ViewとViewModelは1対1にする（Flutter公式。1つの画面を構成するWidgetの集まりに、1つのViewModel）。複数の画面にまたがる手続きの状態は、ViewModelで共有せず、Repositoryに持たせる（例：SMS認証の手続き中の状態（送信先・verificationId・再送の待ち時間）は`auth_repository.dart`が持ち、AUT-02・AUT-03・AUT-04の各ViewModelがそれを読む）。

ボタン押下時などの非同期処理中の画面全体の読み込み中表示は、`loading_overlay_provider.dart`の`run`で処理を囲んで出す（各ViewModelでは個別に持たない）。

### 4.3 Model

- **ドメインモデル**：`lib/domain/models/` にデータクラスとして定義する。Firestoreのドキュメントとの変換（`fromFirestore`等）と、データだけで完結する処理（トーク一覧の区分け・メッセージ履歴の結合・チャットルームIDの生成等）は置いてよいが、通信・Providerへの依存は持たない。表示文言は持たない。Viewでも参照するエラー種別（enum）・例外の型も`lib/domain/models/`に置く（例：`auth_error_code.dart`・`transfer_password_error.dart`）。
- **UseCase**（`lib/domain/use_cases/`、`xxx_use_case.dart`）：複数のViewModelで使い回す処理や、複数のRepositoryを組み合わせる処理だけを置く（公式でも任意。必要になったら作る）。Repositoryを使い、Providerには依存しない。例：`complete_phone_verification_use_case.dart`（SMS認証の後処理。AUT-02・AUT-03・AUT-04で使い、`AuthRepository`と`UserRepository`を組み合わせる）、`withdraw_use_case.dart`（退会。SET-04・AUT-05で使い、`UserRepository`と`PasscodeRepository`を組み合わせる）。
- **Repository**（`lib/data/repositories/<機能>/`、`xxx_repository.dart`）：データの種類ごと（auth・user・account・chat・friend・block・notification・passcode）に置く。Serviceから取ったデータをドメインモデルに変換し、外部のエラーをエラー種別（enum）・例外に変換して返す。ViewModelはRepositoryを使い、Serviceを直接使わない。1つのRepositoryが複数のServiceを使ってよい（例：`auth_repository.dart`はFirebase AuthenticationとCloud Functionsを使う）。
- **Service**（`lib/data/services/<機能>/`。複数の機能から使うものは`common/`）：データの出どころごとに置き、外部のSDK・APIを包むだけにする。状態を持たず、外部の結果・エラーをそのまま返す。`xxx_service.dart` ＝ Firebase Auth・Cloud Functions・FCM等のSDKラッパー（例：`firebase_auth_service.dart`・`cloud_functions_service.dart`。FCMトークンのFirestoreへの登録は`push_notification_service.dart`が行う）、`xxx_storage_service.dart` ＝ Storageへの入出力、`xxx_store.dart` ＝ 端末内の保存領域（例：`passcode_store.dart`）。
- `data/`は、Flutter公式では種類（`repositories/`・`services/`）ごとに分けるだけだが、本プロジェクトでは探しやすさのため、その中を機能ごとのフォルダに分ける（公式の種類の分け方はそのまま残す）。
- Firestoreのパスは`lib/data/services/common/firestore_paths.dart`に、Storageのパスは`lib/data/services/common/storage_paths.dart`にまとめる（Storageのパスはstorage.rules・Cloud Functionsと同じ形にすること）。
- Repository/Serviceは、接続先（`FirebaseFirestore`・`FirebaseStorage`・`FirebaseAuth`・`FirebaseMessaging`・`FirebaseFunctions`）をコンストラクタで受け取り、`.instance`を直接参照しない。実体は`service_providers.dart`で渡す（Firestoreは`firestorePathsProvider`の`FirestorePaths`経由）。テストでは差し替えられる。

### 4.4 共通（ui/core・config・utils）

- `lib/config/`：アプリの設定と依存関係（`service_providers.dart`・`preferences_provider.dart`・`provider_retry.dart`・`app_flavor.dart`）と定数を置く。
- `lib/utils/`：特定の層・機能に属さない処理（日付・電話番号の書式、電話番号の正規化、バリデーション等）を置く。他の層（ui・domain・data）に依存しない。
- `lib/ui/core/`：機能をまたいで使うUI（共通Widget・テーマ・アプリ全体の状態）を置く。

定数・`utils/`・テーマ・共通Widget（`lib/ui/core/ui/`）は、表示文言のため`lib/l10n/`を参照してよいが、各機能のフォルダ・`data/`には依存させない。共通Widgetは必要なデータを引数で受け取り、画面遷移が必要なものは、遷移先の画面をimportせず、コールバックとして受け取る（例：`app_bottom_nav.dart`・`app_home_header.dart`）。

---

## 5. 新機能追加時のチェックリスト

1. 画面を追加する → `lib/ui/<機能>/widgets/xxx_screen.dart`（ホームのタブ本文なら`xxx_body.dart`）
2. その画面が状態を持つ・データ操作を行う → 対応する `lib/ui/<機能>/view_models/xxx_viewmodel.dart` を用意し（既存のViewModelで扱える操作なら共有する）、画面から `data/` を直接呼ばない
3. 複数画面で共有する読み取りデータがある → `lib/ui/<機能>/view_models/` にドメイン単位の `xxx_providers.dart` として追加（既存ファイルへの追記でも可）
4. 新しいデータ型が必要 → `lib/domain/models/` に通信を持たないクラスとして追加
5. Firestore/Storage/Cloud Functions/外部SDKとのやりとりが必要 → `lib/data/repositories/<機能>/`・`lib/data/services/<機能>/` に4.3の命名規約に従って追加し、`lib/config/service_providers.dart`にProviderを追加
6. エラーを表示する → ViewModel・Modelはエラー種別を返し、Viewで`AppLocalizations`を使って文言に変換する

<kbd>補足・実装メモ</kbd>

依存ルールに反していないかを調べる際は、importの有無（`grep -rn "data/" lib/ui`）と、実際の呼び出し箇所（`ref.read(xxxRepositoryProvider)`・`ref.read(xxxServiceProvider)`等）の両方を確認する。後者は、
```
ref
    .read(authServiceProvider)
    .sendCode(...)
```
のように呼び出しが複数行に折り返されている場合があるため、1行に収まるパターンだけで検索しないこと。

---

## 6. 環境分離（dev / prod）

### 6.1 目的・範囲

本番のFirestore等に影響を与えずに動作確認できるよう、Flutterアプリを検証用のFirebaseプロジェクトに向けて起動できるようにする。設定ファイルを手動で書き換える運用は、本番・検証環境を取り違える事故のリスクがあるため、ビルドの単位で切り替える。

本章はFlutterアプリ側の切り替え機構を対象とする。Firebase側（Firestore・Storageのルール、Cloud Functions、Hosting）のデプロイ先は、`firebase/.firebaserc`のalias（`dev`・`prod`）と`firebase/deploy.sh`で切り替える（サーバ側はこのコピーに含めない）。

### 6.2 採用方式：Flutter build flavor

dev/prod の2 Flavorを、AndroidネイティブのproductFlavor・iOSネイティブのXcode schemeレベルで分離する。`--dart-define`のような実行時フラグのみの分離ではなく、ビルド成果物（アプリID・設定ファイル）自体を分けることで、誤ったFirebaseプロジェクトへ接続した状態のままリリースビルドを作ってしまう事故を構造的に防ぐ。

| 項目 | dev | prod |
|---|---|---|
| Firebaseプロジェクト | `example-orto-dev` | `example-orto-prod` |
| Flutterエントリポイント | `lib/main_dev.dart` | `lib/main_prod.dart` |
| Firebase設定ファイル | `lib/firebase_options_dev.dart` | `lib/firebase_options_prod.dart` |
| Android applicationId | `com.example.orto.dev` | `com.example.orto` |
| iOS Bundle ID | `com.example.orto.dev` | `com.example.orto` |
| iOSのScheme | `dev` | `prod` |
| Android/iOSアプリ表示名 | `Orto Dev` | `Orto` |

### 6.3 Flutter側の構成

- `lib/config/app_flavor.dart`：`enum AppFlavor { dev, prod }` と、起動時に一度だけセットするグローバル変数`late final AppFlavor currentFlavor`を定義する。Flavorに応じた分岐が必要な箇所（`lib/ui/core/ui/dev_env_banner.dart`等）はこの変数を参照する。
- `lib/main_dev.dart` / `lib/main_prod.dart`：それぞれ対応する`firebase_options_dev.dart` / `firebase_options_prod.dart`の`DefaultFirebaseOptions.currentPlatform`とFlavorを、共通の`lib/bootstrap.dart`の`bootstrap()`に渡す。FCMのバックグラウンド受信ハンドラは`@pragma('vm:entry-point')`を付けたトップレベル関数である必要があるため、各エントリポイント側に置いて`bootstrap()`に渡す。
- `lib/bootstrap.dart`：`currentFlavor`をセットし、Firebase初期化（10秒でタイムアウト）・App Check有効化・バックグラウンド受信ハンドラ登録と、`SharedPreferences`の読み込みを行ってから`runApp`する。読み込んだ`SharedPreferences`は`ProviderScope`で`sharedPreferencesProvider`（`lib/config/preferences_provider.dart`）に渡し、端末内の設定（アクティブアカウント・表示言語・画面モード）を持つNotifierが`build`の時点で保存値を同期的に読む（復元を待つ間に初期値が一瞬表示されないようにするため）。Firebase初期化に失敗した場合は、白画面にせずエラー内容を表示する画面を出す。
- `lib/firebase_options_dev.dart` / `lib/firebase_options_prod.dart`：`scripts/configure_firebase.sh dev|prod`で生成する。素の`flutterfire configure`は不要なファイルを作ったり`project.pbxproj`を書き換えたりするため使わない。

### 6.4 Androidネイティブ設定

- `android/app/build.gradle.kts`に`flavorDimensions += "env"`と`productFlavors`（`dev`・`prod`）を定義する。devは`applicationIdSuffix = ".dev"`・`resValue("string", "app_name", "Orto Dev")`、prodはsuffix無し・`app_name`は`Orto`。`AndroidManifest.xml`の`android:label`は`@string/app_name`を参照する。
- `google-services.json`はFlavorごとに`android/app/src/dev/google-services.json`・`android/app/src/prod/google-services.json`に置き、Google Servicesプラグインがビルド中のFlavorに応じて読む（`scripts/configure_firebase.sh`が生成する）。

### 6.5 iOSネイティブ設定

- Xcodeに`dev`・`prod`の2 Schemeと、Configuration（`Debug-dev`／`Release-dev`／`Profile-dev`、`Debug-prod`／`Release-prod`／`Profile-prod`）を作成する。
- 各Configurationのxcconfigで、エントリポイント（`FLUTTER_TARGET`）とアプリ表示名（`APP_DISPLAY_NAME`）を切り替える。devは`ios/Flutter/Debug-dev.xcconfig`・`Release-dev.xcconfig`・`Profile-dev.xcconfig`、prodは`ios/Flutter/Debug-prod.xcconfig`・`Release-prod.xcconfig`・`Profile-prod.xcconfig`を使う。Flavorを付けない`Debug`／`Release`／`Profile`のConfigurationと`Runner`スキームは置かない（`flutter run`・`flutter build`には必ず`--flavor`を付ける）。プラグインはSwift Package Managerで取り込み、CocoaPods（`Podfile`）は使わない（SPM非対応のプラグインは入れない。動画の圧縮はそのためネイティブコードで実装した。`VideoProcessingChannel`）。`Info.plist`の`CFBundleDisplayName`は`$(APP_DISPLAY_NAME)`を参照する。
- Bundle ID（`PRODUCT_BUNDLE_IDENTIFIER`）はConfigurationごとに設定する。
- `GoogleService-Info.plist`は使わず、Dart側の`firebase_options_*.dart`を`Firebase.initializeApp(options:)`に渡して初期化する。電話番号認証用のURLスキームは`Info.plist`に設定し、`scripts/configure_firebase.sh`が生成後に一致を確認する。

### 6.6 起動コマンド

```
# dev
flutter run --flavor dev -t lib/main_dev.dart

# prod
flutter run --flavor prod -t lib/main_prod.dart

# リリースビルド例（prod）
flutter build apk --flavor prod -t lib/main_prod.dart
flutter build ipa --flavor prod -t lib/main_prod.dart
```

### 6.7 dev環境の視覚的警告（誤操作混同防止）

`currentFlavor == AppFlavor.dev`の場合のみ、`lib/ui/core/ui/dev_env_banner.dart`が画面右上に赤地・白文字「DEV」の斜めリボン（Flutterの`Banner`）を常時表示する。`lib/app.dart`の`MaterialApp.builder`で全画面を包んで適用するため、画面遷移・スクロールで隠れない。prodビルドでは何も描画しない。
