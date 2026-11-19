import Flutter
import UIKit
import UniformTypeIdentifiers

// 招待リンクの貼り付けボタン（機能仕様書4.3.5.2）。システムの貼り付けボタン（UIPasteControl）を
// Flutterの画面に埋め込む。押されたときだけクリップボードの本文が渡るため、iOSの貼り付けの確認が出ない。
// 受け取った本文は、招待のチャンネルの`pasted`でDartに渡す（判定はDart側）。
final class InvitePasteButtonFactory: NSObject, FlutterPlatformViewFactory {
  private let channel: FlutterMethodChannel

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let params = args as? [String: Any]
    return InvitePasteButtonPlatformView(
      frame: frame,
      channel: channel,
      backgroundArgb: params?["background"] as? Int,
      foregroundArgb: params?["foreground"] as? Int
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class InvitePasteButtonPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView

  init(frame: CGRect, channel: FlutterMethodChannel, backgroundArgb: Int?, foregroundArgb: Int?) {
    if #available(iOS 16.0, *) {
      container = InvitePasteTargetView(
        frame: frame,
        channel: channel,
        background: backgroundArgb.map(UIColor.init(argb:)),
        foreground: foregroundArgb.map(UIColor.init(argb:))
      )
    } else {
      // iOS 15以前は、Dart側がボタンを出さない（hasUrlがfalse）。念のため空のビューにする。
      container = UIView(frame: frame)
    }
    super.init()
  }

  func view() -> UIView { container }
}

// 貼り付けボタンの受け取り先。受け付ける種類（URL・テキスト）がクリップボードに無い間、ボタンは押せない
@available(iOS 16.0, *)
final class InvitePasteTargetView: UIView {
  private let channel: FlutterMethodChannel

  init(frame: CGRect, channel: FlutterMethodChannel, background: UIColor?, foreground: UIColor?) {
    self.channel = channel
    super.init(frame: frame)
    backgroundColor = .clear
    pasteConfiguration = UIPasteConfiguration(acceptableTypeIdentifiers: [
      UTType.url.identifier, UTType.plainText.identifier,
    ])

    let configuration = UIPasteControl.Configuration()
    configuration.displayMode = .iconAndLabel
    configuration.cornerStyle = .capsule
    if let background { configuration.baseBackgroundColor = background }
    if let foreground { configuration.baseForegroundColor = foreground }
    let control = UIPasteControl(configuration: configuration)
    control.target = self
    control.translatesAutoresizingMaskIntoConstraints = false
    addSubview(control)
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: leadingAnchor),
      control.trailingAnchor.constraint(equalTo: trailingAnchor),
      control.topAnchor.constraint(equalTo: topAnchor),
      control.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func paste(itemProviders: [NSItemProvider]) {
    guard let provider = itemProviders.first else { return }
    if provider.canLoadObject(ofClass: URL.self) {
      _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
        self?.send(url?.absoluteString)
      }
    } else if provider.canLoadObject(ofClass: String.self) {
      _ = provider.loadObject(ofClass: String.self) { [weak self] text, _ in
        self?.send(text)
      }
    }
  }

  private func send(_ text: String?) {
    guard let text else { return }
    DispatchQueue.main.async { [channel] in
      channel.invokeMethod("pasted", arguments: text)
    }
  }
}

private extension UIColor {
  // FlutterのColor.toARGB32()の値から作る
  convenience init(argb: Int) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }
}
