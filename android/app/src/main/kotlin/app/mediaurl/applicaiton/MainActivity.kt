package app.mediaurl.applicaiton

import android.app.DownloadManager
import android.content.ContentValues
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
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
                "checkFileExists" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    result.success(checkFileExists(filePath))
                }
                "openWithSystemPlayer" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val mimeType = call.argument<String>("mimeType") ?: "video/*"
                    result.success(openWithSystemPlayer(filePath, mimeType))
                }
                "openInFileManager" -> {
                    val filePath = call.argument<String>("filePath")
                    result.success(openInFileManager(filePath))
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

        val cleanName = fileName.replace(Regex("[\\\\/*?:\"<>|#]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
        val finalFileName = if (cleanName.isNotBlank()) cleanName else "video_${System.currentTimeMillis()}.mp4"

        val publicDownloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!publicDownloadsDir.exists()) {
            try { publicDownloadsDir.mkdirs() } catch (_: Exception) {}
        }
        val directTargetFile = File(publicDownloadsDir, finalFileName)

        var resolvedPublicPath: String? = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ (API 29+): Use MediaStore exclusively.
            // This writes the file to /storage/emulated/0/Download/<finalFileName>
            // and indexes it in Android MediaStore in one atomic operation without creating duplicates.
            try {
                val resolver = applicationContext.contentResolver

                // Delete any existing broken/pending rows or old files with same name so MediaStore never creates " (1)"
                try {
                    val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ? AND ${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
                    val selectionArgs = arrayOf(finalFileName, "${Environment.DIRECTORY_DOWNLOADS}%")
                    resolver.delete(MediaStore.Downloads.EXTERNAL_CONTENT_URI, selection, selectionArgs)
                } catch (_: Exception) {}
                if (directTargetFile.exists()) {
                    try { directTargetFile.delete() } catch (_: Exception) {}
                }

                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, finalFileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }

                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)

                if (uri != null) {
                    var copySuccess = false
                    try {
                        resolver.openOutputStream(uri)?.use { outStream ->
                            sourceFile.inputStream().use { inStream ->
                                inStream.copyTo(outStream)
                            }
                        }
                        copySuccess = true
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed writing to MediaStore stream", e)
                    }

                    if (copySuccess) {
                        contentValues.clear()
                        contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                        resolver.update(uri, contentValues, null, null)

                        // Query resolved physical file path
                        try {
                            resolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)?.use { cursor ->
                                if (cursor.moveToFirst()) {
                                    val dataIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                                    if (dataIdx != -1) {
                                        val path = cursor.getString(dataIdx)
                                        if (!path.isNullOrBlank()) {
                                            val f = File(path)
                                            if (f.exists() && f.length() > 0L) {
                                                resolvedPublicPath = f.absolutePath
                                            }
                                        }
                                    }
                                }
                            }
                        } catch (_: Exception) {}
                    }
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "MediaStore Downloads insert failed", e)
            }
        } else {
            // Android 9 and below: Direct POSIX file copy
            try {
                sourceFile.copyTo(directTargetFile, overwrite = true)
                if (directTargetFile.exists() && directTargetFile.length() > 0L) {
                    resolvedPublicPath = directTargetFile.absolutePath
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Direct copy failed on legacy Android", e)
            }
        }

        // Fallback to direct target file if verified
        if (resolvedPublicPath.isNullOrBlank() && directTargetFile.exists() && directTargetFile.length() > 0L) {
            resolvedPublicPath = directTargetFile.absolutePath
        }

        val finalPathToScan = resolvedPublicPath ?: sourceFile.absolutePath

        // 3. Trigger MediaScanner so system file managers immediately show the single file
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(finalPathToScan),
            arrayOf(mimeType),
            null
        )

        // Return resolved public path if available; otherwise return sourcePath so file is never lost!
        return resolvedPublicPath ?: sourcePath
    }

    private fun checkFileExists(filePath: String): Boolean {
        try {
            val file = File(filePath)
            if (file.exists() && file.length() > 0L) return true

            val fileName = file.name
            val publicDownloads = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), fileName)
            if (publicDownloads.exists() && publicDownloads.length() > 0L) return true

            val publicDlSub = File(File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "VideoDownloader"), fileName)
            if (publicDlSub.exists() && publicDlSub.length() > 0L) return true

            val moviesFile = File(File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), "VideoDownloader"), fileName)
            if (moviesFile.exists() && moviesFile.length() > 0L) return true

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val projection = arrayOf(MediaStore.MediaColumns._ID)
                val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
                val selectionArgs = arrayOf(fileName)
                contentResolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, projection, selection, selectionArgs, null)?.use {
                    if (it.count > 0) return true
                }
                contentResolver.query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, projection, selection, selectionArgs, null)?.use {
                    if (it.count > 0) return true
                }
            }
        } catch (_: Exception) {}
        return false
    }

    private fun openWithSystemPlayer(filePath: String, mimeType: String): Boolean {
        try {
            var targetFile = File(filePath)
            if (!targetFile.exists() || targetFile.length() == 0L) {
                val fileName = targetFile.name
                val publicDl = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), fileName)
                if (publicDl.exists() && publicDl.length() > 0L) {
                    targetFile = publicDl
                } else {
                    val publicDlSub = File(File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "VideoDownloader"), fileName)
                    if (publicDlSub.exists() && publicDlSub.length() > 0L) {
                        targetFile = publicDlSub
                    }
                }
            }

            if (!targetFile.exists() || targetFile.length() == 0L) {
                Log.w("MainActivity", "openWithSystemPlayer: File does not exist: $filePath")
                return false
            }

            val authority = "${applicationContext.packageName}.fileprovider"
            val uri: Uri = try {
                FileProvider.getUriForFile(applicationContext, authority, targetFile)
            } catch (e: Exception) {
                Log.w("MainActivity", "FileProvider.getUriForFile failed, trying MediaStore query", e)
                var mediaUri: Uri? = null
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val projection = arrayOf(MediaStore.MediaColumns._ID)
                    val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
                    val selectionArgs = arrayOf(targetFile.name)
                    contentResolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, projection, selection, selectionArgs, null)?.use {
                        if (it.moveToFirst()) {
                            val id = it.getLong(it.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                            mediaUri = Uri.withAppendedPath(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id.toString())
                        }
                    }
                }
                mediaUri ?: Uri.fromFile(targetFile)
            }

            val effectiveMime = if (mimeType.isNotBlank() && mimeType != "*/*") mimeType else "video/*"
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, effectiveMime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val chooser = Intent.createChooser(intent, "Play Video").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(chooser)
            return true
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to open video with system player", e)
            return false
        }
    }

    private fun openInFileManager(filePath: String?): Boolean {
        // 1. Try launching Downloads via DownloadManager
        try {
            val intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return true
        } catch (_: Exception) {}

        // 2. Try launching Downloads folder via MediaStore Content URI
        try {
            val uri = Uri.parse("content://media/external/downloads")
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "resource/folder")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return true
        } catch (_: Exception) {}

        // 3. Try viewing file location with FileProvider
        if (!filePath.isNullOrBlank()) {
            try {
                val f = File(filePath)
                if (f.exists()) {
                    val authority = "${applicationContext.packageName}.fileprovider"
                    val contentUri = FileProvider.getUriForFile(applicationContext, authority, f)
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(contentUri, "*/*")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(Intent.createChooser(intent, "Open in Files").apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    })
                    return true
                }
            } catch (_: Exception) {}
        }

        return false
    }
}
