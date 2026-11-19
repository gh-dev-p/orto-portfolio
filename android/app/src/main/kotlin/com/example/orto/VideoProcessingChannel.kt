package com.example.orto

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.FrameDropEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

// アルバムの動画の圧縮とサムネイルの生成（機能仕様書4.4.9）。iOSの`VideoProcessingChannel.swift`と、
// メソッド名・引数・戻り値・エラーコードを揃える。アプリ側の入口はlib/data/services/chat/video_processing_service.dart。
// エラーコードは invalid_input（読めないファイル）・unsupported（端末が扱えない形式）・failed（それ以外）。
@OptIn(UnstableApi::class)
class VideoProcessingChannel(private val context: Context, messenger: BinaryMessenger) {
    private class ProcessingError(val code: String, message: String) : Exception(message)

    private val channel = MethodChannel(messenger, "com.example.orto/video_processing")
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    init {
        channel.setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val inputPath = call.argument<String>("inputPath")
        if (inputPath == null) {
            result.error("invalid_input", "inputPath is required", null)
            return
        }
        when (call.method) {
            "probe" -> runInBackground(result) { probe(inputPath) }
            "thumbnail" -> runInBackground(result) { thumbnail(inputPath, call) }
            "compress" -> compress(inputPath, call, result)
            else -> result.notImplemented()
        }
    }

    private fun runInBackground(result: MethodChannel.Result, work: () -> Map<String, Any>) {
        executor.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: ProcessingError) {
                main.post { result.error(e.code, e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message, null) }
            }
        }
    }

    // ---- 情報の取得 ----

    private class VideoInfo(val durationMs: Long, val width: Int, val height: Int)

    /** 回転を反映した表示の大きさと長さを読む */
    private fun readInfo(path: String): VideoInfo {
        val retriever = openRetriever(path)
        try {
            val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
            if (width == null || height == null) throw ProcessingError("invalid_input", "no video track")
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
            val rotated = rotation == 90 || rotation == 270
            return VideoInfo(duration, if (rotated) height else width, if (rotated) width else height)
        } finally {
            retriever.release()
        }
    }

    private fun openRetriever(path: String): MediaMetadataRetriever {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
        } catch (e: RuntimeException) {
            retriever.release()
            throw ProcessingError("invalid_input", e.message ?: "cannot open the file")
        }
        return retriever
    }

    private fun probe(path: String): Map<String, Any> {
        val info = readInfo(path)
        return mapOf("durationMs" to info.durationMs, "width" to info.width, "height" to info.height)
    }

    // ---- 圧縮 ----

    /** 短辺[maxShortSide]以下・H.264・AACのmp4にする。拡大はしない。回転は映像に焼き込み、HDRはSDRに変換する */
    private fun compress(inputPath: String, call: MethodCall, result: MethodChannel.Result) {
        val outputPath = call.argument<String>("outputPath")
        val taskId = call.argument<String>("taskId")
        val maxShortSide = call.argument<Int>("maxShortSide")
        val videoBitrate = call.argument<Int>("videoBitrate")
        val audioBitrate = call.argument<Int>("audioBitrate")
        val maxFrameRate = call.argument<Int>("maxFrameRate")
        if (outputPath == null || taskId == null || maxShortSide == null || videoBitrate == null ||
            audioBitrate == null || maxFrameRate == null
        ) {
            result.error("invalid_input", "missing arguments", null)
            return
        }
        executor.execute {
            val info = try {
                readInfo(inputPath)
            } catch (e: ProcessingError) {
                main.post { result.error(e.code, e.message, null) }
                return@execute
            }
            main.post {
                startExport(inputPath, outputPath, taskId, info, maxShortSide, videoBitrate, audioBitrate, maxFrameRate, result)
            }
        }
    }

    // Transformerは作ったスレッドのLooperで動くので、メインスレッドで呼ぶ。
    private fun startExport(
        inputPath: String,
        outputPath: String,
        taskId: String,
        info: VideoInfo,
        maxShortSide: Int,
        videoBitrate: Int,
        audioBitrate: Int,
        maxFrameRate: Int,
        result: MethodChannel.Result,
    ) {
        val videoEffects = mutableListOf<Effect>(FrameDropEffect.createDefaultFrameDropEffect(maxFrameRate.toFloat()))
        if (min(info.width, info.height) > maxShortSide) {
            videoEffects += Presentation.createForShortSide(maxShortSide)
        }
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(inputPath))))
            .setEffects(Effects(emptyList(), videoEffects))
            .build()
        val composition = Composition.Builder(EditedMediaItemSequence.Builder(item).build())
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
            .build()
        val encoders = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(videoBitrate).build())
            .setRequestedAudioEncoderSettings(AudioEncoderSettings.Builder().setBitrate(audioBitrate).build())
            .build()

        val holder = ProgressHolder()
        lateinit var transformer: Transformer
        val poll = object : Runnable {
            override fun run() {
                if (transformer.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel.invokeMethod("progress", mapOf("taskId" to taskId, "progress" to holder.progress / 100.0))
                }
                main.postDelayed(this, PROGRESS_INTERVAL_MS)
            }
        }
        transformer = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoders)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    main.removeCallbacks(poll)
                    runInBackground(result) {
                        val output = readInfo(outputPath)
                        mapOf(
                            "durationMs" to output.durationMs,
                            "width" to output.width,
                            "height" to output.height,
                            "sizeBytes" to File(outputPath).length(),
                        )
                    }
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exception: ExportException) {
                    main.removeCallbacks(poll)
                    File(outputPath).delete()
                    result.error(errorCode(exception), exception.message, null)
                }
            })
            .build()
        File(outputPath).delete()
        try {
            transformer.start(composition, outputPath)
        } catch (e: RuntimeException) {
            result.error("failed", e.message, null)
            return
        }
        main.post(poll)
    }

    private fun errorCode(exception: ExportException): String = when (exception.errorCode) {
        ExportException.ERROR_CODE_IO_FILE_NOT_FOUND -> "invalid_input"
        ExportException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED,
        ExportException.ERROR_CODE_ENCODING_FORMAT_UNSUPPORTED,
        ExportException.ERROR_CODE_MUXING_FAILED -> "unsupported"
        else -> "failed"
    }

    // ---- サムネイル ----

    /** 先頭付近のフレームをJPEGで保存する。回転を反映し、長辺を[maxSide]以下にする */
    private fun thumbnail(inputPath: String, call: MethodCall): Map<String, Any> {
        val outputPath = call.argument<String>("outputPath")
        val maxSide = call.argument<Int>("maxSide")
        val quality = call.argument<Int>("quality")
        if (outputPath == null || maxSide == null || quality == null) {
            throw ProcessingError("invalid_input", "missing arguments")
        }
        val info = readInfo(inputPath)
        val retriever = openRetriever(inputPath)
        try {
            val timeUs = min(THUMBNAIL_TIME_US, info.durationMs * 1000 / 2)
            val frame = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: throw ProcessingError("unsupported", "cannot decode a frame")
            val scale = min(maxSide.toFloat() / max(frame.width, frame.height), 1f)
            val scaled = Bitmap.createScaledBitmap(
                frame,
                max((frame.width * scale).toInt(), 1),
                max((frame.height * scale).toInt(), 1),
                true,
            )
            FileOutputStream(outputPath).use { scaled.compress(Bitmap.CompressFormat.JPEG, quality, it) }
            return mapOf("width" to scaled.width, "height" to scaled.height)
        } finally {
            retriever.release()
        }
    }

    private companion object {
        const val PROGRESS_INTERVAL_MS = 300L
        const val THUMBNAIL_TIME_US = 500_000L
    }
}
