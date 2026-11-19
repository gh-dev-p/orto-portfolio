import Flutter
import UIKit

// アプリスイッチャーのスナップショットにトークの内容を残さない（機能仕様書4.2.4.3）。
// iOSはアプリが隠れる直前の画面を保存するため、前面でなくなった時点で無地の覆いを重ねる。
// Flutterの描画は間に合わない場合があるので、ネイティブのビューで覆う。
class SnapshotHidingSceneDelegate: FlutterSceneDelegate {
  // 戻った直後にパスコードのガードが描かれるのを待つ時間
  private static let revealDelay: TimeInterval = 0.15

  private var cover: UIView?
  private var pendingReveal: DispatchWorkItem?

  override func sceneWillResignActive(_ scene: UIScene) {
    pendingReveal?.cancel()
    if cover == nil, let window = window {
      let view = UIView(frame: window.bounds)
      view.backgroundColor = .systemBackground
      view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      window.addSubview(view)
      cover = view
    }
    super.sceneWillResignActive(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    let reveal = DispatchWorkItem { [weak self] in
      self?.cover?.removeFromSuperview()
      self?.cover = nil
    }
    pendingReveal = reveal
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealDelay, execute: reveal)
  }
}
