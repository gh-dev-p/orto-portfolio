import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('ja')];

  /// AppHomeHeaderのタイトル（CHA-01：トーク一覧画面）
  ///
  /// In ja, this message translates to:
  /// **'トーク'**
  String get appHomeHeaderChatTitle;

  /// AppHomeHeaderのタイトル（FRI-01：友だち一覧画面）
  ///
  /// In ja, this message translates to:
  /// **'友だち'**
  String get appHomeHeaderFriendTitle;

  /// AppHomeHeaderのタイトル（SET-01：設定画面）
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get appHomeHeaderSettingsTitle;

  /// 友だち追加のボタンの文言
  ///
  /// In ja, this message translates to:
  /// **'友だち追加'**
  String get addMenuAddFriend;

  /// AppHomeHeaderの＋メニュー項目：友だち追加（項目の幅に合わせて2行にする）
  ///
  /// In ja, this message translates to:
  /// **'友だち\n追加'**
  String get addMenuAddFriendLabel;

  /// AppHomeHeaderの＋メニュー項目：グループ作成（項目の幅に合わせて2行にする）
  ///
  /// In ja, this message translates to:
  /// **'グループ\n作成'**
  String get addMenuCreateGroupLabel;

  /// AppHomeHeaderの＋メニュー項目：招待（FRI-03）
  ///
  /// In ja, this message translates to:
  /// **'招待'**
  String get addMenuInvite;

  /// AppHomeHeaderの＋メニュー項目：トークルーム作成
  ///
  /// In ja, this message translates to:
  /// **'トークルーム作成'**
  String get addMenuCreateChat;

  /// グループ作成のボタン・見出しの文言
  ///
  /// In ja, this message translates to:
  /// **'グループ作成'**
  String get addMenuCreateGroup;

  /// SET-01の言語設定項目ラベル
  ///
  /// In ja, this message translates to:
  /// **'言語'**
  String get setLanguageTile;

  /// 言語選択肢：日本語
  ///
  /// In ja, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// 言語選択肢：英語
  ///
  /// In ja, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// SET-01の画面モード（ライト／ダーク）設定項目ラベル
  ///
  /// In ja, this message translates to:
  /// **'画面モード'**
  String get setDisplayModeTile;

  /// 画面モード選択肢：常にライト
  ///
  /// In ja, this message translates to:
  /// **'ライトモード'**
  String get displayModeLight;

  /// 画面モード選択肢：常にダーク
  ///
  /// In ja, this message translates to:
  /// **'ダークモード'**
  String get displayModeDark;

  /// 画面モードのダイアログ：ライトの見本の下の名前
  ///
  /// In ja, this message translates to:
  /// **'ライト'**
  String get displayModeLightShort;

  /// 画面モードのダイアログ：ダークの見本の下の名前
  ///
  /// In ja, this message translates to:
  /// **'ダーク'**
  String get displayModeDarkShort;

  /// 画面モード選択肢：端末の設定に合わせる
  ///
  /// In ja, this message translates to:
  /// **'端末の設定に従う'**
  String get displayModeSystem;

  /// 共通：キャンセルボタン
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get commonCancel;

  /// 共通：保存ボタン
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// 共通：閉じるボタン
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get commonClose;

  /// 共通：検索ボタン・ラベル
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get commonSearch;

  /// 共通：再試行ボタン（スプラッシュ画面）
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get commonRetry;

  /// 共通：一覧取得失敗時の再読み込みボタン（ErrorRetryView）
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get commonReload;

  /// 共通：読み込み中の文言（スプラッシュ画面で起動処理が長引いた場合に表示）
  ///
  /// In ja, this message translates to:
  /// **'読み込み中…'**
  String get commonLoading;

  /// 共通：画像選択メニューのカメラ項目
  ///
  /// In ja, this message translates to:
  /// **'カメラで撮影'**
  String get commonPickCamera;

  /// 共通：画像選択メニューのギャラリー項目
  ///
  /// In ja, this message translates to:
  /// **'ギャラリーから選択'**
  String get commonPickGallery;

  /// 共通：画像選択（カメラ撮影）で、カメラの権限が拒否されている場合のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'カメラの利用が許可されていません。端末の設定アプリからカメラへのアクセスを許可してください。'**
  String get commonPickCameraDenied;

  /// 共通：画像選択（アルバム）で、写真の権限が拒否されている場合のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'写真へのアクセスが許可されていません。端末の設定アプリから写真へのアクセスを許可してください。'**
  String get commonPickPhotoDenied;

  /// 共通：画像選択が権限拒否以外の理由で失敗した場合のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'画像を選択できませんでした。もう一度お試しください'**
  String get commonPickFailed;

  /// 共通：表示名入力欄のラベル
  ///
  /// In ja, this message translates to:
  /// **'表示名'**
  String get commonDisplayNameLabel;

  /// 共通：アカウントID入力欄のラベル
  ///
  /// In ja, this message translates to:
  /// **'アカウントID'**
  String get commonAccountIdLabel;

  /// 共通：表示名入力欄の中の薄い見本（ヒント）
  ///
  /// In ja, this message translates to:
  /// **'表示名を入力'**
  String get commonDisplayNameHint;

  /// 共通：アカウントID入力欄の中の薄い見本（ヒント）
  ///
  /// In ja, this message translates to:
  /// **'アカウントIDを入力'**
  String get commonAccountIdHint;

  /// AUT-02：電話番号入力画面のタイトル
  ///
  /// In ja, this message translates to:
  /// **'電話番号を入力してください'**
  String get authPhoneInputTitle;

  /// AUT-02：次へボタン
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get authNextButton;

  /// AUT-02：サインイン時に次へボタンの下へ出す同意の案内（変更モードでは出さない）。リンクはsetTermsOfServiceTile・setPrivacyPolicyTileを使う
  ///
  /// In ja, this message translates to:
  /// **'「次へ」を押すと、利用規約とプライバシーポリシーに同意したものとします。'**
  String get authLegalConsentNotice;

  /// AUT-03：認証コード再送成功時のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'認証コードを再送しました'**
  String get authVerificationResentSnackbar;

  /// AUT-03：認証コード入力画面のタイトル
  ///
  /// In ja, this message translates to:
  /// **'認証コードを入力してください'**
  String get authVerificationTitle;

  /// AUT-03：送信先電話番号の案内
  ///
  /// In ja, this message translates to:
  /// **'{phoneNumber} に送信しました'**
  String authVerificationSentTo(String phoneNumber);

  /// AUT-03：認証コード3回連続失敗時の案内
  ///
  /// In ja, this message translates to:
  /// **'認証コードが繰り返し一致しません。コードを再送してください'**
  String get authVerificationRepeatedFailure;

  /// AUT-03：再送ボタン（クールダウン明け）
  ///
  /// In ja, this message translates to:
  /// **'コードを再送する'**
  String get authResendCode;

  /// AUT-03：再送ボタン（クールダウン中）
  ///
  /// In ja, this message translates to:
  /// **'コードを再送する（{seconds}秒後に可能）'**
  String authResendCodeCooldown(int seconds);

  /// AUT-03：確認ボタン
  ///
  /// In ja, this message translates to:
  /// **'確認'**
  String get authConfirmButton;

  /// AUT-02：電話番号の形式エラー（AuthErrorCode.invalidPhoneNumber）
  ///
  /// In ja, this message translates to:
  /// **'電話番号の形式が正しくありません'**
  String get authErrorInvalidPhoneNumber;

  /// AUT-02/03：レート制限エラー（AuthErrorCode.tooManyRequests）
  ///
  /// In ja, this message translates to:
  /// **'リクエストが多すぎます。しばらく時間をおいて再度お試しください'**
  String get authErrorTooManyRequests;

  /// AUT-02/03：通信エラー（AuthErrorCode.network、既定のフォールバックにも使用）
  ///
  /// In ja, this message translates to:
  /// **'通信エラーが発生しました。再度お試しください'**
  String get authErrorNetwork;

  /// AUT-03：認証コード不一致（AuthErrorCode.invalidVerificationCode）
  ///
  /// In ja, this message translates to:
  /// **'認証コードが一致しません'**
  String get authErrorInvalidVerificationCode;

  /// AUT-03：認証コード期限切れ（AuthErrorCode.codeExpired）
  ///
  /// In ja, this message translates to:
  /// **'コードの有効期限が切れました'**
  String get authErrorCodeExpired;

  /// AUT-02/03：サインイン失敗（AuthErrorCode.signInFailed）
  ///
  /// In ja, this message translates to:
  /// **'サインインに失敗しました'**
  String get authErrorSignInFailed;

  /// 共通：自分自身のIDを検索／QR読取した場合のエラー
  ///
  /// In ja, this message translates to:
  /// **'自分自身は追加できません'**
  String get commonSelfAddNotAllowed;

  /// ACC-02：作成直前の競合で他ユーザーに先に使用された場合のエラー（AccountCreationError.idTaken）
  ///
  /// In ja, this message translates to:
  /// **'このIDは他の方に使用されました。別のIDを入力してください'**
  String get accCreationIdTakenOnSubmit;

  /// ACC-02：アカウント作成時に画像のアップロードだけ失敗した場合のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'画像のアップロードに失敗しました。アカウントは画像なしで作成されました'**
  String get accCreationImageUploadFailed;

  /// ACC-02：アカウント作成失敗時の汎用エラー（AccountCreationError.unknown）
  ///
  /// In ja, this message translates to:
  /// **'作成に失敗しました。再度お試しください'**
  String get accCreationFailedGeneric;

  /// ACC-03：アカウント削除失敗時のエラー
  ///
  /// In ja, this message translates to:
  /// **'削除に失敗しました。再度お試しください'**
  String get accDeletionFailedGeneric;

  /// FRI-04：検索失敗時のエラー（FriendSearchError.searchFailed）
  ///
  /// In ja, this message translates to:
  /// **'検索に失敗しました。再度お試しください'**
  String get friSearchFailed;

  /// FRI-04：該当ユーザーなし（FriendSearchError.notFound）
  ///
  /// In ja, this message translates to:
  /// **'該当するアカウントが見つかりません'**
  String get friSearchNotFound;

  /// QRC-01：読み取ったQRコードに該当するAccountが見つからない場合のエラー（QrScanError.notFound）
  ///
  /// In ja, this message translates to:
  /// **'QRコードを読み取れませんでした'**
  String get qrcScanNotFound;

  /// フォアグラウンド受信時のプッシュ通知バナー本文（機能仕様書4.4.6.2）
  ///
  /// In ja, this message translates to:
  /// **'新規メッセージがあります'**
  String get pushNewMessageBanner;

  /// フォアグラウンドでリアクションの通知を受信したときのバナー本文。Cloud FunctionsのREACTION_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'メッセージにリアクションがありました'**
  String get pushReactionBanner;

  /// bootstrap.dart：Firebase初期化失敗時のフォールバック画面タイトル
  ///
  /// In ja, this message translates to:
  /// **'アプリを起動できませんでした'**
  String get startupErrorTitle;

  /// bootstrap.dart：Firebase初期化失敗時のフォールバック画面の案内（例外の文は出さない）
  ///
  /// In ja, this message translates to:
  /// **'通信環境を確かめて、アプリを起動し直してください。'**
  String get startupErrorMessage;

  /// AUT-01：ログイン済みUserのAccount一覧取得失敗時のエラーメッセージ（例外の文は出さない）
  ///
  /// In ja, this message translates to:
  /// **'アカウント情報を読み込めませんでした。通信環境を確かめて、もう一度お試しください。'**
  String get accountFetchFailedMessage;

  /// ACC-02：アカウント作成画面のAppBarタイトル（アカウントの一覧を読み込めていないとき）
  ///
  /// In ja, this message translates to:
  /// **'アカウント作成'**
  String get accCreationTitle;

  /// ACC-02：アカウント作成画面のAppBarタイトル。numberは作るアカウントが何件目になるか
  ///
  /// In ja, this message translates to:
  /// **'{number}つ目のアカウントを作成'**
  String accCreationNumberedTitle(String number);

  /// ACC-02：画像選択ボタン（アバター下）
  ///
  /// In ja, this message translates to:
  /// **'画像を選択'**
  String get accCreationPickImageButton;

  /// ACC-02：表示名の文字数エラー
  ///
  /// In ja, this message translates to:
  /// **'表示名は1〜20文字で入力してください'**
  String get accCreationDisplayNameLengthError;

  /// ACC-02：アカウントID使用可能確認ボタン
  ///
  /// In ja, this message translates to:
  /// **'使用可能か確認'**
  String get accCreationCheckAvailability;

  /// ACC-02：アカウントID変更不可の注意書き
  ///
  /// In ja, this message translates to:
  /// **'※アカウントIDは作成後に変更・削除できません'**
  String get accCreationIdImmutableNote;

  /// ACC-02：作成ボタン
  ///
  /// In ja, this message translates to:
  /// **'作成する'**
  String get accCreationSubmitButton;

  /// ACC-02：ID入力欄が空の時の形式ヒント
  ///
  /// In ja, this message translates to:
  /// **'半角英数字・記号（. - _）のみ、4〜20文字'**
  String get accCreationIdHintFormat;

  /// ACC-02：ID形式エラー
  ///
  /// In ja, this message translates to:
  /// **'半角英数字・記号（. - _）のみ、4〜20文字で入力してください'**
  String get accCreationIdFormatError;

  /// ACC-02：ID使用可能確認中の表示
  ///
  /// In ja, this message translates to:
  /// **'確認中...'**
  String get accCreationIdChecking;

  /// ACC-02：ID使用可能
  ///
  /// In ja, this message translates to:
  /// **'✓ 使用可能です'**
  String get accCreationIdAvailable;

  /// ACC-02：ID使用不可（既に使用済み）
  ///
  /// In ja, this message translates to:
  /// **'このIDは既に使用されています'**
  String get accCreationIdTaken;

  /// ACC-02：ID使用不可（運営用の予約ID）
  ///
  /// In ja, this message translates to:
  /// **'このIDは使用できません'**
  String get accCreationIdReserved;

  /// ACC-02：ID未確認時のヒント
  ///
  /// In ja, this message translates to:
  /// **'「使用可能か確認」で確認できます（未確認でも作成は可能です）'**
  String get accCreationIdCheckHint;

  /// ACC-03：アカウント削除画面のAppBarタイトル／ACC-01メニュー項目
  ///
  /// In ja, this message translates to:
  /// **'アカウント削除'**
  String get accDeletionTitle;

  /// ACC-03：削除確認メッセージ
  ///
  /// In ja, this message translates to:
  /// **'このアカウントを削除しますか？\n表示名、一言コメント、プロフィール画像、背景画像と、友だち・ブロック・トーク一覧の情報を削除します。相手には「退会済みアカウント」として表示されます。\n送ったメッセージは、相手のトーク履歴に残ります。\n短い期間に削除を繰り返すと、しばらく新しいアカウントを作れなくなります。\n\n※削除後は、このIDを使って新しいアカウントを作成できません。'**
  String get accDeletionConfirmMessage;

  /// ACC-03：削除ボタン
  ///
  /// In ja, this message translates to:
  /// **'削除する'**
  String get accDeletionSubmitButton;

  /// ACC-01：一覧取得失敗時のエラーメッセージ
  ///
  /// In ja, this message translates to:
  /// **'アカウント一覧の取得に失敗しました'**
  String get accListLoadError;

  /// ACC-01：アカウント0件時の空状態表示
  ///
  /// In ja, this message translates to:
  /// **'アカウントがありません'**
  String get accListEmpty;

  /// ACC-01：使用中のアカウントの行のボタン（PRO-02を開く）
  ///
  /// In ja, this message translates to:
  /// **'プロフィール'**
  String get accListProfileButton;

  /// ACC-01：一覧見出し（従来は英語ベタ書きの'Account'固定だった）
  ///
  /// In ja, this message translates to:
  /// **'アカウント'**
  String get accListHeaderTitle;

  /// 共通：相手Accountが取得できなかった場合の表示名フォールバック
  ///
  /// In ja, this message translates to:
  /// **'不明なアカウント'**
  String get commonUnknownAccount;

  /// 共通：相手Accountがソフトデリート済みの場合の表示名フォールバック
  ///
  /// In ja, this message translates to:
  /// **'退会済みアカウント'**
  String get commonDeletedAccount;

  /// 共通：送信失敗時のSnackBarメッセージ
  ///
  /// In ja, this message translates to:
  /// **'送信に失敗しました。再度お試しください'**
  String get commonSendFailedRetry;

  /// CHA-02：メッセージ一覧取得失敗時のエラーメッセージ
  ///
  /// In ja, this message translates to:
  /// **'メッセージの取得に失敗しました'**
  String get chaMessagesLoadError;

  /// CHA-02：メッセージ0件時の空状態表示
  ///
  /// In ja, this message translates to:
  /// **'まだメッセージがありません'**
  String get chaEmptyMessages;

  /// CHA-01：トーク一覧で、最新メッセージが前日のときの日時表示
  ///
  /// In ja, this message translates to:
  /// **'昨日'**
  String get chaListYesterday;

  /// CHA-02：送信失敗メッセージの再送アイコンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'タップで再送'**
  String get chaRetryTooltip;

  /// CHA-02：既読ラベル
  ///
  /// In ja, this message translates to:
  /// **'既読'**
  String get chaReadLabel;

  /// CHA-02：メッセージ入力欄のヒントテキスト（従来は英語ベタ書きの'Write a message...'固定だった）
  ///
  /// In ja, this message translates to:
  /// **'メッセージを入力'**
  String get chaMessageInputHint;

  /// CHA-02：メッセージ長押しメニューの送信取消（Unsend）項目
  ///
  /// In ja, this message translates to:
  /// **'送信取消'**
  String get chaMessageActionUnsend;

  /// CHA-02：メッセージ長押しメニューの削除項目
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get chaMessageActionDelete;

  /// CHA-02：送信取消確認ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'送信を取り消しますか？'**
  String get chaUnsendConfirmTitle;

  /// CHA-02：送信取消確認ダイアログの本文
  ///
  /// In ja, this message translates to:
  /// **'取り消すと、自分と相手の画面からメッセージが消えます。この操作は元に戻せません。なお、内容は不正利用の調査などのため、運営者だけが確認できる場所に一定期間保管されます。'**
  String get chaUnsendConfirmMessage;

  /// CHA-02：送信取消処理が失敗した場合のSnackBarメッセージ
  ///
  /// In ja, this message translates to:
  /// **'送信取消に失敗しました'**
  String get chaUnsendFailed;

  /// CHA-02：削除確認ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'メッセージを削除しますか？'**
  String get chaDeleteConfirmTitle;

  /// CHA-02：削除確認ダイアログの本文
  ///
  /// In ja, this message translates to:
  /// **'削除すると、自分の画面からのみメッセージが消えます。相手の画面には残ります。'**
  String get chaDeleteConfirmMessage;

  /// CHA-02：削除処理が失敗した場合のSnackBarメッセージ
  ///
  /// In ja, this message translates to:
  /// **'削除に失敗しました'**
  String get chaDeleteFailed;

  /// CHA-02：リアクション追加・変更が失敗した場合のSnackBarメッセージ
  ///
  /// In ja, this message translates to:
  /// **'リアクションに失敗しました'**
  String get chaReactionFailed;

  /// CHA-02：メッセージ長押しメニューのコピー項目
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get chaMessageActionCopy;

  /// CHA-02：メッセージ長押しメニューの部分コピー項目
  ///
  /// In ja, this message translates to:
  /// **'部分コピー'**
  String get chaMessageActionPartialCopy;

  /// CHA-01：トーク一覧取得失敗時のエラーメッセージ
  ///
  /// In ja, this message translates to:
  /// **'トーク一覧の取得に失敗しました'**
  String get chaListLoadError;

  /// CHA-01：トーク0件時の空状態表示
  ///
  /// In ja, this message translates to:
  /// **'まだトークがありません。\n友だちを追加するとここに表示されます。'**
  String get chaListEmpty;

  /// ボトムナビ：トークタブのラベル
  ///
  /// In ja, this message translates to:
  /// **'トーク'**
  String get bottomNavChatTab;

  /// ボトムナビ：友だちタブのラベル
  ///
  /// In ja, this message translates to:
  /// **'友だち'**
  String get bottomNavFriendTab;

  /// ボトムナビ：設定タブのラベル
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get bottomNavSettingsTab;

  /// 共通：未実装の選択肢をタップした際のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'今後リリース予定です'**
  String get commonComingSoon;

  /// FRI-01：友だち一覧取得失敗時のエラーメッセージ
  ///
  /// In ja, this message translates to:
  /// **'友だち一覧の取得に失敗しました'**
  String get friListLoadError;

  /// FRI-01：友だち0件時の空状態表示
  ///
  /// In ja, this message translates to:
  /// **'まだ友だちがいません。\nアカウントIDで検索して友だちを追加しましょう。'**
  String get friListEmpty;

  /// FRI-01：フィルタタブのラベル（現状Groupsタブは非表示のため実質1個のみ表示）
  ///
  /// In ja, this message translates to:
  /// **'友だち'**
  String get friFilterTabLabel;

  /// FRI-01：Groupsフィルタタブのラベル（_showGroupsTabがtrueのときのみ表示）
  ///
  /// In ja, this message translates to:
  /// **'グループ'**
  String get friFilterGroupsTabLabel;

  /// FRI-04：検索画面のAppBarタイトル
  ///
  /// In ja, this message translates to:
  /// **'友だちを検索'**
  String get friSearchTitle;

  /// FRI-02：友だち追加メニューシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'友だちを追加'**
  String get friAddMenuTitle;

  /// FRI-02：QRコードメニュー項目のラベル
  ///
  /// In ja, this message translates to:
  /// **'QRコード'**
  String get friAddMenuQrCode;

  /// FRI-03：共有シートで送る招待文（{link}は招待リンク）。受け取る側の目線で、グループの招待文（grpInviteShareMessage）と口調をそろえる
  ///
  /// In ja, this message translates to:
  /// **'Ortoで友だちになりませんか？\n下のリンクを開くと、友だちに追加できます。Ortoは、電話番号やLINEを相手に教えずにやりとりできるアプリです。\n{link}\n\nアプリが開かないときは、ID「{accountId}」で検索してください。'**
  String friInviteMessage(String accountId, String link);

  /// FRI-03：「IDで検索されない」アカウント（allowIdSearch=false）の招待文。検索では見つからないため、friInviteMessageからIDで検索する案内を除いたもの
  ///
  /// In ja, this message translates to:
  /// **'Ortoで友だちになりませんか？\n下のリンクを開くと、友だちに追加できます。Ortoは、電話番号やLINEを相手に教えずにやりとりできるアプリです。\n{link}'**
  String friInviteMessageNoSearch(String link);

  /// FRI-03：招待文の共有失敗時のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'招待の共有に失敗しました'**
  String get friInviteShareFailed;

  /// 招待リンクから開いたが、自分のアカウントの招待だった場合のSnackBar（InviteLinkError.selfAdd）
  ///
  /// In ja, this message translates to:
  /// **'自分の招待リンクです'**
  String get friInviteLinkSelf;

  /// 招待リンクから開いたが、招待したアカウントが見つからない場合のSnackBar（InviteLinkError.notFound）
  ///
  /// In ja, this message translates to:
  /// **'招待したアカウントが見つかりませんでした'**
  String get friInviteLinkNotFound;

  /// 共通：値が未設定であることを表す表示
  ///
  /// In ja, this message translates to:
  /// **'未設定'**
  String get commonUnset;

  /// 共通：アカウントIDコピー成功時のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'IDをコピーしました'**
  String get commonIdCopied;

  /// 共通：テキストのコピー完了時のSnackBar（画面設計書5.3.2。画面固有キーから汎用キーに統一）
  ///
  /// In ja, this message translates to:
  /// **'コピーしました'**
  String get commonCopied;

  /// 共通：マイQRコードへの導線ラベル
  ///
  /// In ja, this message translates to:
  /// **'マイQRコード'**
  String get commonMyQrCode;

  /// PRO-01：友だち追加失敗時のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'追加に失敗しました。再度お試しください'**
  String get proFriendAddFailed;

  /// PRO-01：ニックネーム編集ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'ニックネームを設定'**
  String get proNicknameDialogTitle;

  /// PRO-01：ニックネーム入力欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'未設定にするには空欄のまま保存'**
  String get proNicknameDialogHint;

  /// PRO-01：ニックネームの保存に失敗した際のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'ニックネームの保存に失敗しました。再度お試しください'**
  String get proNicknameSaveFailed;

  /// PRO-03：画像アップロード失敗時のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'画像の保存に失敗しました。再度お試しください'**
  String get proEditImageSaveFailed;

  /// PRO-03：表示名編集ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'表示名を編集'**
  String get proEditNameDialogTitle;

  /// PRO-03：表示名保存失敗時のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'表示名の保存に失敗しました。再度お試しください'**
  String get proEditNameSaveFailed;

  /// PRO-03：ひとこと行のラベル
  ///
  /// In ja, this message translates to:
  /// **'ひとこと'**
  String get proEditBioLabel;

  /// PRO-03：ひとこと編集ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'ひとことを編集'**
  String get proEditBioDialogTitle;

  /// PRO-03：ひとこと入力欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'ひとことを入力'**
  String get proEditBioHint;

  /// PRO-03：ひとこと保存失敗時のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'ひとことの保存に失敗しました。再度お試しください'**
  String get proEditBioSaveFailed;

  /// PRO-03：IDによる友だち追加許可トグル保存失敗時のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'設定の保存に失敗しました。再度お試しください'**
  String get proEditSettingsSaveFailed;

  /// PRO-03：AppBarタイトル
  ///
  /// In ja, this message translates to:
  /// **'メインプロフィール'**
  String get proEditAppBarTitle;

  /// PRO-03：IDによる友だち追加許可トグルのラベル
  ///
  /// In ja, this message translates to:
  /// **'IDによる友だち追加を許可'**
  String get proEditAllowIdSearchTitle;

  /// PRO-03：IDによる友だち追加許可トグルの説明文
  ///
  /// In ja, this message translates to:
  /// **'オンにすると、ほかの人がIDで検索して友だちに追加できます。オフでも、あなたが渡したQRコード・招待リンクからは追加できます。'**
  String get proEditAllowIdSearchSubtitle;

  /// QRC-01：アルバム画像からQRコードを検出できなかった場合のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'QRコードを検出できませんでした'**
  String get qrcDetectFailed;

  /// QRC-01：下部トグルの「読み取り」モードラベル
  ///
  /// In ja, this message translates to:
  /// **'読み取り'**
  String get qrcSegmentScan;

  /// QRC-01：カメラ枠内の案内テキスト
  ///
  /// In ja, this message translates to:
  /// **'QRコードを枠内に合わせてください'**
  String get qrcOverlayHint;

  /// QRC-01：カメラ権限拒否時のエラーメッセージ
  ///
  /// In ja, this message translates to:
  /// **'カメラの利用が許可されていません。端末の設定アプリからカメラへのアクセスを許可してください。'**
  String get qrcCameraPermissionDenied;

  /// QRC-01：カメラ利用不可時のエラーメッセージ（権限拒否以外）
  ///
  /// In ja, this message translates to:
  /// **'カメラを利用できませんでした。'**
  String get qrcCameraUnavailable;

  /// QRC-01：マイQRコード共有失敗時のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'共有に失敗しました'**
  String get qrcShareFailed;

  /// QRC-01：QRコード生成失敗時のエラーメッセージ
  ///
  /// In ja, this message translates to:
  /// **'QRコードの生成に失敗しました'**
  String get qrcGenerateFailed;

  /// QRC-01：共有ボタンのラベル
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get qrcShareButton;

  /// QRC-01：IDコピーボタンのラベル
  ///
  /// In ja, this message translates to:
  /// **'IDをコピー'**
  String get qrcCopyIdButton;

  /// SET-01：パスコードロックのON/OFFトグル項目のラベル（現在アクティブなアカウントが対象）
  ///
  /// In ja, this message translates to:
  /// **'パスコードロック'**
  String get setPasscodeTile;

  /// AUT-04：起動時・アカウント切替時のガードでの見出し
  ///
  /// In ja, this message translates to:
  /// **'パスコードを入力'**
  String get passcodeEnterTitle;

  /// AUT-04：SET-01でパスコードをOFFにする際の本人確認（確認モード）の見出し
  ///
  /// In ja, this message translates to:
  /// **'現在のパスコードを入力'**
  String get passcodeConfirmCurrentTitle;

  /// AUT-04：パスコード誤入力時のエラー表示
  ///
  /// In ja, this message translates to:
  /// **'パスコードが違います。もう一度入力してください'**
  String get passcodeWrong;

  /// AUT-04：誤りが続いた後の待ち時間の案内（秒）
  ///
  /// In ja, this message translates to:
  /// **'続けて間違えたため、あと{seconds}秒お待ちください'**
  String passcodeWaitSeconds(int seconds);

  /// AUT-04：誤りが続いた後の待ち時間の案内（分）
  ///
  /// In ja, this message translates to:
  /// **'続けて間違えたため、あと{minutes}分お待ちください'**
  String passcodeWaitMinutes(int minutes);

  /// AUT-04：誤りの回数の上限に達したときの案内（ガード）
  ///
  /// In ja, this message translates to:
  /// **'続けて間違えたため、入力できません。「パスコードを忘れた場合」から解除してください'**
  String get passcodeExhausted;

  /// AUT-04：誤りの回数の上限に達したときの案内（確認モード）
  ///
  /// In ja, this message translates to:
  /// **'続けて間違えたため、入力できません。起動時の画面の「パスコードを忘れた場合」から解除してください'**
  String get passcodeExhaustedConfirm;

  /// 通知のタップで使用中のアカウントが変わったときの案内
  ///
  /// In ja, this message translates to:
  /// **'{name}に切り替えました'**
  String notificationSwitchedAccount(String name);

  /// AUT-05：パスワードを忘れた場合のお問い合わせのボタン
  ///
  /// In ja, this message translates to:
  /// **'お問い合わせ'**
  String get transferPasswordContactSupport;

  /// AUT-04：SMS再認証でパスコードを解除するリンク（ガード時のみ）
  ///
  /// In ja, this message translates to:
  /// **'パスコードを忘れた場合'**
  String get passcodeForgot;

  /// SET-03：パスコード設定画面のタイトル
  ///
  /// In ja, this message translates to:
  /// **'パスコードを設定'**
  String get passcodeSetupTitle;

  /// SET-03：1回目の入力の見出し
  ///
  /// In ja, this message translates to:
  /// **'新しいパスコードを入力'**
  String get passcodeSetupNewTitle;

  /// SET-03：2回目（確認）の入力の見出し
  ///
  /// In ja, this message translates to:
  /// **'もう一度入力'**
  String get passcodeSetupConfirmTitle;

  /// SET-03：2回目の入力が1回目と一致しないときのエラー表示
  ///
  /// In ja, this message translates to:
  /// **'パスコードが一致しません。もう一度入力してください'**
  String get passcodeMismatch;

  /// SET-03：パスコードの保存に失敗したときのエラー表示
  ///
  /// In ja, this message translates to:
  /// **'パスコードを設定できませんでした。もう一度お試しください'**
  String get passcodeSaveFailed;

  /// AUT-04：SMS再認証後のパスコード解除に失敗したときのエラー表示
  ///
  /// In ja, this message translates to:
  /// **'パスコードを解除できませんでした。もう一度お試しください'**
  String get passcodeResetFailed;

  /// パスコード入力テンキーの削除ボタン（アクセシビリティ用ラベル）
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get passcodeKeypadDelete;

  /// SET-01：プロフィール項目のラベル
  ///
  /// In ja, this message translates to:
  /// **'プロフィール'**
  String get setProfileTile;

  /// SET-01：アカウント削除項目のラベル
  ///
  /// In ja, this message translates to:
  /// **'アカウント削除'**
  String get setAccountDeletionTile;

  /// SET-01：ブロックリスト項目のラベル／SET-02：画面タイトル
  ///
  /// In ja, this message translates to:
  /// **'ブロックリスト'**
  String get setBlockListTitle;

  /// SET-01：お問い合わせ項目のラベル（タップで端末のメールアプリを起動）
  ///
  /// In ja, this message translates to:
  /// **'お問い合わせ'**
  String get setContactTile;

  /// SET-01：プライバシーポリシー項目のラベル（タップで外部ブラウザを起動）
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシー'**
  String get setPrivacyPolicyTile;

  /// SET-01：一番下のアプリのバージョンとビルド番号
  ///
  /// In ja, this message translates to:
  /// **'バージョン {version} ({buildNumber})'**
  String setAppVersion(String version, String buildNumber);

  /// SET-01：利用規約項目のラベル（タップで外部ブラウザを起動）
  ///
  /// In ja, this message translates to:
  /// **'利用規約'**
  String get setTermsOfServiceTile;

  /// SET-01：使用中のアカウントだけに反映する項目のグループの見出し
  ///
  /// In ja, this message translates to:
  /// **'このアカウント'**
  String get setSectionThisAccount;

  /// SET-01：全アカウントで共有する（ユーザ単位・端末単位の）項目のグループの見出し
  ///
  /// In ja, this message translates to:
  /// **'すべてのアカウント'**
  String get setSectionAllAccounts;

  /// SET-01：お問い合わせ・規約のグループの見出し
  ///
  /// In ja, this message translates to:
  /// **'アプリ情報'**
  String get setSectionAppInfo;

  /// SET-01：お問い合わせ（メールアプリ）・プライバシーポリシー・利用規約（外部ブラウザ）を起動できなかった場合のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'開けませんでした'**
  String get setLinkOpenFailed;

  /// SET-02：ブロックリストが0件のときの案内
  ///
  /// In ja, this message translates to:
  /// **'ブロック中のアカウントはありません'**
  String get setBlockListEmpty;

  /// SET-02：ブロックリストの取得失敗
  ///
  /// In ja, this message translates to:
  /// **'ブロックリストの取得に失敗しました'**
  String get setBlockListLoadError;

  /// SET-02：各行のブロック解除ボタン／確認ダイアログの確定ボタン
  ///
  /// In ja, this message translates to:
  /// **'ブロック解除'**
  String get setBlockListUnblockButton;

  /// SET-02：ブロック解除確認ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'ブロックを解除しますか？'**
  String get setBlockListUnblockConfirmTitle;

  /// SET-02：ブロック解除確認ダイアログの本文
  ///
  /// In ja, this message translates to:
  /// **'解除しても、以前の友だち関係は元に戻りません。あらためて友だち追加が必要です。'**
  String get setBlockListUnblockConfirmMessage;

  /// SET-02：ブロック解除失敗
  ///
  /// In ja, this message translates to:
  /// **'解除に失敗しました。再度お試しください'**
  String get setBlockListUnblockFailed;

  /// CHA-01：未確認のトークリクエストセクションの見出し（件数付き）
  ///
  /// In ja, this message translates to:
  /// **'未確認のトークリクエスト（{count}）'**
  String chaRequestSectionTitle(int count);

  /// ブロックボタン／確認ダイアログの確定ボタン（CHA-02のリクエストモード・PRO-01）
  ///
  /// In ja, this message translates to:
  /// **'ブロック'**
  String get commonBlockButton;

  /// ブロック確認ダイアログのタイトル（CHA-02のリクエストモード・PRO-01）
  ///
  /// In ja, this message translates to:
  /// **'このアカウントをブロックしますか？'**
  String get commonBlockConfirmTitle;

  /// ブロック確認ダイアログの本文（CHA-02のリクエストモード・PRO-01）
  ///
  /// In ja, this message translates to:
  /// **'ブロックすると、このアカウントからのメッセージを受け取らなくなり、友だち関係も解除されます。ブロックはブロックリストから解除できます。'**
  String get commonBlockConfirmMessage;

  /// ブロック失敗（CHA-02のリクエストモード・PRO-01）
  ///
  /// In ja, this message translates to:
  /// **'ブロックに失敗しました。再度お試しください'**
  String get commonBlockFailed;

  /// SET-01：ログイン中の電話番号の表示項目のラベル
  ///
  /// In ja, this message translates to:
  /// **'電話番号'**
  String get setPhoneNumberTile;

  /// SET-01：通知項目のラベル（タップで端末の通知設定画面を開く）
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get setNotificationTile;

  /// SET-06：このアカウント宛ての通知を受け取るかのスイッチのラベル
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get setNotificationMessagesTitle;

  /// SET-06：通知のスイッチの補足
  ///
  /// In ja, this message translates to:
  /// **'このアカウント宛てのメッセージを通知します'**
  String get setNotificationMessagesSubtitle;

  /// SET-06：リアクションの通知を受け取るかのスイッチのラベル
  ///
  /// In ja, this message translates to:
  /// **'リアクション'**
  String get setNotificationReactionsTitle;

  /// SET-06：リアクションのスイッチの補足
  ///
  /// In ja, this message translates to:
  /// **'自分のメッセージへのリアクションを通知し、未読としても表示します'**
  String get setNotificationReactionsSubtitle;

  /// SET-06：端末（OS）の通知の許可がオフのときの案内（LINE準拠）
  ///
  /// In ja, this message translates to:
  /// **'端末の設定で、Ortoの通知がオフになっています。通知を受け取るには、端末の設定でオンにしてください。'**
  String get setNotificationDeviceOff;

  /// SET-06：端末の設定アプリの、このアプリの通知設定を開くボタン
  ///
  /// In ja, this message translates to:
  /// **'端末の設定を開く'**
  String get setNotificationOpenDeviceSettings;

  /// SET-06：通知設定を読み込めなかったときの表示
  ///
  /// In ja, this message translates to:
  /// **'通知設定の取得に失敗しました'**
  String get setNotificationLoadError;

  /// SET-06：スイッチの変更を保存できなかったときのSnackBar
  ///
  /// In ja, this message translates to:
  /// **'変更できませんでした。再度お試しください'**
  String get setNotificationUpdateFailed;

  /// SET-01：ログアウト項目のラベルと確認ダイアログの実行ボタン。管理者にだけ出す
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get setLogoutTile;

  /// SET-01：ログアウトの確認ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'ログアウトしますか？'**
  String get setLogoutConfirmTitle;

  /// SET-01：ログアウトの確認ダイアログの本文
  ///
  /// In ja, this message translates to:
  /// **'この端末からログアウトします。もう一度使うには、SMS認証が必要です。'**
  String get setLogoutConfirmMessage;

  /// SET-01：ログアウト失敗時のエラー
  ///
  /// In ja, this message translates to:
  /// **'ログアウトできませんでした。通信環境を確認して、もう一度お試しください'**
  String get setLogoutFailed;

  /// SET-01：ログアウトがFirestoreのルールで拒否されたときのエラー
  ///
  /// In ja, this message translates to:
  /// **'サーバーに拒否されたため、ログアウトできませんでした'**
  String get setLogoutDenied;

  /// SET-01：退会項目のラベル
  ///
  /// In ja, this message translates to:
  /// **'退会'**
  String get setWithdrawalTile;

  /// SET-04：退会画面のAppBarタイトル
  ///
  /// In ja, this message translates to:
  /// **'退会'**
  String get withdrawalTitle;

  /// SET-04：退会の確認メッセージ
  ///
  /// In ja, this message translates to:
  /// **'退会すると、この電話番号のすべてのアカウントが削除されます。\n相手には「退会済みアカウント」として表示されます。送ったメッセージは、相手のトーク履歴に残ります。消してほしいメッセージがある場合は、退会の前にお問い合わせください（退会の1年後からは、本人の確認ができず、ご依頼に応じられません）。\n同じ電話番号で再度ログインしても、以前のアカウントには戻せません。\n有料プランのサブスクリプションは退会しても解約されません。契約したストア（App Store・Google Play）で解約してください。'**
  String get withdrawalMessage;

  /// SET-04：確定のスライドを有効にする理解の確認のチェック
  ///
  /// In ja, this message translates to:
  /// **'すべてのアカウントが削除され、元に戻せないことを理解しました'**
  String get withdrawalAcknowledge;

  /// SET-04：確定のスライドのトラックに表示する案内
  ///
  /// In ja, this message translates to:
  /// **'スライドして退会'**
  String get withdrawalSlideLabel;

  /// SET-04：確定のスライドの読み上げ用のボタン名
  ///
  /// In ja, this message translates to:
  /// **'退会する'**
  String get withdrawalSubmitButton;

  /// SET-04：退会失敗時のエラー
  ///
  /// In ja, this message translates to:
  /// **'退会できませんでした。通信環境を確認して、もう一度お試しください'**
  String get withdrawalFailed;

  /// 電話番号の変更画面（AUT-02の変更モード）のタイトル
  ///
  /// In ja, this message translates to:
  /// **'電話番号の変更'**
  String get phoneChangeTitle;

  /// 電話番号の変更画面の説明
  ///
  /// In ja, this message translates to:
  /// **'新しい電話番号を入力してください。\nSMSで届く認証コードで確認します。\nアカウント・トーク・友だちはそのまま引き継がれます。'**
  String get phoneChangeDescription;

  /// SET-01：電話番号の変更完了のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'電話番号を変更しました'**
  String get phoneChangeCompleted;

  /// 電話番号の変更：新しい番号が既に使われている
  ///
  /// In ja, this message translates to:
  /// **'この電話番号は、すでに別のユーザーで使われています'**
  String get authErrorPhoneNumberInUse;

  /// 電話番号の変更：同じ番号が入力された
  ///
  /// In ja, this message translates to:
  /// **'現在と同じ電話番号です'**
  String get authErrorSamePhoneNumber;

  /// AUT-02：SMSを送れない国・地域の電話番号（AuthErrorCode.unsupportedRegion）
  ///
  /// In ja, this message translates to:
  /// **'この国・地域の電話番号には対応していません'**
  String get authErrorUnsupportedRegion;

  /// AUT-02：国番号ボタンの読み上げラベル（タップで国・地域の一覧を開く）
  ///
  /// In ja, this message translates to:
  /// **'国・地域を選択'**
  String get authCountrySelectLabel;

  /// SET-01：引き継ぎパスワード項目のラベル
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎパスワード'**
  String get setTransferPasswordTile;

  /// SET-01：引き継ぎパスワードが登録済みのときの表示
  ///
  /// In ja, this message translates to:
  /// **'設定済み'**
  String get setTransferPasswordRegistered;

  /// SET-01：引き継ぎパスワードが未登録のときの表示
  ///
  /// In ja, this message translates to:
  /// **'未設定'**
  String get setTransferPasswordNotRegistered;

  /// SET-05：引き継ぎパスワード設定画面のタイトル
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎパスワード'**
  String get transferPasswordSetupTitle;

  /// SET-05：引き継ぎパスワードの説明
  ///
  /// In ja, this message translates to:
  /// **'新しい端末でログインするときに、SMSの認証コードに加えてこのパスワードの入力を求めます。\n電話番号を解約して別の人の手に渡っても、あなたのアカウントを見られないようにするためのものです。\n忘れると、新しい端末ではアカウントを引き継げません。'**
  String get transferPasswordSetupDescription;

  /// SET-05：パスワード入力欄
  ///
  /// In ja, this message translates to:
  /// **'パスワード（8〜64文字）'**
  String get transferPasswordFieldLabel;

  /// SET-05：確認用のパスワード入力欄
  ///
  /// In ja, this message translates to:
  /// **'パスワード（確認）'**
  String get transferPasswordConfirmFieldLabel;

  /// SET-05：パスワード入力欄の中の薄い見本（ヒント）
  ///
  /// In ja, this message translates to:
  /// **'パスワードを入力'**
  String get transferPasswordFieldHint;

  /// SET-05：確認用のパスワード入力欄の中の薄い見本（ヒント）
  ///
  /// In ja, this message translates to:
  /// **'もう一度入力'**
  String get transferPasswordConfirmFieldHint;

  /// SET-05：確認用と一致しない
  ///
  /// In ja, this message translates to:
  /// **'パスワードが一致しません'**
  String get transferPasswordMismatch;

  /// SET-05：保存ボタン
  ///
  /// In ja, this message translates to:
  /// **'保存する'**
  String get transferPasswordSaveButton;

  /// 最初のアカウント作成後の案内のタイトル
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎパスワードを設定しませんか'**
  String get transferPasswordPromptTitle;

  /// 最初のアカウント作成後の案内の本文
  ///
  /// In ja, this message translates to:
  /// **'電話番号が別の人に渡っても、あなたのアカウントを見られないようにできます。\n忘れると、新しい端末で引き継げません。'**
  String get transferPasswordPromptMessage;

  /// 最初のアカウント作成後の案内：SET-05へ進むボタン
  ///
  /// In ja, this message translates to:
  /// **'設定する'**
  String get transferPasswordPromptSetUp;

  /// 最初のアカウント作成後の案内：閉じるボタン
  ///
  /// In ja, this message translates to:
  /// **'あとで設定する'**
  String get transferPasswordPromptLater;

  /// SET-01：引き継ぎパスワードの設定完了のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎパスワードを設定しました'**
  String get transferPasswordSaved;

  /// AUT-05：引き継ぎパスワード入力画面のタイトル
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎパスワードの確認'**
  String get transferPasswordEntryTitle;

  /// AUT-05：説明
  ///
  /// In ja, this message translates to:
  /// **'この電話番号には引き継ぎパスワードが設定されています。\n新しい端末で使うには、パスワードを入力してください。'**
  String get transferPasswordEntryDescription;

  /// AUT-05：確認ボタン
  ///
  /// In ja, this message translates to:
  /// **'確認'**
  String get transferPasswordEntryButton;

  /// AUT-05：パスワードを忘れた場合のリンク
  ///
  /// In ja, this message translates to:
  /// **'パスワードを忘れた場合'**
  String get transferPasswordForgot;

  /// AUT-05：パスワードを忘れた場合のダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'パスワードを忘れた場合'**
  String get transferPasswordForgotTitle;

  /// AUT-05：パスワードを忘れた場合のダイアログの本文
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎパスワードは再発行できません。以前の端末でログインしている場合は、そちらの設定画面からパスワードを設定し直してください。\n以前の端末が使えない場合は、以前のデータ（すべてのアカウント）を削除して、この電話番号で始め直せます。削除は申請から7日後に行い、その間は以前の端末から取り消せます。'**
  String get transferPasswordForgotMessage;

  /// AUT-05：パスワードを忘れた場合のダイアログの、再設定を申請するボタン
  ///
  /// In ja, this message translates to:
  /// **'データを削除して始め直す'**
  String get transferResetStart;

  /// AUT-05：再設定の申請の確認のタイトル
  ///
  /// In ja, this message translates to:
  /// **'以前のデータを削除しますか？'**
  String get transferResetConfirmTitle;

  /// AUT-05：再設定の申請の確認の本文
  ///
  /// In ja, this message translates to:
  /// **'申請から7日後に、この電話番号のすべてのアカウントを、退会と同じく削除します。元に戻せません。\n7日後以降にもう一度ログインすると、新しく始められます。\n以前の端末でログインしている場合は、そちらに知らせが届き、取り消せます。'**
  String get transferResetConfirmMessage;

  /// AUT-05：再設定の申請の確定ボタン
  ///
  /// In ja, this message translates to:
  /// **'申請する'**
  String get transferResetConfirmButton;

  /// AUT-05：再設定を申請済みのときの案内。dateは削除の日時
  ///
  /// In ja, this message translates to:
  /// **'{date}以降に、以前のデータを削除します。その後、もう一度ログインすると、新しく始められます。'**
  String transferResetPending(String date);

  /// AUT-05：再設定の申請を取り消すボタン
  ///
  /// In ja, this message translates to:
  /// **'申請を取り消す'**
  String get transferResetCancel;

  /// AUT-05：再設定の申請・取り消しの失敗
  ///
  /// In ja, this message translates to:
  /// **'申請できませんでした。通信環境を確認して、もう一度お試しください'**
  String get transferResetFailed;

  /// ホーム：前の持ち主の端末に出す、再設定の申請の警告のタイトル
  ///
  /// In ja, this message translates to:
  /// **'データの削除の申請があります'**
  String get transferResetAlertTitle;

  /// ホーム：再設定の申請の警告の本文。dateは削除の日時
  ///
  /// In ja, this message translates to:
  /// **'新しい端末から、引き継ぎパスワードを忘れたとして、この電話番号のデータの削除が申請されました。{date}に、すべてのアカウントが削除されます。\n心当たりがなければ、取り消してください。'**
  String transferResetAlertMessage(String date);

  /// ホーム：再設定の申請を取り消すボタン
  ///
  /// In ja, this message translates to:
  /// **'取り消す'**
  String get transferResetAlertCancel;

  /// ホーム：再設定の申請の警告を閉じるボタン
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get transferResetAlertLater;

  /// 再設定の申請を取り消したときのSnackBar
  ///
  /// In ja, this message translates to:
  /// **'申請を取り消しました'**
  String get transferResetCanceled;

  /// ホーム：改定の再同意のダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'利用規約とプライバシーポリシーを改定しました'**
  String get legalUpdateTitle;

  /// ホーム：改定の再同意のダイアログの本文
  ///
  /// In ja, this message translates to:
  /// **'改定後の内容をご確認のうえ、「同意する」を押してください。'**
  String get legalUpdateMessage;

  /// ホーム：改定の再同意のボタン
  ///
  /// In ja, this message translates to:
  /// **'同意する'**
  String get legalUpdateAgree;

  /// ホーム：再同意の記録の失敗
  ///
  /// In ja, this message translates to:
  /// **'記録できませんでした。通信環境を確認して、もう一度お試しください'**
  String get legalUpdateFailed;

  /// AUT-05：サインインを取り消してAUT-02へ戻るリンク
  ///
  /// In ja, this message translates to:
  /// **'電話番号の入力に戻る'**
  String get transferPasswordBackToPhoneInput;

  /// AUT-05：パスワード誤り
  ///
  /// In ja, this message translates to:
  /// **'パスワードが違います'**
  String get transferPasswordErrorWrong;

  /// AUT-05：続けて間違えたためロック中
  ///
  /// In ja, this message translates to:
  /// **'続けて間違えたため、しばらくしてからお試しください'**
  String get transferPasswordErrorLocked;

  /// SET-05：文字数が不正
  ///
  /// In ja, this message translates to:
  /// **'パスワードは8〜64文字で入力してください'**
  String get transferPasswordErrorInvalid;

  /// AUT-05・SET-05：通信エラー
  ///
  /// In ja, this message translates to:
  /// **'通信に失敗しました。通信環境を確認して、もう一度お試しください'**
  String get transferPasswordErrorNetwork;

  /// CHA-01：最新メッセージより後に未読のリアクションが付いたトークの、プレビューの代わりの表示
  ///
  /// In ja, this message translates to:
  /// **'リアクションされました'**
  String get chaListReactionPreview;

  /// CHA-01：最新メッセージが画像のときのプレビュー
  ///
  /// In ja, this message translates to:
  /// **'画像'**
  String get chaImagePreviewLabel;

  /// CHA-02：入力欄の画像ボタン（アクセシビリティ用ラベル）
  ///
  /// In ja, this message translates to:
  /// **'画像を送る'**
  String get chaImageButtonTooltip;

  /// CHA-02：画像の送信前プレビューの送信ボタン
  ///
  /// In ja, this message translates to:
  /// **'送信'**
  String get chaImageSendButton;

  /// CHA-02：選んだ画像の読み込み・縮小中の表示
  ///
  /// In ja, this message translates to:
  /// **'画像を準備しています…'**
  String get chaImagePreparing;

  /// CHA-02：画像の送信失敗
  ///
  /// In ja, this message translates to:
  /// **'画像を送信できませんでした。もう一度お試しください'**
  String get chaImageSendFailed;

  /// CHA-02：画像が10MB以上
  ///
  /// In ja, this message translates to:
  /// **'画像が大きすぎるため送信できません（10MBまで）'**
  String get chaImageTooLarge;

  /// CHA-02・CHA-03：画像の読み込み失敗
  ///
  /// In ja, this message translates to:
  /// **'画像を読み込めませんでした'**
  String get chaImageLoadFailed;

  /// CHA-03：保存ボタン（アクセシビリティ用ラベル）
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get chaImageSaveTooltip;

  /// CHA-03：アルバムへの保存完了
  ///
  /// In ja, this message translates to:
  /// **'画像を保存しました'**
  String get chaImageSaved;

  /// CHA-03：アルバムへの保存失敗
  ///
  /// In ja, this message translates to:
  /// **'画像を保存できませんでした'**
  String get chaImageSaveFailed;

  /// CHA-03：写真への追加の権限が拒否されている
  ///
  /// In ja, this message translates to:
  /// **'写真へのアクセスが許可されていません。端末の設定アプリから写真へのアクセスを許可してください。'**
  String get chaImageSaveDenied;

  /// CHA-03：自分が送った画像の送信者名の表示
  ///
  /// In ja, this message translates to:
  /// **'自分'**
  String get chaImageMine;

  /// 通報の入口のボタン・項目（PRO-01・CHA-02のリクエストモード・メッセージの長押しメニュー）
  ///
  /// In ja, this message translates to:
  /// **'通報'**
  String get commonReportButton;

  /// REP-01：タイトル
  ///
  /// In ja, this message translates to:
  /// **'通報'**
  String get repTitle;

  /// REP-01：説明
  ///
  /// In ja, this message translates to:
  /// **'通報の理由を選んでください。\n通報したことは相手に通知されません。'**
  String get repDescription;

  /// REP-01：理由の見出し
  ///
  /// In ja, this message translates to:
  /// **'理由'**
  String get repReasonLabel;

  /// REP-01：理由（ReportReason.spam）
  ///
  /// In ja, this message translates to:
  /// **'スパム・宣伝'**
  String get repReasonSpam;

  /// REP-01：理由（ReportReason.harassment）
  ///
  /// In ja, this message translates to:
  /// **'嫌がらせ・いじめ'**
  String get repReasonHarassment;

  /// REP-01：理由（ReportReason.impersonation）
  ///
  /// In ja, this message translates to:
  /// **'なりすまし'**
  String get repReasonImpersonation;

  /// REP-01：理由（ReportReason.inappropriate）
  ///
  /// In ja, this message translates to:
  /// **'不適切なコンテンツ'**
  String get repReasonInappropriate;

  /// REP-01：理由（ReportReason.other）
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get repReasonOther;

  /// REP-01：詳しい内容の見出し
  ///
  /// In ja, this message translates to:
  /// **'詳しい内容（任意）'**
  String get repDetailLabel;

  /// REP-01：詳しい内容の入力欄の見本
  ///
  /// In ja, this message translates to:
  /// **'どのような問題があったか'**
  String get repDetailHint;

  /// REP-01：通報と同時にブロックするかのチェックボックス
  ///
  /// In ja, this message translates to:
  /// **'この相手をブロックする'**
  String get repAlsoBlock;

  /// REP-01：送信ボタン
  ///
  /// In ja, this message translates to:
  /// **'通報する'**
  String get repSubmitButton;

  /// REP-01：通報後のSnackBar（ReportOutcome.reported）
  ///
  /// In ja, this message translates to:
  /// **'通報しました'**
  String get repDone;

  /// REP-01：通報・ブロック後のSnackBar（ReportOutcome.reportedAndBlocked）
  ///
  /// In ja, this message translates to:
  /// **'通報し、ブロックしました'**
  String get repDoneAndBlocked;

  /// REP-01：通報はできたがブロックに失敗したときのSnackBar（ReportOutcome.blockFailed）
  ///
  /// In ja, this message translates to:
  /// **'通報しましたが、ブロックできませんでした'**
  String get repBlockFailed;

  /// REP-01：通報に失敗したときのSnackBar（ReportOutcome.failed）
  ///
  /// In ja, this message translates to:
  /// **'通報できませんでした。もう一度お試しください'**
  String get repFailed;

  /// AUT-06：見出し
  ///
  /// In ja, this message translates to:
  /// **'アップデートが必要です'**
  String get appUpdateTitle;

  /// AUT-06：本文
  ///
  /// In ja, this message translates to:
  /// **'新しいバージョンのアプリをインストールしてください'**
  String get appUpdateMessage;

  /// AUT-06：ストアを開くボタン
  ///
  /// In ja, this message translates to:
  /// **'アップデート'**
  String get appUpdateButton;

  /// CHA-01・CHA-02：このバージョンのアプリが知らない種類のメッセージの表示
  ///
  /// In ja, this message translates to:
  /// **'アプリを更新すると表示できます'**
  String get chaUnsupportedMessage;

  /// CHA-02：入力欄の送信ボタン（アクセシビリティ用ラベル）
  ///
  /// In ja, this message translates to:
  /// **'送信'**
  String get chaSendButtonTooltip;

  /// CHA-02：スタンプボタンの説明
  ///
  /// In ja, this message translates to:
  /// **'スタンプ'**
  String get chaStickerButtonTooltip;

  /// CHA-01：最新メッセージがスタンプのときのプレビュー
  ///
  /// In ja, this message translates to:
  /// **'スタンプ'**
  String get chaStickerPreviewLabel;

  /// CHA-02：スタンプの画像を取得できないときの表示
  ///
  /// In ja, this message translates to:
  /// **'スタンプを表示できません'**
  String get chaStickerUnavailable;

  /// PRO-01：メモが無いときの表示
  ///
  /// In ja, this message translates to:
  /// **'メモを追加'**
  String get proMemoAdd;

  /// PRO-01：メモ編集シートのタイトルと、メモのカードのラベル
  ///
  /// In ja, this message translates to:
  /// **'メモ'**
  String get proMemoSheetTitle;

  /// PRO-01：メモ入力欄のプレースホルダ
  ///
  /// In ja, this message translates to:
  /// **'自分だけに見えるメモを入力'**
  String get proMemoHint;

  /// PRO-01：メモのカードの読み上げの説明
  ///
  /// In ja, this message translates to:
  /// **'メモを編集'**
  String get proMemoEdit;

  /// PRO-01：メモのカードの補助文字
  ///
  /// In ja, this message translates to:
  /// **'自分だけに表示されます'**
  String get proMemoPrivate;

  /// PRO-01：ピン留めがオンのときのチップ
  ///
  /// In ja, this message translates to:
  /// **'ピン留め中'**
  String get proMemoPinned;

  /// PRO-01：ピン留めがオフのときのチップ
  ///
  /// In ja, this message translates to:
  /// **'トークにピン留め'**
  String get proMemoPin;

  /// PRO-01：メモの保存に失敗したときのSnackBar
  ///
  /// In ja, this message translates to:
  /// **'メモの保存に失敗しました。再度お試しください'**
  String get proMemoSaveFailed;

  /// SET-01の項目・SET-07のタイトル
  ///
  /// In ja, this message translates to:
  /// **'プラン'**
  String get planTitle;

  /// プラン名
  ///
  /// In ja, this message translates to:
  /// **'無料'**
  String get planNameFree;

  /// プラン名
  ///
  /// In ja, this message translates to:
  /// **'グレード1'**
  String get planNameGrade1;

  /// プラン名
  ///
  /// In ja, this message translates to:
  /// **'グレード2'**
  String get planNameGrade2;

  /// プラン名
  ///
  /// In ja, this message translates to:
  /// **'運営者'**
  String get planNameAdmin;

  /// SET-07：今のプラン
  ///
  /// In ja, this message translates to:
  /// **'現在のプラン：{plan}'**
  String planCurrent(String plan);

  /// SET-07：使用数と上限
  ///
  /// In ja, this message translates to:
  /// **'アカウント {count} / {limit}'**
  String planAccountCount(int count, int limit);

  /// SET-07：使用数（上限なし）
  ///
  /// In ja, this message translates to:
  /// **'アカウント {count}'**
  String planAccountCountUnlimited(int count);

  /// SET-07：無料プランより増える数
  ///
  /// In ja, this message translates to:
  /// **'＋{count}アカウント'**
  String planExtraAccounts(int count);

  /// SET-07：プランの上限
  ///
  /// In ja, this message translates to:
  /// **'合計{count}アカウントまで'**
  String planTotalAccounts(int count);

  /// SET-07：価格。priceはストアの表示用の文字列
  ///
  /// In ja, this message translates to:
  /// **'{price}／月'**
  String planPricePerMonth(String price);

  /// SET-07
  ///
  /// In ja, this message translates to:
  /// **'購入する'**
  String get planBuyButton;

  /// SET-07
  ///
  /// In ja, this message translates to:
  /// **'このプランに変更'**
  String get planChangeButton;

  /// SET-07
  ///
  /// In ja, this message translates to:
  /// **'利用中'**
  String get planCurrentBadge;

  /// SET-07
  ///
  /// In ja, this message translates to:
  /// **'購入を復元'**
  String get planRestoreButton;

  /// SET-07
  ///
  /// In ja, this message translates to:
  /// **'解約・プラン変更（{store}）'**
  String planManageButton(String store);

  /// SET-07：別のストアに有効な契約があり、購入ボタンを隠しているとき
  ///
  /// In ja, this message translates to:
  /// **'このプランは{store}で契約しています。変更・解約は{store}で行ってください。'**
  String planOtherStoreNotice(String store);

  /// SET-07：自動更新の説明
  ///
  /// In ja, this message translates to:
  /// **'月額の自動更新のサブスクリプションです。お支払いは{account}に請求されます。期間が終わる24時間前までに解約しない限り、自動で更新されます。解約は{store}のサブスクリプションの設定からできます。解約した後、アカウント数がプランの上限を超えていると、上限を超えた分のアカウントが読み取り専用になります。'**
  String planAutoRenewNotice(String account, String store);

  /// SET-07：Google Playの請求先
  ///
  /// In ja, this message translates to:
  /// **'Googleアカウント'**
  String get planBillingAccountGoogle;

  /// SET-07：商品を取得できないとき
  ///
  /// In ja, this message translates to:
  /// **'現在、この端末では購入できません。'**
  String get planStoreUnavailable;

  /// SET-07
  ///
  /// In ja, this message translates to:
  /// **'プランを読み込めませんでした'**
  String get planLoadError;

  /// SET-07：購入・復元の検証に成功
  ///
  /// In ja, this message translates to:
  /// **'プランを反映しました'**
  String get planPurchaseApplied;

  /// SET-07：承認待ち
  ///
  /// In ja, this message translates to:
  /// **'購入の承認を待っています'**
  String get planPurchasePending;

  /// SET-07
  ///
  /// In ja, this message translates to:
  /// **'購入を反映できませんでした。時間をおいて「購入を復元」をお試しください'**
  String get planPurchaseFailed;

  /// SET-07
  ///
  /// In ja, this message translates to:
  /// **'復元できる購入はありません'**
  String get planNothingToRestore;

  /// SET-07：予約中のプラン変更（機能仕様書4.6.4.3）
  ///
  /// In ja, this message translates to:
  /// **'現在のプラン：{plan}（{date}から{next}）'**
  String planCurrentScheduled(String plan, String date, String next);

  /// SET-07：予約中のプラン変更（機能仕様書4.6.4.3）
  ///
  /// In ja, this message translates to:
  /// **'変更日までは今のプランのまま使えます。取り消すときは「解約・プラン変更」から操作してください。'**
  String get planScheduledNotice;

  /// SET-07：予約中のプラン変更（機能仕様書4.6.4.3）
  ///
  /// In ja, this message translates to:
  /// **'変更予約済み'**
  String get planScheduledBadge;

  /// SET-07：予約中のプラン変更（機能仕様書4.6.4.3）
  ///
  /// In ja, this message translates to:
  /// **'プランの変更を予約しました。次回の更新日から切り替わります'**
  String get planChangeScheduled;

  /// SET-07：予約中のプラン変更（機能仕様書4.6.4.3）
  ///
  /// In ja, this message translates to:
  /// **'このプランは契約中か、変更を予約済みです。別の番号で契約した場合は「購入を復元」で引き継げます'**
  String get planPurchaseAlreadyOwned;

  /// SET-07：ストアの契約の引き継ぎ（機能仕様書4.6.4.2）
  ///
  /// In ja, this message translates to:
  /// **'契約を引き継ぐ'**
  String get planTransferButton;

  /// SET-07：ストアの契約の引き継ぎ（機能仕様書4.6.4.2）
  ///
  /// In ja, this message translates to:
  /// **'この{account}に{plan}の契約があります。引き継ぐと、このログインで使えます。ほかのログインで使っている場合、そちらは無料プランに戻ります。'**
  String planTransferNotice(String account, String plan);

  /// SET-07：特定商取引法に基づく表記へのリンク
  ///
  /// In ja, this message translates to:
  /// **'特定商取引法に基づく表記'**
  String get planTokushohoLink;

  /// 読み取り専用の案内（CHA-02など）
  ///
  /// In ja, this message translates to:
  /// **'プランの上限を超えた分のアカウントのため、読み取り専用です'**
  String get planReadOnlyNotice;

  /// SET-07：読み取り専用の説明
  ///
  /// In ja, this message translates to:
  /// **'アカウント数がプランの上限を超えているため、使い続けるアカウント以外は読み取り専用です。プランを変更するか、アカウントを削除して上限内にすると元に戻ります。'**
  String get planReadOnlyExplanation;

  /// SET-07：ACC-01の＋から開いたときの案内（一番上のプラン未満）
  ///
  /// In ja, this message translates to:
  /// **'アカウント数が上限に達しました。プランを変更すると増やせます。'**
  String get planLimitReachedUpgrade;

  /// SET-07：ACC-01の＋から開いたときの案内（一番上のプラン）
  ///
  /// In ja, this message translates to:
  /// **'アカウント数が上限に達しました。これ以上は増やせません。'**
  String get planLimitReachedTopPlan;

  /// SET-07：SET-08へのボタン
  ///
  /// In ja, this message translates to:
  /// **'使い続けるアカウントを選ぶ'**
  String get planKeptAccountsButton;

  /// SET-08：タイトル
  ///
  /// In ja, this message translates to:
  /// **'使い続けるアカウント'**
  String get keptAccountsTitle;

  /// SET-08：説明
  ///
  /// In ja, this message translates to:
  /// **'使い続けるアカウントを{limit}件選んでください。選ばなかったアカウントは読み取り専用になります。変更できるのは、プランが変わるごとに1回だけです。'**
  String keptAccountsDescription(int limit);

  /// SET-08：決定ボタン
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get keptAccountsConfirmButton;

  /// SET-08：確認ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'このアカウントに決めますか？'**
  String get keptAccountsConfirmTitle;

  /// SET-08：確認ダイアログの本文
  ///
  /// In ja, this message translates to:
  /// **'決めた後は、次にプランが変わるまで変更できません。'**
  String get keptAccountsConfirmMessage;

  /// SET-08：保存の成功
  ///
  /// In ja, this message translates to:
  /// **'使い続けるアカウントを決めました'**
  String get keptAccountsSaved;

  /// SET-08：保存の失敗
  ///
  /// In ja, this message translates to:
  /// **'保存できませんでした。時間をおいてお試しください'**
  String get keptAccountsSaveFailed;

  /// プランが下がった後の案内のタイトル
  ///
  /// In ja, this message translates to:
  /// **'アカウント数がプランの上限を超えています'**
  String get keptAccountsPromptTitle;

  /// プランが下がった後の案内の本文
  ///
  /// In ja, this message translates to:
  /// **'上限の数までのアカウントは使い続けられ、ほかのアカウントは読み取り専用です。使い続けるアカウントは、1回変更できます。'**
  String get keptAccountsPromptMessage;

  /// プランが下がった後の案内のボタン
  ///
  /// In ja, this message translates to:
  /// **'選ぶ'**
  String get keptAccountsPromptChoose;

  /// 読み取り専用の案内のボタン
  ///
  /// In ja, this message translates to:
  /// **'プランを見る'**
  String get planSeePlansButton;

  /// GRP-01：タイトル
  ///
  /// In ja, this message translates to:
  /// **'友だちを選択'**
  String get grpSelectFriendsTitle;

  /// GRP-01：ヘッダーのボタン
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get grpNext;

  /// GRP-01：検索欄
  ///
  /// In ja, this message translates to:
  /// **'名前で検索'**
  String get grpSearchHint;

  /// GRP-02：ヘッダーのボタン
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get grpCreateAction;

  /// GRP-02：入力欄の上の見出し
  ///
  /// In ja, this message translates to:
  /// **'グループ名'**
  String get grpNameLabel;

  /// GRP-02・GRP-03：グループ名入力欄の中の薄い見本（ヒント）
  ///
  /// In ja, this message translates to:
  /// **'グループ名を入力'**
  String get grpNameHint;

  /// GRP-02：方式の見出し
  ///
  /// In ja, this message translates to:
  /// **'友だちの招待の方式'**
  String get grpPolicyLabel;

  /// GRP-02：方式
  ///
  /// In ja, this message translates to:
  /// **'承認制'**
  String get grpPolicyApproval;

  /// GRP-02：方式の説明
  ///
  /// In ja, this message translates to:
  /// **'招待された人が「参加」または「拒否」を選べます'**
  String get grpPolicyApprovalDescription;

  /// GRP-02：方式
  ///
  /// In ja, this message translates to:
  /// **'自動参加'**
  String get grpPolicyAuto;

  /// GRP-02：方式の説明
  ///
  /// In ja, this message translates to:
  /// **'友だちどうしなら招待されると自動で参加します'**
  String get grpPolicyAutoDescription;

  /// GRP-02：注意書き
  ///
  /// In ja, this message translates to:
  /// **'方式は作成後に変更できません'**
  String get grpPolicyFixedNote;

  /// GRP-02：作成の失敗
  ///
  /// In ja, this message translates to:
  /// **'グループを作成できませんでした'**
  String get grpCreateFailed;

  /// FRI-01：グループタブの空の表示
  ///
  /// In ja, this message translates to:
  /// **'参加中のグループはありません'**
  String get grpListEmpty;

  /// CHA-01：招待のセクションの見出し
  ///
  /// In ja, this message translates to:
  /// **'グループへの招待（{count}）'**
  String grpRequestSectionTitle(int count);

  /// CHA-01：招待した人
  ///
  /// In ja, this message translates to:
  /// **'{name}からの招待'**
  String grpRequestInvitedBy(String name);

  /// CHA-01：招待への参加
  ///
  /// In ja, this message translates to:
  /// **'参加'**
  String get grpRequestJoin;

  /// CHA-01：招待の拒否
  ///
  /// In ja, this message translates to:
  /// **'拒否'**
  String get grpRequestDecline;

  /// CHA-01：招待の操作の失敗
  ///
  /// In ja, this message translates to:
  /// **'操作に失敗しました'**
  String get grpRequestFailed;

  /// グループ名と人数
  ///
  /// In ja, this message translates to:
  /// **'{name}（{count}）'**
  String grpTitleWithCount(String name, int count);

  /// CHA-01：送信者名付きのプレビュー
  ///
  /// In ja, this message translates to:
  /// **'{name}: {text}'**
  String grpPreviewWithSender(String name, String text);

  /// CHA-02：当日の定型連絡のボタン・吹き出し・CHA-01のプレビュー（機能仕様書4.7.8.11）
  ///
  /// In ja, this message translates to:
  /// **'遅れます'**
  String get grpMeetupStatusLate;

  /// CHA-02：当日の定型連絡のボタン・吹き出し・CHA-01のプレビュー（機能仕様書4.7.8.11）
  ///
  /// In ja, this message translates to:
  /// **'着きました'**
  String get grpMeetupStatusArrived;

  /// CHA-02：当日の定型連絡のボタン・吹き出し・CHA-01のプレビュー（機能仕様書4.7.8.11）
  ///
  /// In ja, this message translates to:
  /// **'見つかりません'**
  String get grpMeetupStatusNotFound;

  /// グループの操作の失敗：読み取り専用
  ///
  /// In ja, this message translates to:
  /// **'読み取り専用の間はグループを利用できません'**
  String get grpErrorReadOnly;

  /// グループの操作の失敗：満員
  ///
  /// In ja, this message translates to:
  /// **'グループの人数が上限に達しています'**
  String get grpErrorGroupFull;

  /// グループの操作の失敗：参加の上限
  ///
  /// In ja, this message translates to:
  /// **'参加できるグループ数の上限に達しています'**
  String get grpErrorJoinLimit;

  /// グループの操作の失敗：作成の上限
  ///
  /// In ja, this message translates to:
  /// **'作成できるグループ数の上限に達しています'**
  String get grpErrorCreateLimit;

  /// グループの操作の失敗：招待で人数の上限を超える
  ///
  /// In ja, this message translates to:
  /// **'参加できる人数の上限を超えています'**
  String get grpErrorMembersExceeded;

  /// グループの操作の失敗：削除済み
  ///
  /// In ja, this message translates to:
  /// **'このグループはなくなりました'**
  String get grpErrorGroupDeleted;

  /// グループの操作の失敗：無効なリンク
  ///
  /// In ja, this message translates to:
  /// **'この招待リンクは無効です'**
  String get grpErrorInviteInvalid;

  /// システムメッセージ
  ///
  /// In ja, this message translates to:
  /// **'{actor}がグループ「{group}」を作成しました'**
  String grpSysCreated(String actor, String group);

  /// システムメッセージ
  ///
  /// In ja, this message translates to:
  /// **'{name}が参加しました'**
  String grpSysJoined(String name);

  /// システムメッセージ
  ///
  /// In ja, this message translates to:
  /// **'{name}が退会しました'**
  String grpSysLeft(String name);

  /// システムメッセージ
  ///
  /// In ja, this message translates to:
  /// **'{actor}が{target}を退会させました'**
  String grpSysRemoved(String actor, String target);

  /// システムメッセージ
  ///
  /// In ja, this message translates to:
  /// **'{actor}がグループ名を「{group}」に変更しました'**
  String grpSysRenamed(String actor, String group);

  /// システムメッセージ
  ///
  /// In ja, this message translates to:
  /// **'{actor}がグループの画像を変更しました'**
  String grpSysPhotoChanged(String actor);

  /// システムメッセージ
  ///
  /// In ja, this message translates to:
  /// **'{actor}が招待リンクを再発行しました'**
  String grpSysInviteReissued(String actor);

  /// GRP-03：タイトル
  ///
  /// In ja, this message translates to:
  /// **'グループ情報'**
  String get grpInfoTitle;

  /// GRP-03：このグループの通知
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get grpNotifications;

  /// GRP-03：メンバーの取得失敗
  ///
  /// In ja, this message translates to:
  /// **'メンバーを取得できませんでした'**
  String get grpMembersLoadError;

  /// GRP-03：自分の行
  ///
  /// In ja, this message translates to:
  /// **'{name}（自分）'**
  String grpMemberMe(String name);

  /// GRP-03：他の参加者を退会させる
  ///
  /// In ja, this message translates to:
  /// **'退会させる'**
  String get grpRemoveMember;

  /// GRP-03：確認
  ///
  /// In ja, this message translates to:
  /// **'{name}をこのグループから退会させますか？'**
  String grpRemoveConfirmMessage(String name);

  /// GRP-03：退会
  ///
  /// In ja, this message translates to:
  /// **'グループを退会'**
  String get grpLeave;

  /// GRP-03：確認の実行ボタン
  ///
  /// In ja, this message translates to:
  /// **'退会'**
  String get grpLeaveAction;

  /// GRP-03：確認
  ///
  /// In ja, this message translates to:
  /// **'グループを退会しますか？'**
  String get grpLeaveConfirmTitle;

  /// GRP-03：確認
  ///
  /// In ja, this message translates to:
  /// **'トーク履歴は読めなくなります。再参加しても読めません。'**
  String get grpLeaveConfirmMessage;

  /// GRP-03：通報
  ///
  /// In ja, this message translates to:
  /// **'このグループを通報'**
  String get grpReportGroup;

  /// CHA-02：退会した
  ///
  /// In ja, this message translates to:
  /// **'このグループから退会しました'**
  String get grpLeftNotice;

  /// CHA-02：グループの既読
  ///
  /// In ja, this message translates to:
  /// **'既読 {count}'**
  String grpReadCount(int count);

  /// REP-01：グループの通報
  ///
  /// In ja, this message translates to:
  /// **'このグループを通報します。\n通報の理由を選んでください。'**
  String get repGroupDescription;

  /// フォアグラウンドでグループへの招待の通知を受信したときのバナー本文。Cloud FunctionsのGROUP_INVITE_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'グループに招待されました'**
  String get pushGroupInviteBanner;

  /// GRP-03：招待
  ///
  /// In ja, this message translates to:
  /// **'招待'**
  String get grpInvite;

  /// GRP-04
  ///
  /// In ja, this message translates to:
  /// **'友だちから選ぶ'**
  String get grpInviteFromFriends;

  /// GRP-04
  ///
  /// In ja, this message translates to:
  /// **'QRコードを共有'**
  String get grpInviteQrShare;

  /// GRP-04
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピー'**
  String get grpInviteLinkCopy;

  /// GRP-04
  ///
  /// In ja, this message translates to:
  /// **'招待リンクを送る'**
  String get grpInviteLinkShare;

  /// GRP-04
  ///
  /// In ja, this message translates to:
  /// **'リンクとQRコードを再発行'**
  String get grpInviteReissue;

  /// GRP-04：確認の実行ボタン
  ///
  /// In ja, this message translates to:
  /// **'再発行'**
  String get grpInviteReissueAction;

  /// GRP-04：確認
  ///
  /// In ja, this message translates to:
  /// **'今のリンクとQRコードは使えなくなります'**
  String get grpInviteReissueMessage;

  /// GRP-04：注意書き
  ///
  /// In ja, this message translates to:
  /// **'リンクを知っている人は誰でも参加できます'**
  String get grpInviteNote;

  /// GRP-04：「招待リンクを送る」の共有シートの文面。受け取る側の目線で、グループ名を入れる（uidなど内部の値は入れない）。招待ページと言い回しをそろえる
  ///
  /// In ja, this message translates to:
  /// **'Ortoのグループ「{groupName}」に招待されています。\n下のリンクを開くと、グループの内容を確かめて参加に進めます。Ortoは、電話番号やLINEを相手に教えずにやりとりできるアプリです。\n{link}'**
  String grpInviteShareMessage(String groupName, String link);

  /// GRP-04：「QRコードを共有」で画像に付ける文面。リンクはQRコードに入っているので付けない
  ///
  /// In ja, this message translates to:
  /// **'Ortoのグループ「{groupName}」の招待のQRコードです。スマートフォンのカメラで読み取ると、グループの内容を確かめて参加に進めます。'**
  String grpInviteQrShareMessage(String groupName);

  /// GRP-01：招待時のヘッダーのボタン
  ///
  /// In ja, this message translates to:
  /// **'招待'**
  String get grpInviteAction;

  /// GRP-01：招待の結果
  ///
  /// In ja, this message translates to:
  /// **'招待しました'**
  String get grpInvited;

  /// GRP-01：参加している友だち
  ///
  /// In ja, this message translates to:
  /// **'参加中'**
  String get grpJoinedLabel;

  /// GRP-01：人数の上限
  ///
  /// In ja, this message translates to:
  /// **'最大100人まで'**
  String get grpMaxMembers;

  /// GRP-05：タイトル
  ///
  /// In ja, this message translates to:
  /// **'グループに参加'**
  String get grpJoinTitle;

  /// GRP-05：参加するアカウント
  ///
  /// In ja, this message translates to:
  /// **'{name}で参加します'**
  String grpJoinAccount(String name);

  /// CHA-01：最新メッセージがアルバムの案内のときのプレビュー
  ///
  /// In ja, this message translates to:
  /// **'アルバム'**
  String get albPreviewLabel;

  /// ALB-01：タイトル、GRP-03：行
  ///
  /// In ja, this message translates to:
  /// **'アルバム'**
  String get albListTitle;

  /// ALB-01：0件
  ///
  /// In ja, this message translates to:
  /// **'アルバムはまだありません'**
  String get albEmpty;

  /// ALB-01・ALB-02：読み込み失敗
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした'**
  String get albLoadError;

  /// ALB-01：作成の名前入力
  ///
  /// In ja, this message translates to:
  /// **'アルバムを作成'**
  String get albCreateTitle;

  /// ALB-01・ALB-02：名前の入力欄
  ///
  /// In ja, this message translates to:
  /// **'アルバム名'**
  String get albNameHint;

  /// ALB-01：作成失敗
  ///
  /// In ja, this message translates to:
  /// **'アルバムを作成できませんでした'**
  String get albCreateFailed;

  /// ALB-01：件数の上限
  ///
  /// In ja, this message translates to:
  /// **'このトークのアルバムは100件までです'**
  String get albTooManyAlbums;

  /// ALB-02：件数の上限
  ///
  /// In ja, this message translates to:
  /// **'1つのアルバムに追加できるのは1000件までです'**
  String get albTooManyItems;

  /// ALB-02：0件
  ///
  /// In ja, this message translates to:
  /// **'画像や動画はありません'**
  String get albNoItems;

  /// ALB-02・CHA-02：アルバムが消された
  ///
  /// In ja, this message translates to:
  /// **'削除されたアルバム'**
  String get albDeleted;

  /// ALB-02：メニュー
  ///
  /// In ja, this message translates to:
  /// **'選択'**
  String get albSelect;

  /// ALB-02：メニュー
  ///
  /// In ja, this message translates to:
  /// **'名前を変更'**
  String get albRenameTitle;

  /// ALB-02：メニュー・確認
  ///
  /// In ja, this message translates to:
  /// **'アルバムを削除'**
  String get albDeleteTitle;

  /// ALB-02：確認
  ///
  /// In ja, this message translates to:
  /// **'アルバムの中の画像と動画もすべて削除され、元に戻せません'**
  String get albDeleteMessage;

  /// ALB-02・ALB-03：削除ボタン
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get albDeleteConfirm;

  /// ALB-02・ALB-03：確認
  ///
  /// In ja, this message translates to:
  /// **'項目を削除'**
  String get albDeleteItemsTitle;

  /// ALB-02：他の人の項目のみ選択
  ///
  /// In ja, this message translates to:
  /// **'削除できるのは自分が追加した項目だけです'**
  String get albDeleteOnlyMine;

  /// ALB-02・ALB-03：失敗
  ///
  /// In ja, this message translates to:
  /// **'操作できませんでした。もう一度お試しください'**
  String get albUpdateFailed;

  /// ALB-02・ALB-03：保存完了
  ///
  /// In ja, this message translates to:
  /// **'保存しました'**
  String get albSaved;

  /// ALB-02・ALB-03：保存失敗
  ///
  /// In ja, this message translates to:
  /// **'保存できませんでした'**
  String get albSaveFailed;

  /// ALB-02：動画の長さの上限
  ///
  /// In ja, this message translates to:
  /// **'5分を超える動画は追加できません'**
  String get albVideoTooLong;

  /// ALB-02：大きさの上限
  ///
  /// In ja, this message translates to:
  /// **'ファイルが大きすぎます'**
  String get albFileTooLarge;

  /// ALB-02：扱えない形式
  ///
  /// In ja, this message translates to:
  /// **'この形式には対応していません'**
  String get albUnsupported;

  /// ALB-02：ルールで拒否
  ///
  /// In ja, this message translates to:
  /// **'上限に達したか、今は追加できません'**
  String get albRejected;

  /// ALB-02：追加失敗
  ///
  /// In ja, this message translates to:
  /// **'通信状況をご確認ください'**
  String get albAddFailed;

  /// ALB-02：追加の再試行
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get albRetry;

  /// ALB-03：再生失敗
  ///
  /// In ja, this message translates to:
  /// **'動画を再生できませんでした'**
  String get albVideoLoadFailed;

  /// ALB-02：追加の進み具合
  ///
  /// In ja, this message translates to:
  /// **'追加中（{current}/{total}）'**
  String albUploading(int current, int total);

  /// ALB-01：件数
  ///
  /// In ja, this message translates to:
  /// **'{count}件'**
  String albItemCount(int count);

  /// ALB-02：選択中の件数
  ///
  /// In ja, this message translates to:
  /// **'{count}件を選択'**
  String albSelectedCount(int count);

  /// ALB-02・ALB-03：確認
  ///
  /// In ja, this message translates to:
  /// **'{count}件を削除します。元に戻せません'**
  String albDeleteItemsMessage(int count);

  /// ALB-02：確認
  ///
  /// In ja, this message translates to:
  /// **'自分が追加した{count}件を削除します。他の人の項目は残ります'**
  String albDeleteMineMessage(int count);

  /// ALB-02：追加の失敗件数
  ///
  /// In ja, this message translates to:
  /// **'{count}件を追加できませんでした。'**
  String albFailedCount(int count);

  /// CHA-02：アルバムの案内
  ///
  /// In ja, this message translates to:
  /// **'アルバムを作成し、{count}件を追加しました'**
  String albNoticeCreated(int count);

  /// CHA-02：アルバムの案内
  ///
  /// In ja, this message translates to:
  /// **'アルバムに{count}件を追加しました'**
  String albNoticeAdded(int count);

  /// AUT-02/03：運営者が停止した電話番号（AuthErrorCode.accountSuspended）
  ///
  /// In ja, this message translates to:
  /// **'このアカウントは利用を停止しています。お問い合わせ先にご連絡ください'**
  String get authErrorAccountSuspended;

  /// ACC-02：削除の繰り返しによる作成の制限（AccountCreationError.blocked）
  ///
  /// In ja, this message translates to:
  /// **'アカウントの削除を繰り返したため、しばらく新しいアカウントを作成できません'**
  String get accCreationBlocked;

  /// CHA-01：招待の行のメニュー
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get grpRequestMore;

  /// CHA-01：招待した人をブロックして拒否する
  ///
  /// In ja, this message translates to:
  /// **'招待した人をブロック'**
  String get grpRequestBlockInviter;

  /// ACC-02：1つ目のアカウントの作成で出す、招待してくれた人のID入力欄の見出し（機能仕様書4.3.5.2）
  ///
  /// In ja, this message translates to:
  /// **'招待してくれた人のアカウントID（任意）'**
  String get accCreationInviterLabel;

  /// ACC-02：招待してくれた人のID入力欄の見本
  ///
  /// In ja, this message translates to:
  /// **'例：orto_friend'**
  String get accCreationInviterHint;

  /// ACC-02：招待してくれた人のID入力欄の下の説明
  ///
  /// In ja, this message translates to:
  /// **'入れると、作成の後にその人を友だち追加できます'**
  String get accCreationInviterNote;

  /// AUT-02：招待の貼り付けボタンの案内の見出し（機能仕様書4.3.5.2）
  ///
  /// In ja, this message translates to:
  /// **'招待リンクから来ましたか？'**
  String get invitePasteTitle;

  /// AUT-02：招待の貼り付けボタンの案内の本文
  ///
  /// In ja, this message translates to:
  /// **'招待のページでコピーした招待を下のボタンで貼り付けると、ログインの後に、そのまま友だち追加やグループへの参加に進めます。'**
  String get invitePasteMessage;

  /// AUT-02：貼り付けた内容が招待リンクではなかったとき
  ///
  /// In ja, this message translates to:
  /// **'招待リンクではありませんでした'**
  String get invitePasteNotInvite;

  /// AUT-02：招待を貼り付けで受け取ったときの見出し
  ///
  /// In ja, this message translates to:
  /// **'招待を受け取りました'**
  String get invitePasteReceivedTitle;

  /// AUT-02：友だちの招待を受け取ったときの本文
  ///
  /// In ja, this message translates to:
  /// **'招待したアカウントのID：{accountId}\nログインとアカウントの作成の後に、友だち追加に進みます。'**
  String invitePasteReceivedFriend(String accountId);

  /// AUT-02：グループの招待を受け取ったときの本文
  ///
  /// In ja, this message translates to:
  /// **'ログインとアカウントの作成の後に、グループへの参加に進みます。'**
  String get invitePasteReceivedGroup;

  /// AUT-02：招待の貼り付けボタンの案内を閉じるボタン（読み上げ）
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get invitePasteClose;

  /// 外部から届いた友だちの招待で、使うアカウントを選ぶシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'どのアカウントで友だち追加しますか？'**
  String get inviteAccountTitleFriend;

  /// 外部から届いたグループの招待で、使うアカウントを選ぶシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'どのアカウントで参加しますか？'**
  String get inviteAccountTitleGroup;

  /// アカウントを選ぶシートの説明（ほかのアカウントは相手に見えない）
  ///
  /// In ja, this message translates to:
  /// **'相手には、選んだアカウントだけが見えます'**
  String get inviteAccountNote;

  /// アカウントを選ぶシート・送る側の表示：自分のアカウントID
  ///
  /// In ja, this message translates to:
  /// **'ID：{accountId}'**
  String inviteAccountId(String accountId);

  /// アカウントを選ぶシート：使用中のアカウントの印
  ///
  /// In ja, this message translates to:
  /// **'使用中'**
  String get inviteAccountCurrent;

  /// アカウントを選ぶシート：読み取り専用のアカウントを選べない理由
  ///
  /// In ja, this message translates to:
  /// **'読み取り専用のため選べません'**
  String get inviteAccountReadOnly;

  /// 招待で選んだアカウントに、使用中のアカウントを切り替えたときの案内
  ///
  /// In ja, this message translates to:
  /// **'{name}に切り替えました'**
  String inviteSwitchedAccount(String name);

  /// PRO-01：友だち追加に使うアカウント
  ///
  /// In ja, this message translates to:
  /// **'{name}で追加します'**
  String proAddAs(String name);

  /// GRP-04：招待する側のアカウント
  ///
  /// In ja, this message translates to:
  /// **'{name}として招待します'**
  String grpInviteAs(String name);

  /// FRI-03：招待文を送る前に出す、招待に使うアカウントの見出し
  ///
  /// In ja, this message translates to:
  /// **'このアカウントで招待します'**
  String get friInviteAsTitle;

  /// FRI-03：OSの共有シートを開くボタン
  ///
  /// In ja, this message translates to:
  /// **'招待文を送る'**
  String get friInviteSend;

  /// QRC-01のマイQRコード：どのアカウントのQRコードか
  ///
  /// In ja, this message translates to:
  /// **'このアカウントのQRコードです'**
  String get qrcMyQrAccountNote;

  /// GRP-06：タイトル
  ///
  /// In ja, this message translates to:
  /// **'グループの種類'**
  String get grpKindTitle;

  /// GRP-06：種類の名前
  ///
  /// In ja, this message translates to:
  /// **'普通のグループ'**
  String get grpKindStandard;

  /// GRP-06：普通のグループの説明
  ///
  /// In ja, this message translates to:
  /// **'友だちや仲間と話すグループです。全員が同じことをできます。'**
  String get grpKindStandardDescription;

  /// GRP-06：種類の名前
  ///
  /// In ja, this message translates to:
  /// **'オフ会グループ'**
  String get grpKindMeetup;

  /// GRP-06：オフ会グループの説明
  ///
  /// In ja, this message translates to:
  /// **'オフ会やイベントのためのグループです。主催チームがメンバーの管理やお知らせをします。会が終わると閉じます。'**
  String get grpKindMeetupDescription;

  /// GRP-06：注意書き
  ///
  /// In ja, this message translates to:
  /// **'種類はあとから変えられません'**
  String get grpKindFixedNote;

  /// オフ会グループの印（CHA-01・CHA-02・GRP-03）
  ///
  /// In ja, this message translates to:
  /// **'オフ会'**
  String get grpMeetupBadge;

  /// オフ会グループの、会の日時が決まる前の表示
  ///
  /// In ja, this message translates to:
  /// **'日時未定'**
  String get grpMeetupDateUndecided;

  /// オフ会グループの、閉じるまでの残り日数
  ///
  /// In ja, this message translates to:
  /// **'あと{count}日'**
  String grpMeetupDaysLeft(int count);

  /// オフ会グループの、閉じたあとの印（CHA-01・CHA-02・GRP-03）
  ///
  /// In ja, this message translates to:
  /// **'終了'**
  String get grpMeetupClosed;

  /// CHA-02：閉じたオフ会グループの入力欄の代わりの文（閉じる日時が分からないとき）
  ///
  /// In ja, this message translates to:
  /// **'このグループは閉じました'**
  String get grpMeetupClosedNotice;

  /// CHA-02：閉じたオフ会グループの入力欄の代わりの文
  ///
  /// In ja, this message translates to:
  /// **'このグループは閉じました。{date}に記録が消えます'**
  String grpMeetupClosedNoticeWithDate(String date);

  /// GRP-08：閉じる日の行
  ///
  /// In ja, this message translates to:
  /// **'グループを閉じる日'**
  String get grpCloseDayTitle;

  /// GRP-08：閉じる日（会の1日後）
  ///
  /// In ja, this message translates to:
  /// **'翌日'**
  String get grpCloseDayNextDay;

  /// GRP-08：閉じる日（会の3日後、初期値）
  ///
  /// In ja, this message translates to:
  /// **'3日後'**
  String get grpCloseDay3Days;

  /// GRP-08：閉じる日（会の7日後）
  ///
  /// In ja, this message translates to:
  /// **'1週間後'**
  String get grpCloseDayWeek;

  /// GRP-08：閉じる日（延長、会の{count}日後）
  ///
  /// In ja, this message translates to:
  /// **'会の{count}日後'**
  String grpCloseDayN(int count);

  /// GRP-08：閉じる日の注意書き
  ///
  /// In ja, this message translates to:
  /// **'会の日時から数えて閉じます。会のあとは、会の日から2週間まで延ばせます。閉じる24時間前と1時間前にメンバーに知らせます'**
  String get grpCloseDayNote;

  /// グループの操作の失敗：オフ会グループが閉じている
  ///
  /// In ja, this message translates to:
  /// **'このグループは閉じています'**
  String get grpErrorGroupClosed;

  /// グループの操作の失敗：閉じる日時が今から1時間以内
  ///
  /// In ja, this message translates to:
  /// **'1時間より後になる日を選んでください'**
  String get grpErrorInvalidCloseDays;

  /// システムメッセージ（閉じる日を変えた）
  ///
  /// In ja, this message translates to:
  /// **'{name}がグループを閉じる日時を変更しました'**
  String grpSysCloseUpdated(String name);

  /// システムメッセージ（閉じる24時間前の知らせ）
  ///
  /// In ja, this message translates to:
  /// **'このグループは24時間以内に閉じます'**
  String get grpSysClosingSoon24h;

  /// システムメッセージ（閉じる1時間前の知らせ）
  ///
  /// In ja, this message translates to:
  /// **'このグループは1時間以内に閉じます'**
  String get grpSysClosingSoon1h;

  /// システムメッセージ（期限が来て閉じた）
  ///
  /// In ja, this message translates to:
  /// **'グループは閉じました'**
  String get grpSysClosed;

  /// フォアグラウンドで閉じる24時間前の通知を受信したときのバナー本文。Cloud FunctionsのGROUP_CLOSING_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'{name}は24時間以内に閉じます'**
  String pushGroupClosing24hBanner(String name);

  /// フォアグラウンドで閉じる1時間前の通知を受信したときのバナー本文。Cloud FunctionsのGROUP_CLOSING_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'{name}は1時間以内に閉じます'**
  String pushGroupClosing1hBanner(String name);

  /// GRP-03：メンバー一覧の見出し
  ///
  /// In ja, this message translates to:
  /// **'主催チーム'**
  String get grpOrganizerTeamHeading;

  /// GRP-03：メンバー一覧の見出し（オフ会グループ）
  ///
  /// In ja, this message translates to:
  /// **'メンバー'**
  String get grpMembersHeading;

  /// GRP-03：主催チームの人の印
  ///
  /// In ja, this message translates to:
  /// **'主催'**
  String get grpOrganizerBadge;

  /// GRP-03：主催チームに誘われている人
  ///
  /// In ja, this message translates to:
  /// **'主催に誘い中'**
  String get grpOrganizerInvitedLabel;

  /// GRP-03：メニュー
  ///
  /// In ja, this message translates to:
  /// **'主催チームに入れる'**
  String get grpInviteToOrganizers;

  /// GRP-03：メニュー
  ///
  /// In ja, this message translates to:
  /// **'主催チームから外す'**
  String get grpRemoveFromOrganizers;

  /// GRP-03：確認
  ///
  /// In ja, this message translates to:
  /// **'{name}を主催チームから外しますか？'**
  String grpRemoveFromOrganizersConfirm(String name);

  /// GRP-03：自分の行のメニュー
  ///
  /// In ja, this message translates to:
  /// **'主催チームから抜ける'**
  String get grpLeaveOrganizers;

  /// GRP-03：確認
  ///
  /// In ja, this message translates to:
  /// **'主催チームから抜けますか？'**
  String get grpLeaveOrganizersConfirm;

  /// CHA-02：主催チームへの誘いのカード
  ///
  /// In ja, this message translates to:
  /// **'{name}から、主催チームに誘われています'**
  String grpOrganizerInviteCard(String name);

  /// CHA-02：誘いのカードのボタン
  ///
  /// In ja, this message translates to:
  /// **'入る'**
  String get grpOrganizerInviteAccept;

  /// CHA-02：誘いのカードのボタン
  ///
  /// In ja, this message translates to:
  /// **'断る'**
  String get grpOrganizerInviteDecline;

  /// グループの操作の失敗：主催チームの最後の1人
  ///
  /// In ja, this message translates to:
  /// **'主催チームがあなただけのため抜けられません。先にほかのメンバーを主催チームに入れてください。'**
  String get grpErrorLastOrganizer;

  /// システムメッセージ
  ///
  /// In ja, this message translates to:
  /// **'{name}が主催チームに入りました'**
  String grpSysOrganizerAdded(String name);

  /// システムメッセージ
  ///
  /// In ja, this message translates to:
  /// **'{name}が主催チームから外れました'**
  String grpSysOrganizerRemoved(String name);

  /// フォアグラウンドで主催チームへの誘いの通知を受信したときのバナー本文。Cloud FunctionsのORGANIZER_INVITE_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'主催チームに誘われています'**
  String get pushOrganizerInviteBanner;

  /// システムメッセージ・誘いのカード・確認の文に入れる人の名前（で「さん」を付ける。「退会済みアカウント」「不明なアカウント」には使わない）
  ///
  /// In ja, this message translates to:
  /// **'{name}さん'**
  String grpPersonName(String name);

  /// GRP-05：オフ会グループの申請ボタン
  ///
  /// In ja, this message translates to:
  /// **'参加を申請'**
  String get grpApplyJoin;

  /// GRP-05：申請の注意書き
  ///
  /// In ja, this message translates to:
  /// **'主催チームが承認すると参加できます。答えは主催チームの人だけが見ます。'**
  String get grpApplyNote;

  /// GRP-05：答えの欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'答えを入力'**
  String get grpApplyAnswerHint;

  /// GRP-05：承認待ち
  ///
  /// In ja, this message translates to:
  /// **'参加を申請しました。主催チームが承認すると、通知でお知らせします。'**
  String get grpApplyPending;

  /// GRP-05：キャンセル待ち
  ///
  /// In ja, this message translates to:
  /// **'キャンセル待ちになりました。空きが出たら、申請した順に主催チームが承認します。'**
  String get grpApplyWaitlisted;

  /// GRP-05・CHA-01・通知のバナー：断られた（Cloud FunctionsのJOIN_RESULT_NOTIFICATION_BODIESと揃える）
  ///
  /// In ja, this message translates to:
  /// **'{name}への参加は承認されませんでした'**
  String grpApplyDeclined(String name);

  /// GRP-05・通知のバナー：答えが出ないままグループが閉じた（Cloud FunctionsのJOIN_RESULT_NOTIFICATION_BODIESと揃える）
  ///
  /// In ja, this message translates to:
  /// **'{name}に参加できませんでした'**
  String grpApplyClosed(String name);

  /// GRP-05：断られたあとの再申請
  ///
  /// In ja, this message translates to:
  /// **'もう一度申請する'**
  String get grpApplyAgain;

  /// GRP-05：申請の取り消し
  ///
  /// In ja, this message translates to:
  /// **'申請を取り消す'**
  String get grpApplyCancel;

  /// 申請の取り消しの確認ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'申請を取り消しますか？'**
  String get grpApplyCancelConfirmTitle;

  /// 申請の取り消しの確認ダイアログの本文
  ///
  /// In ja, this message translates to:
  /// **'取り消すと、答えも消えます。'**
  String get grpApplyCancelConfirmMessage;

  /// 申請の取り消しの確認ボタン・CHA-01の行のボタン
  ///
  /// In ja, this message translates to:
  /// **'取り消す'**
  String get grpApplyCancelConfirm;

  /// CHA-01：出した参加の申請のセクション
  ///
  /// In ja, this message translates to:
  /// **'参加の申請（{count}）'**
  String grpApplicationSectionTitle(int count);

  /// CHA-01：申請の状態
  ///
  /// In ja, this message translates to:
  /// **'承認待ち'**
  String get grpApplicationPending;

  /// CHA-01：申請の状態
  ///
  /// In ja, this message translates to:
  /// **'キャンセル待ち'**
  String get grpApplicationWaitlisted;

  /// CHA-01：申請の状態
  ///
  /// In ja, this message translates to:
  /// **'承認されませんでした'**
  String get grpApplicationDeclined;

  /// CHA-01：申請の状態
  ///
  /// In ja, this message translates to:
  /// **'参加できませんでした'**
  String get grpApplicationClosed;

  /// CHA-02：主催チームに出す申請の帯
  ///
  /// In ja, this message translates to:
  /// **'参加の申請 {count}件'**
  String grpJoinRequestBanner(int count);

  /// GRP-03：GRP-09への行
  ///
  /// In ja, this message translates to:
  /// **'参加の申請'**
  String get grpJoinRequestsMenu;

  /// GRP-03：GRP-10への行
  ///
  /// In ja, this message translates to:
  /// **'参加時の質問'**
  String get grpJoinQuestionsMenu;

  /// GRP-03：質問の数
  ///
  /// In ja, this message translates to:
  /// **'{count}問'**
  String grpJoinQuestionsCount(int count);

  /// GRP-03：質問なし
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get grpJoinQuestionsNone;

  /// GRP-09：タイトル
  ///
  /// In ja, this message translates to:
  /// **'参加の申請'**
  String get grpJoinRequestsTitle;

  /// GRP-09：見出し
  ///
  /// In ja, this message translates to:
  /// **'承認待ち（{count}）'**
  String grpJoinRequestsPendingHeading(int count);

  /// GRP-09：見出し
  ///
  /// In ja, this message translates to:
  /// **'キャンセル待ち（{count}）'**
  String grpJoinRequestsWaitlistHeading(int count);

  /// GRP-09：キャンセル待ちの順番
  ///
  /// In ja, this message translates to:
  /// **'{order}番目'**
  String grpJoinRequestsWaitlistOrder(int order);

  /// GRP-09：0件
  ///
  /// In ja, this message translates to:
  /// **'届いている申請はありません'**
  String get grpJoinRequestsEmpty;

  /// GRP-09：質問なしの申請
  ///
  /// In ja, this message translates to:
  /// **'質問なし'**
  String get grpJoinRequestsNoQuestions;

  /// GRP-09：取得の失敗
  ///
  /// In ja, this message translates to:
  /// **'申請を読み込めませんでした'**
  String get grpJoinRequestsLoadError;

  /// GRP-09：承認ボタン
  ///
  /// In ja, this message translates to:
  /// **'承認'**
  String get grpJoinRequestApprove;

  /// GRP-09：断るボタン・確認ボタン
  ///
  /// In ja, this message translates to:
  /// **'断る'**
  String get grpJoinRequestDecline;

  /// GRP-09：断るの確認（名前はgrpPersonNameで「さん」付き）
  ///
  /// In ja, this message translates to:
  /// **'{name}の申請を断りますか？'**
  String grpJoinRequestDeclineTitle(String name);

  /// GRP-09：断るの確認の本文
  ///
  /// In ja, this message translates to:
  /// **'相手には「{group}への参加は承認されませんでした」とだけ知らせます。'**
  String grpJoinRequestDeclineMessage(String group);

  /// GRP-09：承認のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'承認しました'**
  String get grpJoinRequestApproved;

  /// GRP-09：満員でキャンセル待ちに回したSnackBar
  ///
  /// In ja, this message translates to:
  /// **'満員のため、キャンセル待ちに回しました'**
  String get grpJoinRequestWaitlisted;

  /// GRP-09：申請した人が参加できない状態（中身は見せない）
  ///
  /// In ja, this message translates to:
  /// **'この人は今は参加できません。時間をおいてお試しください'**
  String get grpErrorApplicantUnavailable;

  /// GRP-05：答えが質問に合わない
  ///
  /// In ja, this message translates to:
  /// **'質問が変わったため申請できませんでした。開き直してください'**
  String get grpErrorInvalidAnswers;

  /// GRP-10：タイトル
  ///
  /// In ja, this message translates to:
  /// **'参加時の質問'**
  String get grpJoinQuestionsTitle;

  /// GRP-10：説明
  ///
  /// In ja, this message translates to:
  /// **'招待リンクから参加を申請する人に答えてもらう質問です。3問まで決められます。答えは主催チームの人だけが見ます。'**
  String get grpJoinQuestionsDescription;

  /// GRP-10：入力欄のラベル
  ///
  /// In ja, this message translates to:
  /// **'質問{number}'**
  String grpJoinQuestionsLabel(int number);

  /// GRP-10：最初の欄の例
  ///
  /// In ja, this message translates to:
  /// **'例：Xの@IDを教えてください'**
  String get grpJoinQuestionsExample;

  /// GRP-10：追加ボタン
  ///
  /// In ja, this message translates to:
  /// **'質問を追加'**
  String get grpJoinQuestionsAdd;

  /// GRP-10：削除ボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'質問を削除'**
  String get grpJoinQuestionsRemove;

  /// GRP-10：注意書き
  ///
  /// In ja, this message translates to:
  /// **'質問を変えても、届いている申請の質問と答えはそのままです'**
  String get grpJoinQuestionsNote;

  /// GRP-10：保存のSnackBar
  ///
  /// In ja, this message translates to:
  /// **'保存しました'**
  String get grpJoinQuestionsSaved;

  /// GRP-10：戻るときの確認
  ///
  /// In ja, this message translates to:
  /// **'変更を破棄しますか？'**
  String get grpJoinQuestionsDiscardTitle;

  /// GRP-10：破棄ボタン
  ///
  /// In ja, this message translates to:
  /// **'破棄'**
  String get grpJoinQuestionsDiscard;

  /// GRP-04：オフ会グループの注意書き
  ///
  /// In ja, this message translates to:
  /// **'リンクから来た人は、主催チームが承認すると参加できます'**
  String get grpInviteMeetupNote;

  /// フォアグラウンドで申請の通知を受信したときのバナー本文。Cloud FunctionsのJOIN_REQUEST_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'参加の申請が届きました'**
  String get pushJoinRequestBanner;

  /// 申請の結果のバナー。Cloud FunctionsのJOIN_RESULT_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'{name}への参加が承認されました'**
  String pushJoinApprovedBanner(String name);

  /// 申請の結果のバナー。Cloud FunctionsのJOIN_RESULT_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'{name}のキャンセル待ちになりました'**
  String pushJoinWaitlistedBanner(String name);

  /// GRP-03：主催チームが見るメンバーの答えのシートの説明
  ///
  /// In ja, this message translates to:
  /// **'参加の申請のときの答え（主催チームだけが見られます）'**
  String get grpMemberJoinAnswersNote;

  /// GRP-03：答えのシートからPRO-01へ
  ///
  /// In ja, this message translates to:
  /// **'プロフィールを見る'**
  String get grpMemberJoinAnswersProfile;

  /// PRO-01：グループのメンバーへの友だち申請のボタン
  ///
  /// In ja, this message translates to:
  /// **'友だち申請'**
  String get frqSendButton;

  /// PRO-01：友だち申請に使うアカウント
  ///
  /// In ja, this message translates to:
  /// **'{name}で申請します'**
  String frqSendAs(String name);

  /// PRO-01：申請を送った後の表示（相手が断っても変わらない）
  ///
  /// In ja, this message translates to:
  /// **'申請中'**
  String get frqPending;

  /// PRO-01：相手から申請が届いているときのボタン
  ///
  /// In ja, this message translates to:
  /// **'承認する'**
  String get frqAcceptButton;

  /// PRO-01：「承認する」の下の説明
  ///
  /// In ja, this message translates to:
  /// **'友だち申請が届いています'**
  String get frqReceivedNotice;

  /// PRO-01：申請を送ったときのSnackBar
  ///
  /// In ja, this message translates to:
  /// **'友だち申請を送りました'**
  String get frqSent;

  /// 承認したときのSnackBar（nameはgrpPersonNameで「さん」を付ける）
  ///
  /// In ja, this message translates to:
  /// **'{name}と友だちになりました'**
  String frqAccepted(String name);

  /// PRO-01：申請の失敗
  ///
  /// In ja, this message translates to:
  /// **'申請に失敗しました。再度お試しください'**
  String get frqSendFailed;

  /// PRO-01：相手がもうグループにいない
  ///
  /// In ja, this message translates to:
  /// **'申請できませんでした。相手がグループを抜けた可能性があります'**
  String get frqNotMember;

  /// 承認・断るの失敗
  ///
  /// In ja, this message translates to:
  /// **'操作に失敗しました。再度お試しください'**
  String get frqRespondFailed;

  /// 申請が期限切れ・相手が退会済み・ブロック関係
  ///
  /// In ja, this message translates to:
  /// **'この申請は無効になっています'**
  String get frqInvalid;

  /// FRI-01：届いた友だち申請の見出し
  ///
  /// In ja, this message translates to:
  /// **'友だち申請 {count}件'**
  String frqSectionTitle(int count);

  /// FRI-01：申請を送ったグループ
  ///
  /// In ja, this message translates to:
  /// **'「{groupName}」から'**
  String frqFromGroup(String groupName);

  /// FRI-01：申請の承認
  ///
  /// In ja, this message translates to:
  /// **'承認'**
  String get frqAccept;

  /// FRI-01：申請を断る
  ///
  /// In ja, this message translates to:
  /// **'断る'**
  String get frqDecline;

  /// FRI-01：断る確認のタイトル
  ///
  /// In ja, this message translates to:
  /// **'友だち申請を断りますか？'**
  String get frqDeclineTitle;

  /// FRI-01：断る確認の本文
  ///
  /// In ja, this message translates to:
  /// **'断ったことは相手に知らされません。'**
  String get frqDeclineMessage;

  /// FRI-01：申請の行のメニュー
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get frqMore;

  /// フォアグラウンドで友だち申請の通知を受信したときのバナー本文。Cloud FunctionsのFRIEND_REQUEST_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'友だち申請が届きました'**
  String get pushFriendRequestBanner;

  /// システムメッセージ（お知らせを出した）
  ///
  /// In ja, this message translates to:
  /// **'{name}がお知らせを追加しました'**
  String grpSysAnnouncementPosted(String name);

  /// システムメッセージ（会の日時・場所を決めた・変えた）
  ///
  /// In ja, this message translates to:
  /// **'{name}が会の日時・場所を更新しました'**
  String grpSysEventUpdated(String name);

  /// CHA-02：オフ会グループのお知らせの枠で、会の場所が決まる前の表示
  ///
  /// In ja, this message translates to:
  /// **'場所未定'**
  String get annPlaceUndecided;

  /// CHA-02：たたんだお知らせの行
  ///
  /// In ja, this message translates to:
  /// **'お知らせ {count}件'**
  String annCollapsed(int count);

  /// CHA-02のお知らせの枠・GRP-07のタイトル
  ///
  /// In ja, this message translates to:
  /// **'お知らせを追加'**
  String get annAdd;

  /// GRP-07のタイトル（直すとき）
  ///
  /// In ja, this message translates to:
  /// **'お知らせを編集'**
  String get annEditTitle;

  /// GRP-07の投稿ボタン
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get annPost;

  /// CHA-02：お知らせの「…」のメニュー
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get annEdit;

  /// GRP-07：本文のプレースホルダ
  ///
  /// In ja, this message translates to:
  /// **'集合場所・時刻・持ち物など'**
  String get annTextHint;

  /// GRP-07・GRP-08：場所のプレースホルダ
  ///
  /// In ja, this message translates to:
  /// **'店名か住所（任意）'**
  String get annPlaceHint;

  /// GRP-07・GRP-08：場所の注意書き
  ///
  /// In ja, this message translates to:
  /// **'入れると、押したときに地図アプリで検索して開きます'**
  String get annPlaceNote;

  /// GRP-07・GRP-08：通知のスイッチ
  ///
  /// In ja, this message translates to:
  /// **'メンバーに通知する'**
  String get annNotifyMembers;

  /// CHA-02：お知らせを最後に直した日時
  ///
  /// In ja, this message translates to:
  /// **'{time}更新'**
  String annUpdatedAt(String time);

  /// お知らせの削除の確認ダイアログ
  ///
  /// In ja, this message translates to:
  /// **'このお知らせを削除しますか？'**
  String get annDeleteConfirm;

  /// お知らせが上限のとき
  ///
  /// In ja, this message translates to:
  /// **'お知らせは20件までです。古いお知らせを削除してから追加してください。'**
  String get annErrorLimit;

  /// 直そうとしたお知らせが消えていたとき
  ///
  /// In ja, this message translates to:
  /// **'このお知らせは削除されています'**
  String get annErrorNotFound;

  /// メッセージの長押しメニュー（主催チームのみ）
  ///
  /// In ja, this message translates to:
  /// **'お知らせにする'**
  String get annMakeFromMessage;

  /// GRP-08のタイトル
  ///
  /// In ja, this message translates to:
  /// **'会の日時と場所'**
  String get annEventTitle;

  /// CHA-02：会の日時の編集ボタンの読み上げ
  ///
  /// In ja, this message translates to:
  /// **'会の日時と場所を編集'**
  String get annEventEdit;

  /// GRP-08：日時の行
  ///
  /// In ja, this message translates to:
  /// **'日時'**
  String get annEventDate;

  /// GRP-08：日時が決まる前
  ///
  /// In ja, this message translates to:
  /// **'未定'**
  String get annEventDateUnset;

  /// GRP-08：注意書き
  ///
  /// In ja, this message translates to:
  /// **'会の日時は、決めたあとは変えられますが、未定には戻せません'**
  String get annEventNote;

  /// 会の日時が選べる範囲の外のとき
  ///
  /// In ja, this message translates to:
  /// **'今より後の日時を選んでください'**
  String get annErrorEventPast;

  /// 場所を押したときのシート（iOS）
  ///
  /// In ja, this message translates to:
  /// **'Apple マップで開く'**
  String get annOpenAppleMaps;

  /// 場所を押したときのシート（iOS）
  ///
  /// In ja, this message translates to:
  /// **'Google マップで開く'**
  String get annOpenGoogleMaps;

  /// 場所を押したときのシート
  ///
  /// In ja, this message translates to:
  /// **'場所をコピー'**
  String get annCopyPlace;

  /// 地図アプリを開けなかったとき
  ///
  /// In ja, this message translates to:
  /// **'地図アプリを開けませんでした'**
  String get annMapOpenFailed;

  /// フォアグラウンドでお知らせの通知を受信したときのバナー本文。Cloud FunctionsのANNOUNCEMENT_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'お知らせがあります'**
  String get pushAnnouncementBanner;

  /// お知らせの削除の確認ダイアログの本文
  ///
  /// In ja, this message translates to:
  /// **'メンバー全員の画面から消えます。'**
  String get annDeleteConfirmMessage;

  /// GRP-11のタイトル・CHA-02の出欠の行
  ///
  /// In ja, this message translates to:
  /// **'出欠'**
  String get attTitle;

  /// 出欠の答え「参加」
  ///
  /// In ja, this message translates to:
  /// **'参加'**
  String get attYes;

  /// 出欠の答え「不参加」
  ///
  /// In ja, this message translates to:
  /// **'不参加'**
  String get attNo;

  /// CHA-02の出欠の行の集計
  ///
  /// In ja, this message translates to:
  /// **'参加 {yes}・不参加 {no}・未回答 {unanswered}'**
  String attSummary(int yes, int no, int unanswered);

  /// CHA-02の出欠の行の締切
  ///
  /// In ja, this message translates to:
  /// **'締切 {date}'**
  String attDeadlineAt(String date);

  /// 出欠の締切を過ぎたときの印
  ///
  /// In ja, this message translates to:
  /// **'締切済み'**
  String get attDeadlinePassed;

  /// GRP-11：自分の答えの見出し
  ///
  /// In ja, this message translates to:
  /// **'あなたの出欠'**
  String get attMyResponse;

  /// GRP-11：締切の行
  ///
  /// In ja, this message translates to:
  /// **'締切'**
  String get attDeadlineLabel;

  /// GRP-11：締切なし
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get attDeadlineNone;

  /// GRP-11：締切の選択のシートで締切を消す
  ///
  /// In ja, this message translates to:
  /// **'締切なしにする'**
  String get attDeadlineClear;

  /// GRP-11：注意書き
  ///
  /// In ja, this message translates to:
  /// **'締切を過ぎても答えを変えられます。'**
  String get attNote;

  /// GRP-11：締切があるときの注意書き
  ///
  /// In ja, this message translates to:
  /// **'締切の24時間前に、未回答の人へ自動で通知します。'**
  String get attNoteAuto;

  /// GRP-11：主催チームの催促のボタン
  ///
  /// In ja, this message translates to:
  /// **'未回答の人に催促する'**
  String get attRemind;

  /// 催促の確認ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'未回答の{count}人に通知を送りますか？'**
  String attRemindConfirm(int count);

  /// 催促の確認ダイアログの本文
  ///
  /// In ja, this message translates to:
  /// **'6時間に1回まで送れます。'**
  String get attRemindConfirmMessage;

  /// 催促の確認ダイアログの実行ボタン
  ///
  /// In ja, this message translates to:
  /// **'送る'**
  String get attRemindSend;

  /// 催促のあとのSnackBar
  ///
  /// In ja, this message translates to:
  /// **'{count}人に通知しました'**
  String attReminded(int count);

  /// 締切を保存したあとのSnackBar
  ///
  /// In ja, this message translates to:
  /// **'締切を更新しました'**
  String get attDeadlineUpdated;

  /// GRP-11：一覧の見出し
  ///
  /// In ja, this message translates to:
  /// **'参加（{count}）'**
  String attSectionYes(int count);

  /// GRP-11：一覧の見出し
  ///
  /// In ja, this message translates to:
  /// **'不参加（{count}）'**
  String attSectionNo(int count);

  /// GRP-11：一覧の見出し
  ///
  /// In ja, this message translates to:
  /// **'未回答（{count}）'**
  String attSectionUnanswered(int count);

  /// 締切の範囲外
  ///
  /// In ja, this message translates to:
  /// **'締切は今より後で、会の日時までにしてください'**
  String get attErrorDeadline;

  /// 6時間以内の催促
  ///
  /// In ja, this message translates to:
  /// **'催促は6時間に1回までです。時間をおいてお試しください'**
  String get attErrorReminderTooSoon;

  /// システムメッセージ（出欠の締切）
  ///
  /// In ja, this message translates to:
  /// **'{name}が出欠の締切を更新しました'**
  String grpSysAttendanceDeadlineUpdated(String name);

  /// システムメッセージ（定員）
  ///
  /// In ja, this message translates to:
  /// **'{name}が定員を変更しました'**
  String grpSysCapacityUpdated(String name);

  /// 出欠の催促のバナー。Cloud FunctionsのATTENDANCE_REMINDER_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'出欠の回答をお願いします'**
  String get pushAttendanceReminderBanner;

  /// 繰り上がった人へのバナー。Cloud FunctionsのJOIN_RESULT_NOTIFICATION_BODIES.pendingと揃える
  ///
  /// In ja, this message translates to:
  /// **'{name}のキャンセル待ちから繰り上がりました'**
  String pushJoinPromotedBanner(String name);

  /// 主催チームへのバナー。Cloud FunctionsのWAITLIST_PROMOTED_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'キャンセル待ちから繰り上がった人がいます'**
  String get pushWaitlistPromotedBanner;

  /// GRP-03の定員の行・ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'定員'**
  String get capTitle;

  /// GRP-03の定員の値
  ///
  /// In ja, this message translates to:
  /// **'{count}人'**
  String capValue(int count);

  /// GRP-03：定員なし
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get capNone;

  /// 定員のダイアログの説明
  ///
  /// In ja, this message translates to:
  /// **'主催チームを含むメンバーの数で数えます。満員のあとの申請はキャンセル待ちになり、空きが出たら申請した順に繰り上がります。'**
  String get capDescription;

  /// 定員がメンバーより少ないときの注意
  ///
  /// In ja, this message translates to:
  /// **'今のメンバーは{count}人です。誰も退会にはなりませんが、空きが出るまで新しく入れません。'**
  String capBelowMembers(int count);

  /// 定員のダイアログで定員をなくす
  ///
  /// In ja, this message translates to:
  /// **'定員なし'**
  String get capClear;

  /// 定員の範囲外
  ///
  /// In ja, this message translates to:
  /// **'定員は2〜100人にしてください'**
  String get capErrorRange;

  /// GRP-03：グループ名と人数と定員
  ///
  /// In ja, this message translates to:
  /// **'{name}（{count}/{capacity}）'**
  String capMemberCount(String name, int count, int capacity);

  /// GRP-05：定員
  ///
  /// In ja, this message translates to:
  /// **'定員 {count}人'**
  String capPreview(int count);

  /// GRP-05：満員の注意
  ///
  /// In ja, this message translates to:
  /// **'満員のため、申請するとキャンセル待ちになります'**
  String get capPreviewFull;

  /// GRP-09：キャンセル待ちから繰り上がった承認待ちの印
  ///
  /// In ja, this message translates to:
  /// **'繰り上がり'**
  String get grpJoinRequestPromoted;

  /// GRP-12：タイトル
  ///
  /// In ja, this message translates to:
  /// **'精算'**
  String get stlTitle;

  /// 金額（3桁区切りの数字）
  ///
  /// In ja, this message translates to:
  /// **'{amount}円'**
  String stlYen(String amount);

  /// GRP-13：合計の入力の単位
  ///
  /// In ja, this message translates to:
  /// **'円'**
  String get stlYenSuffix;

  /// CHA-02の精算の行・GRP-12：主催チームが精算を始める
  ///
  /// In ja, this message translates to:
  /// **'精算を始める'**
  String get stlRowStart;

  /// CHA-02の精算の行（自分の額と状態）
  ///
  /// In ja, this message translates to:
  /// **'精算：{amount}・{status}'**
  String stlRowMine(String amount, String status);

  /// CHA-02の精算の行（自分が対象でないとき）
  ///
  /// In ja, this message translates to:
  /// **'精算：合計 {amount}'**
  String stlRowTotal(String amount);

  /// GRP-12：精算が無いとき
  ///
  /// In ja, this message translates to:
  /// **'精算はまだ始まっていません。'**
  String get stlNotStarted;

  /// GRP-12：自分が対象でないとき
  ///
  /// In ja, this message translates to:
  /// **'あなたは精算の対象ではありません。'**
  String get stlNotTarget;

  /// 払った記録の状態
  ///
  /// In ja, this message translates to:
  /// **'未払い'**
  String get stlStatusUnpaid;

  /// 払った記録の状態（本人が払ったを付けた）
  ///
  /// In ja, this message translates to:
  /// **'確認待ち'**
  String get stlStatusReported;

  /// 払った記録の状態（主催チームが確定）
  ///
  /// In ja, this message translates to:
  /// **'支払い済み'**
  String get stlStatusConfirmed;

  /// 払う額が0円の人
  ///
  /// In ja, this message translates to:
  /// **'支払いなし'**
  String get stlStatusFree;

  /// GRP-12・GRP-13：合計の金額
  ///
  /// In ja, this message translates to:
  /// **'合計'**
  String get stlTotalLabel;

  /// GRP-12：端数の単位
  ///
  /// In ja, this message translates to:
  /// **'{unit}円単位で切り上げ'**
  String stlRoundingValue(int unit);

  /// GRP-12：自分の額の見出し
  ///
  /// In ja, this message translates to:
  /// **'あなたの支払い'**
  String get stlMyShare;

  /// 区分の名前と割合
  ///
  /// In ja, this message translates to:
  /// **'{name}（{percent}%）'**
  String stlTierLabel(String name, int percent);

  /// GRP-12：払ったを付けるボタン
  ///
  /// In ja, this message translates to:
  /// **'払った'**
  String get stlReportPaid;

  /// GRP-12：払ったを取り消すボタン
  ///
  /// In ja, this message translates to:
  /// **'「払った」を取り消す'**
  String get stlReportCancel;

  /// GRP-12：確認待ちの説明
  ///
  /// In ja, this message translates to:
  /// **'主催チームの確認を待っています。'**
  String get stlReportedNote;

  /// GRP-12：確定の説明
  ///
  /// In ja, this message translates to:
  /// **'主催チームが受け取りを確かめました。'**
  String get stlConfirmedNote;

  /// GRP-12：払い方を選ぶシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'どうやって払いましたか？'**
  String get stlMethodTitle;

  /// 払い方：送金リンク
  ///
  /// In ja, this message translates to:
  /// **'送金サービス'**
  String get stlMethodLink;

  /// 払い方：現金
  ///
  /// In ja, this message translates to:
  /// **'現金'**
  String get stlMethodCash;

  /// 払い方：そのほか
  ///
  /// In ja, this message translates to:
  /// **'そのほか'**
  String get stlMethodOther;

  /// GRP-12：送金リンクの見出し
  ///
  /// In ja, this message translates to:
  /// **'送金先'**
  String get stlLinksHeading;

  /// GRP-12：送金リンクが無いとき
  ///
  /// In ja, this message translates to:
  /// **'送金先はまだありません。払い方は主催チームに確かめてください。'**
  String get stlLinksEmpty;

  /// GRP-12：PayPayのリンク
  ///
  /// In ja, this message translates to:
  /// **'PayPay'**
  String get stlLinkPayPay;

  /// GRP-12：PayPay ID（押すとコピー）
  ///
  /// In ja, this message translates to:
  /// **'PayPay ID：{id}'**
  String stlLinkPayPayId(String id);

  /// GRP-12：送金リンクを貼った人
  ///
  /// In ja, this message translates to:
  /// **'{name}が追加'**
  String stlLinkAddedBy(String name);

  /// GRP-12：PayPayの注意
  ///
  /// In ja, this message translates to:
  /// **'PayPay で送ると、あなたの表示名が相手に見えます。受け取りリンクの期限は4日です。'**
  String get stlPayPayNote;

  /// GRP-12：アプリの中で送金しないことの説明
  ///
  /// In ja, this message translates to:
  /// **'Orto の中でお金は動きません。送金は各サービスで行ってください。'**
  String get stlInAppNote;

  /// GRP-12：送金リンクを足すボタン・ダイアログの見出し
  ///
  /// In ja, this message translates to:
  /// **'送金先を追加'**
  String get stlLinkAdd;

  /// GRP-12：送金リンクを外す
  ///
  /// In ja, this message translates to:
  /// **'外す'**
  String get stlLinkRemove;

  /// GRP-12：送金リンクを外す確認
  ///
  /// In ja, this message translates to:
  /// **'この送金先を外しますか？'**
  String get stlLinkRemoveConfirm;

  /// 送金先の種類
  ///
  /// In ja, this message translates to:
  /// **'PayPay の受け取りリンク'**
  String get stlLinkServicePayPayUrl;

  /// 送金先の種類
  ///
  /// In ja, this message translates to:
  /// **'PayPay ID'**
  String get stlLinkServicePayPayId;

  /// 送金先の種類
  ///
  /// In ja, this message translates to:
  /// **'ほかのサービスのリンク'**
  String get stlLinkServiceOther;

  /// ほかのサービスの名前の入力
  ///
  /// In ja, this message translates to:
  /// **'サービスの名前（例：楽天ペイ）'**
  String get stlLinkLabelHint;

  /// PayPay IDの入力
  ///
  /// In ja, this message translates to:
  /// **'PayPay ID'**
  String get stlLinkIdHint;

  /// 送金リンクの入力の誤り
  ///
  /// In ja, this message translates to:
  /// **'PayPay のリンク（paypay.ne.jp）、PayPay ID、または https で始まるリンクを入れてください'**
  String get stlLinkInvalid;

  /// 送金先を足すダイアログの説明
  ///
  /// In ja, this message translates to:
  /// **'自分の PayPay で作った受け取りリンクか、PayPay ID を貼ってください。PayPay の請求リンクは、作る人・払う人とも本人確認が要ります。'**
  String get stlLinkAddNote;

  /// GRP-12：主催チームの一覧の見出し
  ///
  /// In ja, this message translates to:
  /// **'全員の支払い'**
  String get stlOrganizerHeading;

  /// 全員が払うと集まる額
  ///
  /// In ja, this message translates to:
  /// **'集まる額 {amount}'**
  String stlCollected(String amount);

  /// 集まる額が合計より多いとき
  ///
  /// In ja, this message translates to:
  /// **'集まる額 {amount}（端数の切り上げで合計より {surplus} 多い）'**
  String stlCollectedSurplus(String amount, String surplus);

  /// 確定した額の合計
  ///
  /// In ja, this message translates to:
  /// **'受け取り済み {amount}'**
  String stlConfirmedSum(String amount);

  /// GRP-12：一覧の見出し
  ///
  /// In ja, this message translates to:
  /// **'確認待ち（{count}）'**
  String stlSectionReported(int count);

  /// GRP-12：一覧の見出し
  ///
  /// In ja, this message translates to:
  /// **'未払い（{count}）'**
  String stlSectionUnpaid(int count);

  /// GRP-12：一覧の見出し
  ///
  /// In ja, this message translates to:
  /// **'支払い済み（{count}）'**
  String stlSectionConfirmed(int count);

  /// GRP-12：一覧の見出し
  ///
  /// In ja, this message translates to:
  /// **'支払いなし（{count}）'**
  String stlSectionFree(int count);

  /// グループを抜けた人の印
  ///
  /// In ja, this message translates to:
  /// **'退会'**
  String get stlLeft;

  /// GRP-12：確定のシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'{name}・{amount}'**
  String stlShareSheetTitle(String name, String amount);

  /// GRP-12：確認待ちの人を確定
  ///
  /// In ja, this message translates to:
  /// **'受け取りを確定'**
  String get stlConfirm;

  /// GRP-12：未払いの人を払い方を付けて確定
  ///
  /// In ja, this message translates to:
  /// **'{method}で受け取り済みにする'**
  String stlConfirmWith(String method);

  /// GRP-12：未払いに戻す
  ///
  /// In ja, this message translates to:
  /// **'未払いに戻す'**
  String get stlRevert;

  /// GRP-12：催促のボタン
  ///
  /// In ja, this message translates to:
  /// **'未払いの人に催促する'**
  String get stlRemind;

  /// GRP-12：催促の確認
  ///
  /// In ja, this message translates to:
  /// **'未払いの{count}人に通知を送りますか？'**
  String stlRemindConfirm(int count);

  /// GRP-12：自動の催促の説明
  ///
  /// In ja, this message translates to:
  /// **'グループが閉じる前（24時間前）にも、未払いの人へ自動で通知します。'**
  String get stlAutoNote;

  /// GRP-12：GRP-13を開く
  ///
  /// In ja, this message translates to:
  /// **'精算の設定を変える'**
  String get stlEdit;

  /// GRP-12：精算をやめる
  ///
  /// In ja, this message translates to:
  /// **'精算をやめる'**
  String get stlDelete;

  /// GRP-12：精算をやめる確認
  ///
  /// In ja, this message translates to:
  /// **'精算をやめますか？'**
  String get stlDeleteConfirm;

  /// GRP-12：精算をやめる確認の本文
  ///
  /// In ja, this message translates to:
  /// **'全員の金額と払った記録が消えます。'**
  String get stlDeleteConfirmMessage;

  /// GRP-13：タイトル
  ///
  /// In ja, this message translates to:
  /// **'精算の設定'**
  String get stlEditTitle;

  /// GRP-13：合計の入力
  ///
  /// In ja, this message translates to:
  /// **'合計の金額'**
  String get stlTotalHint;

  /// GRP-13：合計の入力の誤り
  ///
  /// In ja, this message translates to:
  /// **'1円〜1,000万円で入れてください'**
  String get stlErrorTotal;

  /// GRP-13：端数の単位の見出し
  ///
  /// In ja, this message translates to:
  /// **'端数'**
  String get stlRoundingTitle;

  /// GRP-13：端数の単位の選択肢
  ///
  /// In ja, this message translates to:
  /// **'{unit}円'**
  String stlRoundingOption(int unit);

  /// GRP-13：端数の説明
  ///
  /// In ja, this message translates to:
  /// **'一人ひとりの額をこの単位に切り上げます。合計より多く集まった分は主催チームで扱ってください。'**
  String get stlRoundingNote;

  /// GRP-13：区分の見出し
  ///
  /// In ja, this message translates to:
  /// **'区分（割合）'**
  String get stlTiersHeading;

  /// GRP-13：区分の説明
  ///
  /// In ja, this message translates to:
  /// **'区分ごとの割合で合計を分けます。例：通常 100%、飲まない 70%、主催 0%（無料）'**
  String get stlTiersNote;

  /// GRP-13：初めの区分の名前
  ///
  /// In ja, this message translates to:
  /// **'通常'**
  String get stlTierDefaultName;

  /// GRP-13：区分を足す
  ///
  /// In ja, this message translates to:
  /// **'区分を追加'**
  String get stlTierAdd;

  /// GRP-13：区分を足したあと
  ///
  /// In ja, this message translates to:
  /// **'区分を追加しました。対象の人の区分を選んでください'**
  String get stlTierAdded;

  /// GRP-13：区分のダイアログの見出し
  ///
  /// In ja, this message translates to:
  /// **'区分'**
  String get stlTierEditTitle;

  /// GRP-13：区分を消す
  ///
  /// In ja, this message translates to:
  /// **'区分を消す'**
  String get stlTierDelete;

  /// GRP-13：区分の名前の入力
  ///
  /// In ja, this message translates to:
  /// **'名前（例：飲まない）'**
  String get stlTierNameHint;

  /// GRP-13：区分の割合の入力
  ///
  /// In ja, this message translates to:
  /// **'割合'**
  String get stlTierPercentHint;

  /// GRP-13：区分の割合の説明
  ///
  /// In ja, this message translates to:
  /// **'0〜500%。100% が基準で、0% の人は払いません。'**
  String get stlTierPercentNote;

  /// GRP-13：区分の割合
  ///
  /// In ja, this message translates to:
  /// **'{percent}%'**
  String stlPercent(int percent);

  /// GRP-13：対象の見出し
  ///
  /// In ja, this message translates to:
  /// **'精算の対象（{count}人）'**
  String stlTargetsHeading(int count);

  /// GRP-13：対象の説明
  ///
  /// In ja, this message translates to:
  /// **'初めは出欠で「参加」と答えた人が入っています。'**
  String get stlTargetsNote;

  /// GRP-13：額が変わる人の確認
  ///
  /// In ja, this message translates to:
  /// **'{count}人の払った記録が未払いに戻ります'**
  String stlResetConfirm(int count);

  /// GRP-13：額が変わる人の確認の本文
  ///
  /// In ja, this message translates to:
  /// **'払う額が変わるため、払った記録を消して未払いに戻します。保存しますか？'**
  String get stlResetConfirmMessage;

  /// GRP-13：保存したあと（初めて）
  ///
  /// In ja, this message translates to:
  /// **'精算を始めました'**
  String get stlStarted;

  /// GRP-13：保存したあと
  ///
  /// In ja, this message translates to:
  /// **'精算の設定を保存しました'**
  String get stlSaved;

  /// 精算の値の誤り
  ///
  /// In ja, this message translates to:
  /// **'入力を確かめてください'**
  String get stlErrorInvalid;

  /// 精算が無い
  ///
  /// In ja, this message translates to:
  /// **'精算は始まっていないか、やめられました'**
  String get stlErrorNotFound;

  /// 精算の対象でない
  ///
  /// In ja, this message translates to:
  /// **'精算の対象ではありません'**
  String get stlErrorNotTarget;

  /// 確定のあとに払ったを取り消そうとした
  ///
  /// In ja, this message translates to:
  /// **'主催チームが確定したため取り消せません。主催チームに知らせてください'**
  String get stlErrorPaymentConfirmed;

  /// 送金リンクの上限
  ///
  /// In ja, this message translates to:
  /// **'送金先は5件までです'**
  String get stlErrorLinkLimit;

  /// システムメッセージ（精算）
  ///
  /// In ja, this message translates to:
  /// **'{name}が精算を始めました'**
  String grpSysSettlementStarted(String name);

  /// システムメッセージ（精算）
  ///
  /// In ja, this message translates to:
  /// **'{name}が精算の設定を変えました'**
  String grpSysSettlementUpdated(String name);

  /// システムメッセージ（精算）
  ///
  /// In ja, this message translates to:
  /// **'{name}が精算をやめました'**
  String grpSysSettlementDeleted(String name);

  /// 精算の催促のバナー。Cloud FunctionsのSETTLEMENT_REMINDER_NOTIFICATION_BODIESと揃える
  ///
  /// In ja, this message translates to:
  /// **'精算の支払いをお願いします'**
  String get pushSettlementReminderBanner;

  /// GRP-03・CHA-02：閉じたオフ会グループから次の回を作る
  ///
  /// In ja, this message translates to:
  /// **'次の回を作る'**
  String get nxtMenu;

  /// GRP-03：次の回がもう作られているときの「次の回を作る」の右の文
  ///
  /// In ja, this message translates to:
  /// **'作成済み'**
  String get nxtCreatedLabel;

  /// GRP-14のタイトル
  ///
  /// In ja, this message translates to:
  /// **'次の回を作る'**
  String get nxtTitle;

  /// GRP-14：グループ名の見出し
  ///
  /// In ja, this message translates to:
  /// **'グループ名'**
  String get nxtNameLabel;

  /// GRP-14の説明
  ///
  /// In ja, this message translates to:
  /// **'前の回のメンバーに招待を送ります。招待を承諾した人だけが次の回に入ります。'**
  String get nxtDescription;

  /// GRP-14：引き継ぐもの
  ///
  /// In ja, this message translates to:
  /// **'グループの画像・参加時の質問・定員・閉じる日を引き継ぎます。会の日時・場所・お知らせ・出欠は引き継ぎません。'**
  String get nxtCarriedNote;

  /// GRP-14：主催チームの引き継ぎ
  ///
  /// In ja, this message translates to:
  /// **'前の回の主催チームの人は、承諾すると主催チームにも入ります。'**
  String get nxtOrganizerNote;

  /// GRP-14：招待する人の見出し
  ///
  /// In ja, this message translates to:
  /// **'招待する人（{count}人）'**
  String nxtInviteHeading(int count);

  /// GRP-14：自分のほかにメンバーがいないとき
  ///
  /// In ja, this message translates to:
  /// **'招待できる前の回のメンバーはいません'**
  String get nxtNoMembers;

  /// GRP-14のボタン
  ///
  /// In ja, this message translates to:
  /// **'作って招待を送る'**
  String get nxtSubmit;

  /// 次の回を作ったときのSnackBar
  ///
  /// In ja, this message translates to:
  /// **'次の回を作りました'**
  String get nxtCreated;

  /// 次の回がもうあるとき
  ///
  /// In ja, this message translates to:
  /// **'次の回はすでに作られています'**
  String get nxtErrorExists;

  /// 閉じてから30日を過ぎたとき
  ///
  /// In ja, this message translates to:
  /// **'記録が消えたため、次の回を作れません'**
  String get nxtErrorExpired;

  /// CHA-01：次の回の招待の行の2行目
  ///
  /// In ja, this message translates to:
  /// **'「{previous}」の次の回・{name}からの招待'**
  String grpRequestNextRound(String previous, String name);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
