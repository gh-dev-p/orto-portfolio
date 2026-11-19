import Flutter
import StoreKit
import UIKit
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var videoProcessingChannel: VideoProcessingChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // UISceneの起動ではプラグインの登録がこのメソッドの後になり、firebase_messagingが通知の受け取り（APNsへの登録・
    // UNUserNotificationCenterのdelegate）を準備できないため、ここで準備させる（firebase_messagingのREADME）
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerInviteClipboardChannel(engineBridge.pluginRegistry)
    registerStoreRenewalChannel(engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VideoProcessing") {
      videoProcessingChannel = VideoProcessingChannel(messenger: registrar.messenger())
    }
  }

  // 招待リンクの引き継ぎ（機能仕様書4.3.5.2）。アプリはクリップボードの本文を自分では読まない
  // （読むとiOSの貼り付けの確認が出るため）。URLがあるかだけを確かめ（確認は出ない）、あれば
  // システムの貼り付けボタン（UIPasteControl、iOS 16以降）を出して、押されたときに受け取る。
  private func registerInviteClipboardChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "InviteClipboard") else { return }
    let channel = FlutterMethodChannel(
      name: "com.example.orto/invite_clipboard",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "hasUrl" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // 貼り付けボタンを出せない端末では、確かめない（アカウント作成画面の入力欄で受け取る）。
      guard #available(iOS 16.0, *) else {
        result(false)
        return
      }
      UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { detection in
        DispatchQueue.main.async {
          if case .success(let patterns) = detection {
            result(patterns.contains(.probableWebURL))
          } else {
            result(false)
          }
        }
      }
    }
    registrar.register(
      InvitePasteButtonFactory(channel: channel),
      withId: "com.example.orto/invite_paste_button"
    )
  }

  // Apple Accountの契約の取得（機能仕様書4.6.4.2・4.6.4.3）。RevenueCatのSDKでは取得できないため、StoreKitに問い合わせる
  private func registerStoreRenewalChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "StoreRenewal") else { return }
    let channel = FlutterMethodChannel(
      name: "com.example.orto/store_renewal",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch (call.method, call.arguments as? String) {
      case ("autoRenewProductId", let productId?):
        Task { @MainActor in
          result(try? await AppDelegate.autoRenewProductId(of: productId))
        }
      case ("activeProductIds", _):
        Task { @MainActor in
          result(await AppDelegate.activeProductIds())
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // このApple Accountで有効な自動更新のサブスクリプションの商品（機能仕様書4.6.4.2）
  private static func activeProductIds() async -> [String] {
    var productIds: [String] = []
    for await entitlement in Transaction.currentEntitlements {
      guard case .verified(let transaction) = entitlement,
        transaction.productType == .autoRenewable
      else { continue }
      productIds.append(transaction.productID)
    }
    return productIds
  }

  // [productId]の契約が次回の更新で切り替わる先の商品。解約済み・契約が無ければnil
  private static func autoRenewProductId(of productId: String) async throws -> String? {
    guard let subscription = try await Product.products(for: [productId]).first?.subscription else { return nil }
    for status in try await subscription.status {
      guard case .verified(let renewal) = status.renewalInfo,
        renewal.currentProductID == productId,
        renewal.willAutoRenew
      else { continue }
      return renewal.autoRenewPreference
    }
    return nil
  }
}
