package app.mediaurl.applicaiton

import android.content.Intent
import android.os.Bundle
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import app.mediaurl.applicaiton.playcore.AppUpdateHelper
import app.mediaurl.applicaiton.playcore.InAppReviewHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val MUXER_CHANNEL = "app.mediaurl.applicaiton/muxer"
    private val PLAYCORE_CHANNEL = "app.mediaurl.applicaiton/playcore"
    private val SHARE_CHANNEL = "app.mediaurl.applicaiton/share"

    private lateinit var appUpdateHelper: AppUpdateHelper
    private lateinit var inAppReviewHelper: InAppReviewHelper
    private var sharedText: String? = null
    private var shareChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appUpdateHelper = AppUpdateHelper(this)
        inAppReviewHelper = InAppReviewHelper(this)

        // Automatically check for available flexible updates on cold launch
        appUpdateHelper.checkForUpdate()

        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        if (Intent.ACTION_SEND == action && type != null) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text?.toString()
            if (!text.isNullOrBlank()) {
                sharedText = text
                shareChannel?.invokeMethod("onShareReceived", text)
            }
        } else if (Intent.ACTION_VIEW == action) {
            val data = intent.dataString
            if (!data.isNullOrBlank()) {
                sharedText = data
                shareChannel?.invokeMethod("onShareReceived", data)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (::appUpdateHelper.isInitialized) {
            appUpdateHelper.onResume()
        }
    }

    override fun onPause() {
        super.onPause()
        if (::appUpdateHelper.isInitialized) {
            appUpdateHelper.onPause()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Share Channel for receiving shared links from YouTube, Instagram, etc.
        val shareMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        this.shareChannel = shareMethodChannel
        shareMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedText" -> {
                    val initial = sharedText
                    sharedText = null
                    result.success(initial)
                }
                "clearSharedText" -> {
                    sharedText = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        val currentShared = sharedText
        if (!currentShared.isNullOrBlank()) {
            shareMethodChannel.invokeMethod("onShareReceived", currentShared)
        }

        // Play Core In-App Update and In-App Review Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAYCORE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkForUpdate" -> {
                    if (::appUpdateHelper.isInitialized) {
                        appUpdateHelper.checkForUpdate { isAvailable ->
                            result.success(isAvailable)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "completeUpdate" -> {
                    if (::appUpdateHelper.isInitialized) {
                        appUpdateHelper.completeUpdate()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "recordSuccessfulAction" -> {
                    if (::inAppReviewHelper.isInitialized) {
                        inAppReviewHelper.recordSuccessfulAction()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "tryRequestReview" -> {
                    val force = call.argument<Boolean>("force") ?: false
                    if (::inAppReviewHelper.isInitialized) {
                        inAppReviewHelper.tryRequestReview(force) {
                            result.success(true)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Muxer channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MUXER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "muxMedia") {
                val videoPath = call.argument<String>("videoPath")
                val audioPath = call.argument<String>("audioPath")
                val outputPath = call.argument<String>("outputPath")

                if (videoPath == null || audioPath == null || outputPath == null) {
                    result.error("INVALID_ARGS", "Missing paths for muxing", null)
                    return@setMethodCallHandler
                }

                Thread {
                    try {
                        val success = mux(videoPath, audioPath, outputPath)
                        runOnUiThread {
                            if (success) {
                                result.success(outputPath)
                            } else {
                                result.error("MUX_FAILED", "Native MediaMuxer failed to combine tracks", null)
                            }
                        }
                    } catch (e: Exception) {
                        runOnUiThread {
                            result.error("MUX_ERROR", e.localizedMessage ?: "Unknown error", null)
                        }
                    }
                }.start()
            } else {
                result.notImplemented()
            }
        }
    }

    private fun mux(videoPath: String, audioPath: String, outputPath: String): Boolean {
        var videoExtractor: MediaExtractor? = null
        var audioExtractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null

        try {
            videoExtractor = MediaExtractor().apply { setDataSource(videoPath) }
            audioExtractor = MediaExtractor().apply { setDataSource(audioPath) }

            var videoTrackIndex = -1
            var videoFormat: MediaFormat? = null
            for (i in 0 until videoExtractor.trackCount) {
                val format = videoExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("video/")) {
                    videoTrackIndex = i
                    videoFormat = format
                    break
                }
            }

            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null
            for (i in 0 until audioExtractor.trackCount) {
                val format = audioExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }

            if (videoTrackIndex == -1 || videoFormat == null) {
                return false
            }

            val outFile = File(outputPath)
            if (outFile.exists()) {
                outFile.delete()
            }

            val formatType = if (outputPath.endsWith(".webm", ignoreCase = true)) {
                MediaMuxer.OutputFormat.MUXER_OUTPUT_WEBM
            } else {
                MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
            }

            muxer = MediaMuxer(outputPath, formatType)
            val muxerVideoTrack = muxer.addTrack(videoFormat)
            val muxerAudioTrack = if (audioTrackIndex != -1 && audioFormat != null) {
                try {
                    muxer.addTrack(audioFormat)
                } catch (_: Exception) {
                    -1
                }
            } else {
                -1
            }

            muxer.start()

            // Copy video stream
            videoExtractor.selectTrack(videoTrackIndex)
            val maxVideoBuf = if (videoFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                videoFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE).coerceAtLeast(1024 * 1024)
            } else {
                2 * 1024 * 1024
            }
            val videoBuf = ByteBuffer.allocate(maxVideoBuf)
            val bufferInfo = MediaCodec.BufferInfo()

            while (true) {
                bufferInfo.offset = 0
                bufferInfo.size = videoExtractor.readSampleData(videoBuf, 0)
                if (bufferInfo.size < 0) break
                bufferInfo.presentationTimeUs = videoExtractor.sampleTime
                bufferInfo.flags = videoExtractor.sampleFlags
                muxer.writeSampleData(muxerVideoTrack, videoBuf, bufferInfo)
                videoExtractor.advance()
            }

            // Copy audio stream
            if (audioTrackIndex != -1 && muxerAudioTrack != -1 && audioFormat != null) {
                audioExtractor.selectTrack(audioTrackIndex)
                val maxAudioBuf = if (audioFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    audioFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE).coerceAtLeast(512 * 1024)
                } else {
                    512 * 1024
                }
                val audioBuf = ByteBuffer.allocate(maxAudioBuf)

                while (true) {
                    bufferInfo.offset = 0
                    bufferInfo.size = audioExtractor.readSampleData(audioBuf, 0)
                    if (bufferInfo.size < 0) break
                    bufferInfo.presentationTimeUs = audioExtractor.sampleTime
                    bufferInfo.flags = audioExtractor.sampleFlags
                    muxer.writeSampleData(muxerAudioTrack, audioBuf, bufferInfo)
                    audioExtractor.advance()
                }
            }

            muxer.stop()
            return true
        } finally {
            try { videoExtractor?.release() } catch (_: Exception) {}
            try { audioExtractor?.release() } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
        }
    }
}
