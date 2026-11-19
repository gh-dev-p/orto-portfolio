# 多言語対応（i18n）設計書

**複数アカウント切替メッセージアプリ（Orto）** 

- 対象プロジェクト：Orto
- 本書の位置付け：表示言語（日本語・英語）の切り替えの仕組みと、表示文言の管理方法を定義する
- 技術スタック：Flutter（`flutter_localizations`・ARB・`flutter gen-l10n`）

---

## 目次

1. [本書の目的・範囲](#1-本書の目的範囲)
2. [採用方式](#2-採用方式)
  - [2.1 設定ファイル](#21-設定ファイル)
3. [表示言語の決め方](#3-表示言語の決め方)
  - [3.1 通常起動時](#31-通常起動時)
  - [3.2 表示言語の保存と復元](#32-表示言語の保存と復元)
  - [3.3 起動失敗時の画面](#33-起動失敗時の画面)
  - [3.4 表示言語の切り替え（SET-01）](#34-表示言語の切り替えset-01)
4. [キーの命名規約](#4-キーの命名規約)
5. [プレースホルダー](#5-プレースホルダー)
6. [ViewModel・Model層での文言の扱い](#6-viewmodelmodel層での文言の扱い)
  - [6.1 エラー種別（enum）で返す](#61-エラー種別enumで返す)
  - [6.2 エラーの有無だけを返す](#62-エラーの有無だけを返す)
  - [6.3 文言を引数で受け取る](#63-文言を引数で受け取る)
  - [6.4 画面に属さない出来事から出す表示](#64-画面に属さない出来事から出す表示)
7. [日付・時刻の表示](#7-日付時刻の表示)
8. [プッシュ通知の文言](#8-プッシュ通知の文言)
9. [iOSの権限ダイアログの文言](#9-iosの権限ダイアログの文言)
10. [用語の統一](#10-用語の統一)

---

## 1. 本書の目的・範囲

本書は、アプリの表示文言を日本語・英語で切り替えるための仕組みと、文言の追加・管理のルールを定義する。

- 対応言語：日本語（`ja`）・英語（`en`）
- 対象：`lib/ui/`の画面に表示する文言（Text・SnackBar・ダイアログ等）、`lib/app.dart`・`lib/bootstrap.dart`のエラー表示、日付・時刻の表示、プッシュ通知の文言、iOSの権限ダイアログの文言
- 対象外：コメント・ログ出力・Firestoreのフィールド名など、画面に表示しない文字列

画面ID（AUT-01等）は画面設計書のID体系に従う。ViewModel・Model層が`BuildContext`に依存しないという依存ルールは、アーキテクチャ・フォルダ構成定義書2章で定義する。

---

## 2. 採用方式

Flutter公式の`flutter_localizations`と、ARBファイル＋`flutter gen-l10n`によるコード生成を使う。

- 翻訳データの正本：`lib/l10n/app_ja.arb`（テンプレート）・`lib/l10n/app_en.arb`。2つのファイルは同じキーを持つ。
- コード生成：`flutter gen-l10n`（`pubspec.yaml`の`flutter.generate: true`により、ビルド時に自動で実行される）
- 生成物：`lib/l10n/app_localizations.dart`（抽象クラス`AppLocalizations`）・`app_localizations_ja.dart`／`app_localizations_en.dart`（言語ごとの実装）
- 各キーには`@キー名`の`description`で、使う画面（画面ID）や用途を書く。
- AUT-02の国・地域の一覧の国名と検索欄の文言は、`country_picker`パッケージの`CountryLocalizations`を使い、ARBには持たない。

### 2.1 設定ファイル

`l10n.yaml`（リポジトリ直下）：

```yaml
arb-dir: lib/l10n
template-arb-file: app_ja.arb
output-localization-file: app_localizations.dart
output-dir: lib/l10n
```

`pubspec.yaml`の関連する依存：`flutter_localizations`（SDK）・`intl`（日付の書式）・`shared_preferences`（表示言語の保存）・`country_picker`（国名）。

---

## 3. 表示言語の決め方

### 3.1 通常起動時

`lib/app.dart`の`MultiIdMsgApp`が`localeProvider`（`lib/ui/core/view_models/locale_provider.dart`）を`watch`し、`MaterialApp.locale`に渡す。

```dart
final locale = ref.watch(localeProvider);

MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    CountryLocalizations.delegate, // AUT-02の国・地域の一覧（country_picker）
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  ...
)
```

Viewは`AppLocalizations.of(context)`で、現在の表示言語の文言を取得する。

### 3.2 表示言語の保存と復元

`LocaleNotifier`（`NotifierProvider<LocaleNotifier, Locale>`）が表示言語を持つ。

- 言語を選んでいない間は、端末の言語に従う（`initialLocaleFor()`）。端末の言語の優先順（`PlatformDispatcher.locales`）で最初に対応している言語にし、日本語・英語のどちらでもない場合は英語にする。ログイン前の画面（AUT-01〜03・AUT-05・ACC-01・ACC-02）も、この言語で表示する。
- 選んだ言語コードを`SharedPreferences`のキー`appLocaleLanguageCode`に保存し、次回の起動時に復元する。`SharedPreferences`は起動時（`lib/bootstrap.dart`）に読み込み済みのものを`sharedPreferencesProvider`から受け取るため、`build`の時点で保存値を返す（最初の描画から選んだ言語で表示する）。
- `setLocale(Locale)`は、状態の更新と保存を同時に行う。`MaterialApp.locale`がすぐに変わるため、アプリの再起動は要らない。

```dart
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final code = ref.watch(sharedPreferencesProvider).getString(_prefsKey);
    if (code != null) return Locale(code);
    return initialLocaleFor(WidgetsBinding.instance.platformDispatcher.locales);
  }
  static const _prefsKey = 'appLocaleLanguageCode';
  Future<void> setLocale(Locale locale) async { ... }
}
```

### 3.3 起動失敗時の画面

Firebaseの初期化に失敗したときの画面（`lib/bootstrap.dart`の`_StartupErrorApp`）は、専用の`MaterialApp`で表示する。`localeProvider`は使わず、`locale`を渡さないことで端末の言語に従う（日本語・英語のどちらでもない場合は、Flutterの解決により`supportedLocales`の先頭の英語になる）。起動の最初期の画面のため、Riverpod・`SharedPreferences`に依存させず、SET-01で選んだ言語は反映しない。

### 3.4 表示言語の切り替え（SET-01）

`lib/ui/settings/widgets/settings_body.dart`の「言語」項目（アイコン`Icons.language_outlined`）をタップすると`SimpleDialog`が開き、「日本語」「English」から選ぶ。

- 項目の右端に、選択中の言語を表示する。
- 選ぶと`ref.read(localeProvider.notifier).setLocale(selected)`を呼び、画面全体にすぐ反映される。
- 選択肢のラベルもARBのキー（`languageJapanese`・`languageEnglish`）を使う。

<kbd>補足・実装メモ</kbd>

言語を追加する場合は、`app_<言語コード>.arb`の追加に加え、SET-01の選択肢（日本語・英語の2択を直接書いている）、項目の右端の表示、プッシュ通知の文言表（8章）を更新する。

---

## 4. キーの命名規約

ARBのキーは、使う画面の画面IDに対応する接頭辞を付ける。

| 接頭辞 | 対象 | 例 |
|---|---|---|
| `common*` | 複数の画面で共通する文言（ボタン・共通のエラー・ブロックの確認等） | `commonCancel`, `commonSave`, `commonUnknownAccount`, `commonBlockConfirmTitle` |
| `auth*` | AUT-02・AUT-03（電話番号・認証コードの入力、国・地域の選択） | `authNextButton`, `authErrorInvalidPhoneNumber` |
| `phoneChange*` | AUT-02の電話番号の変更モード | `phoneChangeTitle`, `phoneChangeCompleted` |
| `passcode*` | AUT-04・SET-03（パスコードの入力・設定） | `passcodeEnterTitle`, `passcodeWrong` |
| `transferPassword*` | AUT-05・SET-05（引き継ぎパスワードの入力・設定）、最初のアカウント作成後の案内 | `transferPasswordEntryTitle`, `transferPasswordErrorWrong` |
| `acc*` | ACC-01〜03（アカウント一覧・作成・削除） | `accListEmpty`, `accCreationIdTaken`, `accDeletionConfirmMessage` |
| `cha*` | CHA-01〜03（チャット一覧・チャット画面・画像の全画面表示） | `chaReadLabel`, `chaListEmpty`, `chaImageSaved` |
| `fri*` | FRI-01〜04（友だち一覧・追加メニュー・招待・検索） | `friListEmpty`, `friInviteMessage` |
| `qrc*` | QRC-01（QRコード画面） | `qrcShareButton` |
| `pro*` | PRO-01〜03（プロフィールの表示・編集） | `proNicknameDialogTitle`, `proEditAllowIdSearchTitle` |
| `set*` | SET-01・SET-02（設定画面・ブロックリスト） | `setContactTile`, `setLanguageTile`, `setBlockListEmpty` |
| `language*`・`displayMode*` | SET-01の言語・画面モードの選択肢 | `languageJapanese`, `displayModeDark` |
| `plan*` | SET-01のプラン名 | `planNameFree` |
| `withdrawal*` | SET-04（退会） | `withdrawalTitle`, `withdrawalFailed` |
| `appHomeHeader*`・`addMenu*` | 共通ヘッダー（`AppHomeHeader`）と＋メニュー | `appHomeHeaderChatTitle`, `addMenuAddFriend` |
| `bottomNav*` | ボトムナビゲーション | `bottomNavChatTab` |
| `push*` | アプリを開いているときの新着のアプリ内バナー | `pushNewMessageBanner` |
| `startupErrorTitle`・`accountFetchFailed` | 起動時のエラー（`bootstrap.dart`・`app.dart`。特定の画面に属さない） | － |

複数の画面で使う文言は`common*`にまとめ、同じ文言のキーを画面ごとに作らない。新しい文言を追加する際は、まず`common*`で流用できないかを確認する。

---

## 5. プレースホルダー

値を埋め込む文言は、文字列の連結ではなく、ARBのプレースホルダーを使う。

```json
"authVerificationSentTo": "{phoneNumber} に送信しました",
"@authVerificationSentTo": {
  "description": "AUT-03：送信先電話番号の案内",
  "placeholders": { "phoneNumber": { "type": "String" } }
}
```

プレースホルダーを使っているキー：

| キー | プレースホルダー |
|---|---|
| `authVerificationSentTo` | `phoneNumber`（String） |
| `authResendCodeCooldown` | `seconds`（int） |
| `accountFetchFailed` | `error`（String） |
| `accListLimitMessage` | `limit`（int） |
| `friInviteMessage` | `accountId`（String） |
| `chaRequestSectionTitle` | `count`（int） |

プレースホルダーを持つキーは、生成コードでは引数付きのメソッドになる。

```dart
Text(l10n.authResendCodeCooldown(state.cooldownSeconds))
```

---

## 6. ViewModel・Model層での文言の扱い

ViewModel・Service・Model層は表示文言を持たない。エラーは種別（enum）やエラーの有無として返すか、文言を呼び出し元のViewから引数で受け取り、文言への変換はViewで`AppLocalizations`を使って行う。

### 6.1 エラー種別（enum）で返す

エラーの種類によって表示を変える場合は、enumで返し、Viewで文言に変換する。

| enum | 定義 | Viewへの渡し方 | 文言への変換 |
|---|---|---|---|
| `AuthErrorCode` | `lib/domain/models/auth_error_code.dart` | `PhoneInputState`・`VerificationCodeState`・`PasscodeEntryState`の`errorCode` | `localizedAuthError()`（`lib/ui/auth/widgets/auth_error_localization.dart`。AUT-02・AUT-03・AUT-04で共用） |
| `TransferPasswordError` | `lib/domain/models/transfer_password_error.dart` | `AsyncError`（`TransferPasswordException`）。`transferPasswordErrorOf()`で取り出す | `localizedTransferPasswordError()`（`lib/ui/auth/widgets/transfer_password_error_localization.dart`。AUT-05・SET-05で共用） |
| `AccountCreationError` | `lib/ui/account/view_models/account_creation_viewmodel.dart` | `AccountCreationData.errorCode` | ACC-02の画面内 |
| `FriendSearchError` | `lib/ui/friend/view_models/friend_search_viewmodel.dart` | `AsyncError`の値 | FRI-04の画面内 |
| `QrScanError` | `lib/ui/qr/view_models/qr_scan_viewmodel.dart` | `QrScanState`の`error` | QRC-01の画面内 |

Firebase Authenticationのエラーから`AuthErrorCode`への変換は`AuthRepository`（`lib/data/repositories/auth/auth_repository.dart`）が行い、ViewModelには`AuthErrorCode`（失敗時は`AuthException`）として返す。

```dart
// lib/ui/auth/widgets/auth_error_localization.dart
switch (code) {
  case AuthErrorCode.invalidPhoneNumber:
    return l10n.authErrorInvalidPhoneNumber;
  ...
}
```

### 6.2 エラーの有無だけを返す

エラーが1種類しかない場合は、enumを作らず、Viewが`AsyncValue.hasError`を見て共通の文言を表示する（例：`AccountDeletionViewModel`→`accDeletionFailedGeneric`、`WithdrawalViewModel`→`withdrawalFailed`）。

### 6.3 文言を引数で受け取る

多くの画面から使うModel層の関数で、文言が必要な場合は、呼び出し元のViewから必須引数で受け取る（例：`lib/domain/models/account.dart`の`resolveDisplayName()`。「不明なアカウント」（`commonUnknownAccount`）・「退会済みアカウント」（`commonDeletedAccount`）を受け取る）。

```dart
String resolveDisplayName(
  Account? account, {
  String? nickname,
  required String unknownAccountLabel,
  required String deletedAccountLabel,
}) { ... }
```

### 6.4 画面に属さない出来事から出す表示

FCMのフォアグラウンド受信（`lib/ui/notification/view_models/push_notification_init.dart`）は特定の画面に属さないが、ViewModel側は受信回数（`foregroundMessageCountProvider`）を増やすだけで、文言は扱わない。`MaterialApp`配下の`_AccountGate`（`lib/app.dart`）がこの変化を`ref.listen`し、自分の`context`で`showNewMessageBanner`（`lib/ui/core/ui/new_message_banner.dart`）を呼んで、`AppLocalizations.of(context)`から文言を解決する。

---

## 7. 日付・時刻の表示

日付・時刻は`lib/utils/date_format_utils.dart`の関数で整形する。表示言語は、Viewが`AppLocalizations.of(context)!.localeName`を渡す。日本語は日本で一般的な書式を関数内で指定し、英語は`intl`の表示言語の書式（`DateFormat.jm`・`MMMd`・`yMMMd`）を使う。

| 関数 | 使う画面 | 表示 |
|---|---|---|
| `formatChatTimestamp` | CHA-01（最新メッセージの日時） | 今日は時刻（`formatMessageTime`と同じ）、昨日は「昨日」（`chaListYesterday`）、7日以内は曜日（表示言語の書式）、それより前は月日（日本語は`09/18`、英語は`Sep 18`） |
| `formatMessageTime` | CHA-02（メッセージの時刻）・CHA-03 | 日付に関わらず時刻だけ。日本語は24時間表記の`15:05`、英語は`3:05 PM` |
| `formatDateDividerLabel` | CHA-02（日付の区切り）・CHA-03 | 日本語は`2026年9月18日(金)`の形式、英語は表示言語の書式（例：`Sep 18, 2026`） |

---

## 8. プッシュ通知の文言

OSが表示するプッシュ通知の文言は、アプリではなくCloud Functionsが決める。

- アプリは、FCMトークンを登録する際に表示言語を一緒に保存する（`accounts/{accountId}/fcmTokens`の`language`、データ設計書3.2.2）。表示言語を変えたときも登録し直す。
- Cloud Functionsは、`firebase/functions/index.js`の`NOTIFICATION_BODIES`（`ja`・`en`）から、トークンの`language`の文言を選ぶ。未知の値は日本語にする。
- 文言はARBの`pushNewMessageBanner`（アプリ内バナー）と揃える。言語・文言を変える際は両方を更新する。

---

## 9. iOSの権限ダイアログの文言

カメラ・写真ライブラリの使用許可を求めるダイアログの文言（利用目的）は、アプリではなくiOSが表示する。そのため、ARBではなく`ios/Runner`の`InfoPlist.strings`で言語ごとに持つ。

| キー | 用途 |
|---|---|
| `NSCameraUsageDescription` | プロフィール写真・トークで送る写真の撮影、QRコードの読み取り |
| `NSPhotoLibraryUsageDescription` | プロフィール写真・トークで送る写真の選択 |
| `NSPhotoLibraryAddUsageDescription` | トークの画像の写真ライブラリへの保存 |

- 文言：`ios/Runner/ja.lproj/InfoPlist.strings`（日本語）・`ios/Runner/en.lproj/InfoPlist.strings`（英語）
- `Info.plist`の同じキーには日本語の文言を置く（既定値）。
- `Info.plist`の`CFBundleLocalizations`に`en`・`ja`を列挙し、iOSとApp Storeにアプリの対応言語を伝える。
- iOSは端末の言語（または「設定」アプリでこのアプリに選んだ言語）で文言を選ぶ。アプリ内の表示言語の切り替え（SET-01）は、この文言には反映されない。
- 文言を変える際は、`Info.plist`と2つの`InfoPlist.strings`をすべて更新する。

---

## 10. 用語の統一

表記ゆれを防ぐため、次の用語は統一する。ARBは以下のルールに沿っている。

| 対象 | 統一する表記 | 使わない表記 |
|---|---|---|
| トーク（CHA-01・CHA-02の画面・機能の呼び名、日本語） | 「トーク」 | 「チャット」 |
| Chat（同上、英語） | 「Chat」 | 「Talk」「Talks」 |
| 友だち（日本語） | 「友だち」（ひらがな） | 「友達」「フレンド」 |

「メッセージ」（`chaMessageInputHint`等、個々のメッセージを指す文言）は、トークという画面・機能の呼び名とは別のため、この統一の対象外とする。
