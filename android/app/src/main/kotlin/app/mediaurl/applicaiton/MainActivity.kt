package app.mediaurl.applicaiton

import android.content.ContentValues
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
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
    private val DOWNLOAD_CHANNEL = "app.mediaurl.applicaiton/downloads"

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

        // Downloads Channel for exporting media to public Downloads folder & MediaStore
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportToPublicDownloads" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "video/mp4"

                    if (sourcePath == null || fileName == null) {
                        result.error("INVALID_ARGS", "Missing sourcePath or fileName", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val publicPath = exportToPublicDownloads(sourcePath, fileName, mimeType)
                            runOnUiThread {
                                result.success(publicPath)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("EXPORT_FAILED", e.localizedMessage ?: "Failed to export media", null)
                            }
                        }
                    }.start()
                }
                "scanFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    if (filePath != null) {
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(filePath),
                            arrayOf(mimeType),
                            null
                        )
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
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

    private fun exportToPublicDownloads(sourcePath: String, fileName: String, mimeType: String): String {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists() || sourceFile.length() == 0L) {
            return sourcePath
        }

        val isVideo = mimeType.startsWith("video/") || fileName.endsWith(".mp4", true) || fileName.endsWith(".mkv", true) || fileName.endsWith(".webm", true)
        val isAudio = mimeType.startsWith("audio/") || fileName.endsWith(".mp3", true) || fileName.endsWith(".m4a", true)

        // 1. Direct copy to standard Internal Storage Download folder
        val publicDownloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!publicDownloadsDir.exists()) {
            try { publicDownloadsDir.mkdirs() } catch (_: Exception) {}
        }
        val directTargetFile = File(publicDownloadsDir, fileName)
        try {
            sourceFile.copyTo(directTargetFile, overwrite = true)
        } catch (_: Exception) {}

        // 2. Direct copy to Movies/VideoDownloader for videos so it is organized and visible in Internal Storage
        var moviesFile: File? = null
        if (isVideo) {
            try {
                val moviesDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), "VideoDownloader")
                if (!moviesDir.exists()) {
                    moviesDir.mkdirs()
                }
                val mFile = File(moviesDir, fileName)
                sourceFile.copyTo(mFile, overwrite = true)
                moviesFile = mFile
            } catch (_: Exception) {}
        }

        // 3. Android 10+ (API 29+) MediaStore insertion so Scoped Storage indexes it into system File Explorer & Gallery
        var mediaStorePath: String? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }

                val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                val uri = contentResolver.insert(collection, contentValues)

                if (uri != null) {
                    contentResolver.openOutputStream(uri)?.use { outStream ->
                        sourceFile.inputStream().use { inStream ->
                            inStream.copyTo(outStream)
                        }
                    }
                    contentValues.clear()
                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    contentResolver.update(uri, contentValues, null, null)

                    try {
                        val projection = arrayOf(MediaStore.MediaColumns.DATA)
                        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                val dataIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                                if (dataIdx != -1) {
                                    val resolved = cursor.getString(dataIdx)
                                    if (!resolved.isNullOrBlank()) {
                                        mediaStorePath = resolved
                                    }
                                }
                            }
                        }
                    } catch (_: Exception) {}
                }
            } catch (_: Exception) {}

            // If it is a video, ALSO register into MediaStore.Video.Media so phone's Gallery / Photos app lists it
            if (isVideo) {
                try {
                    val videoValues = ContentValues().apply {
                        put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                        put(MediaStore.Video.Media.MIME_TYPE, mimeType)
                        put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/VideoDownloader/")
                        put(MediaStore.Video.Media.IS_PENDING, 1)
                    }
                    val videoUri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, videoValues)
                    if (videoUri != null) {
                        contentResolver.openOutputStream(videoUri)?.use { outStream ->
                            sourceFile.inputStream().use { inStream ->
                                inStream.copyTo(outStream)
                            }
                        }
                        videoValues.clear()
                        videoValues.put(MediaStore.Video.Media.IS_PENDING, 0)
                        contentResolver.update(videoUri, videoValues, null, null)
                    }
                } catch (_: Exception) {}
            }
        }

        // 4. Trigger MediaScanner on all destinations so Android OS immediately scans and indexes the files
        val pathsToScan = mutableListOf<String>()
        if (directTargetFile.exists()) pathsToScan.add(directTargetFile.absolutePath)
        if (moviesFile != null && moviesFile.exists()) pathsToScan.add(moviesFile.absolutePath)
        if (!mediaStorePath.isNullOrBlank() && File(mediaStorePath!!).exists()) pathsToScan.add(mediaStorePath!!)
        pathsToScan.add(sourceFile.absolutePath)

        MediaScannerConnection.scanFile(
            applicationContext,
            pathsToScan.toTypedArray(),
            Array(pathsToScan.size) { mimeType },
            null
        )

        // Return the best public path for playback
        if (!mediaStorePath.isNullOrBlank() && File(mediaStorePath!!).exists()) {
            return mediaStorePath!!
        }
        if (directTargetFile.exists()) {
            return directTargetFile.absolutePath
        }
        if (moviesFile != null && moviesFile.exists()) {
            return moviesFile.absolutePath
        }
        return sourcePath
    }
}
