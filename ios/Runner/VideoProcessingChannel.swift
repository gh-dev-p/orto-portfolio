import AVFoundation
import Flutter
import UIKit

// アルバムの動画の圧縮とサムネイルの生成（機能仕様書4.4.9）。Androidの`VideoProcessingChannel.kt`と、
// メソッド名・引数・戻り値・エラーコードを揃える。アプリ側の入口はlib/data/services/chat/video_processing_service.dart。
// エラーコードは invalid_input（読めないファイル）・unsupported（端末が扱えない形式）・failed（それ以外）。
final class VideoProcessingChannel {
  private struct ProcessingError: Error {
    let code: String
    let message: String
  }

  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "com.example.orto.video_processing", qos: .userInitiated)

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.example.orto/video_processing", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let inputPath = args["inputPath"] as? String else {
      result(FlutterError(code: "invalid_input", message: "inputPath is required", details: nil))
      return
    }
    let input = URL(fileURLWithPath: inputPath)
    let finish: (Result<[String: Any], Error>) -> Void = { outcome in
      DispatchQueue.main.async {
        switch outcome {
        case .success(let value):
          result(value)
        case .failure(let error as ProcessingError):
          result(FlutterError(code: error.code, message: error.message, details: nil))
        case .failure(let error):
          result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
        }
      }
    }

    Task.detached { [self] in
      do {
        switch call.method {
        case "probe":
          finish(.success(try await probe(input)))
        case "compress":
          finish(.success(try await compress(input, args: args)))
        case "thumbnail":
          finish(.success(try await thumbnail(input, args: args)))
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
        }
      } catch {
        finish(.failure(error))
      }
    }
  }

  // ---- 情報の取得 ----

  /// 回転を反映した表示の大きさと長さを返す
  private func probe(_ input: URL) async throws -> [String: Any] {
    let asset = AVURLAsset(url: input)
    let track = try await videoTrack(of: asset)
    let size = try await displaySize(of: track)
    let duration = try await asset.load(.duration)
    return [
      "durationMs": milliseconds(duration),
      "width": Int(size.width),
      "height": Int(size.height),
    ]
  }

  private func videoTrack(of asset: AVURLAsset) async throws -> AVAssetTrack {
    let tracks: [AVAssetTrack]
    do {
      tracks = try await asset.loadTracks(withMediaType: .video)
    } catch {
      throw ProcessingError(code: "invalid_input", message: error.localizedDescription)
    }
    guard let track = tracks.first else {
      throw ProcessingError(code: "invalid_input", message: "no video track")
    }
    return track
  }

  private func displaySize(of track: AVAssetTrack) async throws -> CGSize {
    let natural = try await track.load(.naturalSize)
    let transform = try await track.load(.preferredTransform)
    let size = natural.applying(transform)
    return CGSize(width: abs(size.width), height: abs(size.height))
  }

  private func milliseconds(_ time: CMTime) -> Int {
    time.isNumeric ? Int(CMTimeGetSeconds(time) * 1000) : 0
  }

  // ---- 圧縮 ----

  /// 短辺[maxShortSide]以下・H.264・AACのmp4にする。拡大はしない
  /// 回転はVideoCompositionで映像に焼き込み、HDRはSDR（BT.709）に変換する（Androidと同じ出力にするため）
  private func compress(_ input: URL, args: [String: Any]) async throws -> [String: Any] {
    guard let outputPath = args["outputPath"] as? String,
      let taskId = args["taskId"] as? String,
      let maxShortSide = args["maxShortSide"] as? Int,
      let videoBitrate = args["videoBitrate"] as? Int,
      let audioBitrate = args["audioBitrate"] as? Int,
      let maxFrameRate = args["maxFrameRate"] as? Int
    else {
      throw ProcessingError(code: "invalid_input", message: "missing arguments")
    }
    let output = URL(fileURLWithPath: outputPath)
    try? FileManager.default.removeItem(at: output)

    let asset = AVURLAsset(url: input)
    let track = try await videoTrack(of: asset)
    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
    let duration = try await asset.load(.duration)
    let target = VideoProcessingChannel.targetSize(try await displaySize(of: track), maxShortSide: CGFloat(maxShortSide))

    let composition = AVMutableVideoComposition(propertiesOf: asset)
    composition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
    composition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
    composition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
    let minFrameDuration = CMTime(value: 1, timescale: CMTimeScale(maxFrameRate))
    if composition.frameDuration < minFrameDuration { composition.frameDuration = minFrameDuration }

    let reader: AVAssetReader
    let writer: AVAssetWriter
    do {
      reader = try AVAssetReader(asset: asset)
      writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
    } catch {
      throw ProcessingError(code: "failed", message: error.localizedDescription)
    }
    writer.shouldOptimizeForNetworkUse = true

    let videoOutput = AVAssetReaderVideoCompositionOutput(
      videoTracks: [track],
      videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
    )
    videoOutput.videoComposition = composition
    let videoInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: Int(target.width),
        AVVideoHeightKey: Int(target.height),
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: videoBitrate],
        AVVideoColorPropertiesKey: [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
      ]
    )
    videoInput.expectsMediaDataInRealTime = false
    guard reader.canAdd(videoOutput), writer.canAdd(videoInput) else {
      throw ProcessingError(code: "unsupported", message: "cannot read or write the video track")
    }
    reader.add(videoOutput)
    writer.add(videoInput)

    var audioPair: (AVAssetReaderTrackOutput, AVAssetWriterInput)?
    if let audioTrack = audioTracks.first {
      let audioOutput = AVAssetReaderTrackOutput(
        track: audioTrack,
        outputSettings: [
          AVFormatIDKey: kAudioFormatLinearPCM,
          AVSampleRateKey: 44100,
          AVNumberOfChannelsKey: 2,
        ]
      )
      let audioInput = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: 44100,
          AVNumberOfChannelsKey: 2,
          AVEncoderBitRateKey: audioBitrate,
        ]
      )
      audioInput.expectsMediaDataInRealTime = false
      if reader.canAdd(audioOutput), writer.canAdd(audioInput) {
        reader.add(audioOutput)
        writer.add(audioInput)
        audioPair = (audioOutput, audioInput)
      }
    }

    guard reader.startReading(), writer.startWriting() else {
      throw ProcessingError(code: "unsupported", message: "\(reader.error ?? writer.error as Error? ?? ProcessingError(code: "failed", message: "start failed"))")
    }
    writer.startSession(atSourceTime: .zero)

    let group = DispatchGroup()
    let durationSeconds = max(CMTimeGetSeconds(duration), 0.001)
    var lastReported = -1.0
    pump(videoOutput, into: videoInput, group: group) { [weak self] time in
      let progress = min(CMTimeGetSeconds(time) / durationSeconds, 1)
      guard progress - lastReported >= 0.02 else { return }
      lastReported = progress
      self?.reportProgress(taskId: taskId, progress: progress)
    }
    if let (audioOutput, audioInput) = audioPair {
      pump(audioOutput, into: audioInput, group: group, onSample: nil)
    }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      group.notify(queue: queue) { continuation.resume() }
    }

    if reader.status == .failed {
      writer.cancelWriting()
      throw ProcessingError(code: "failed", message: reader.error?.localizedDescription ?? "read failed")
    }
    await writer.finishWriting()
    guard writer.status == .completed else {
      throw ProcessingError(code: "failed", message: writer.error?.localizedDescription ?? "write failed")
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
    return [
      "durationMs": milliseconds(duration),
      "width": Int(target.width),
      "height": Int(target.height),
      "sizeBytes": (attributes[.size] as? NSNumber)?.intValue ?? 0,
    ]
  }

  /// [source]のサンプルが尽きるまで、[input]へ渡す
  private func pump(
    _ source: AVAssetReaderOutput,
    into input: AVAssetWriterInput,
    group: DispatchGroup,
    onSample: ((CMTime) -> Void)?
  ) {
    group.enter()
    let inputQueue = DispatchQueue(label: "com.example.orto.video_processing.\(input.mediaType.rawValue)")
    input.requestMediaDataWhenReady(on: inputQueue) {
      while input.isReadyForMoreMediaData {
        guard let sample = source.copyNextSampleBuffer() else {
          input.markAsFinished()
          group.leave()
          return
        }
        onSample?(CMSampleBufferGetPresentationTimeStamp(sample))
        if !input.append(sample) {
          input.markAsFinished()
          group.leave()
          return
        }
      }
    }
  }

  private func reportProgress(taskId: String, progress: Double) {
    DispatchQueue.main.async { [channel] in
      channel.invokeMethod("progress", arguments: ["taskId": taskId, "progress": progress])
    }
  }

  /// 短辺が[maxShortSide]以下になる大きさ（H.264のため偶数にそろえる）
  static func targetSize(_ size: CGSize, maxShortSide: CGFloat) -> CGSize {
    let scale = min(maxShortSide / min(size.width, size.height), 1)
    let even = { (value: CGFloat) in max(floor(value * scale / 2) * 2, 2) }
    return CGSize(width: even(size.width), height: even(size.height))
  }

  // ---- サムネイル ----

  /// 先頭付近のフレームをJPEGで保存する。回転を反映し、長辺を[maxSide]以下にする
  private func thumbnail(_ input: URL, args: [String: Any]) async throws -> [String: Any] {
    guard let outputPath = args["outputPath"] as? String,
      let maxSide = args["maxSide"] as? Int,
      let quality = args["quality"] as? Int
    else {
      throw ProcessingError(code: "invalid_input", message: "missing arguments")
    }
    let asset = AVURLAsset(url: input)
    _ = try await videoTrack(of: asset)
    let duration = try await asset.load(.duration)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: maxSide, height: maxSide)
    let seconds = min(0.5, CMTimeGetSeconds(duration) / 2)
    let image: CGImage
    do {
      image = try generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil)
    } catch {
      throw ProcessingError(code: "unsupported", message: error.localizedDescription)
    }
    guard let data = UIImage(cgImage: image).jpegData(compressionQuality: CGFloat(quality) / 100) else {
      throw ProcessingError(code: "failed", message: "jpeg encoding failed")
    }
    try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    return ["width": image.width, "height": image.height]
  }
}
