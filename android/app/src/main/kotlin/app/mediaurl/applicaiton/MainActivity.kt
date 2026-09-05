package app.mediaurl.applicaiton

import android.Manifest
import android.app.DownloadManager
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
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
    private val WHATSAPP_CHANNEL = "app.mediaurl.applicaiton/whatsapp"

    private val PERMISSION_REQUEST_CODE = 8821
    private var permissionCallback: ((Boolean) -> Unit)? = null

    private val SAF_REQUEST_CODE_WA = 9912
    private val SAF_REQUEST_CODE_WB = 9913
    private var safResultCallback: ((Boolean) -> Unit)? = null

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

    override fun onStart() {
        super.onStart()
        if (::appUpdateHelper.isInitialized) {
            appUpdateHelper.onStart()
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

    override fun onStop() {
        super.onStop()
        if (::appUpdateHelper.isInitialized) {
            appUpdateHelper.unregisterListener()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::appUpdateHelper.isInitialized) {
            appUpdateHelper.onDestroy()
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

        // WhatsApp Status Saver Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WHATSAPP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermissions" -> {
                    result.success(hasStoragePermissions())
                }
                "requestPermissions" -> {
                    requestStoragePermissions { granted ->
                        runOnUiThread {
                            result.success(granted)
                        }
                    }
                }
                "scanStatuses" -> {
                    val appType = call.argument<String>("appType") ?: "all"
                    Thread {
                        val statuses = scanWhatsAppStatuses(appType)
                        runOnUiThread {
                            result.success(statuses)
                        }
                    }.start()
                }
                "saveStatusMedia" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val fileName = call.argument<String>("fileName")
                    val isVideo = call.argument<Boolean>("isVideo") ?: false
                    if (sourcePath == null || fileName == null) {
                        result.error("INVALID_ARGS", "Missing sourcePath or fileName", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        val savedPath = saveStatusMedia(sourcePath, fileName, isVideo)
                        runOnUiThread {
                            if (savedPath != null) {
                                result.success(savedPath)
                            } else {
                                result.error("SAVE_FAILED", "Failed to save status media", null)
                            }
                        }
                    }.start()
                }
                "isStatusSaved" -> {
                    val fileName = call.argument<String>("fileName") ?: ""
                    val isVideo = call.argument<Boolean>("isVideo") ?: false
                    result.success(isStatusSaved(fileName, isVideo))
                }
                "isWhatsAppInstalled" -> {
                    val appType = call.argument<String>("appType") ?: "whatsapp"
                    result.success(isWhatsAppInstalled(appType))
                }
                "openWhatsAppApp" -> {
                    val appType = call.argument<String>("appType") ?: "whatsapp"
                    result.success(openWhatsAppApp(appType))
                }
                "hasFolderPermission" -> {
                    val appType = call.argument<String>("appType") ?: "whatsapp"
                    result.success(hasFolderPermission(appType))
                }
                "requestFolderPermission" -> {
                    val appType = call.argument<String>("appType") ?: "whatsapp"
                    requestFolderPermission(appType) { granted ->
                        runOnUiThread {
                            result.success(granted)
                        }
                    }
                }
                "openPlayStore" -> {
                    val packageName = call.argument<String>("packageName") ?: "com.whatsapp"
                    result.success(openPlayStore(packageName))
                }
                "getVideoThumbnail" -> {
                    val videoPath = call.argument<String>("videoPath") ?: ""
                    Thread {
                        val thumb = getVideoThumbnail(videoPath)
                        runOnUiThread {
                            result.success(thumb)
                        }
                    }.start()
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

    private fun hasStoragePermissions(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && Environment.isExternalStorageManager()) {
            return true
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_VIDEO) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestStoragePermissions(callback: (Boolean) -> Unit) {
        if (hasStoragePermissions()) {
            callback(true)
            return
        }
        permissionCallback = callback
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO)
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        ActivityCompat.requestPermissions(this, permissions, PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            permissionCallback?.invoke(allGranted || hasStoragePermissions())
            permissionCallback = null
        }
    }

    private fun scanWhatsAppStatuses(appType: String): List<Map<String, Any>> {
        val results = mutableListOf<Map<String, Any>>()
        val visitedPaths = mutableSetOf<String>()

        val scanWA = (appType == "all" || appType == "whatsapp")
        val scanWB = (appType == "all" || appType == "whatsappBusiness")

        // 1. Direct File Scan across all known file system locations
        val directories = mutableListOf<Pair<File, String>>()

        if (scanWA) {
            directories.add(Pair(File("/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File("/storage/emulated/0/WhatsApp/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File(Environment.getExternalStorageDirectory(), "Android/media/com.whatsapp/WhatsApp/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File(Environment.getExternalStorageDirectory(), "WhatsApp/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File("/storage/emulated/0/Android/media/com.gbwhatsapp/GBWhatsApp/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File("/storage/emulated/0/GBWhatsApp/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File("/storage/emulated/0/Android/media/com.fmwhatsapp/FMWhatsApp/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File("/storage/emulated/0/Android/media/com.yowhatsapp/YoWhatsApp/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File("/storage/emulated/0/Android/media/com.whatsappplus/WhatsAppPlus/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File("/storage/emulated/999/Android/media/com.whatsapp/WhatsApp/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File("/storage/emulated/999/WhatsApp/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File("/storage/emulated/10/Android/media/com.whatsapp/WhatsApp/Media/.Statuses"), "whatsapp"))
            directories.add(Pair(File("/storage/emulated/10/WhatsApp/Media/.Statuses"), "whatsapp"))
        }

        if (scanWB) {
            directories.add(Pair(File("/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses"), "whatsappBusiness"))
            directories.add(Pair(File("/storage/emulated/0/WhatsApp Business/Media/.Statuses"), "whatsappBusiness"))
            directories.add(Pair(File(Environment.getExternalStorageDirectory(), "Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses"), "whatsappBusiness"))
            directories.add(Pair(File(Environment.getExternalStorageDirectory(), "WhatsApp Business/Media/.Statuses"), "whatsappBusiness"))
            directories.add(Pair(File("/storage/emulated/999/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses"), "whatsappBusiness"))
            directories.add(Pair(File("/storage/emulated/999/WhatsApp Business/Media/.Statuses"), "whatsappBusiness"))
            directories.add(Pair(File("/storage/emulated/10/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses"), "whatsappBusiness"))
            directories.add(Pair(File("/storage/emulated/10/WhatsApp Business/Media/.Statuses"), "whatsappBusiness"))
        }

        for ((dir, sourceApp) in directories) {
            try {
                if (dir.exists() && dir.isDirectory && dir.canRead()) {
                    val files = dir.listFiles()
                    if (files != null) {
                        for (file in files) {
                            if (file.isFile && file.length() > 0L) {
                                val name = file.name
                                if (name.startsWith(".nomedia", ignoreCase = true) || name.startsWith(".")) continue
                                val ext = file.extension.lowercase()
                                if (ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "mp4") {
                                    if (visitedPaths.add(name)) {
                                        val isVid = (ext == "mp4")
                                        val thumbPath = if (isVid) getVideoThumbnail(file.absolutePath) else null
                                        results.add(mapOf(
                                            "path" to file.absolutePath,
                                            "fileName" to name,
                                            "isVideo" to isVid,
                                            "thumbnailPath" to (thumbPath ?: ""),
                                            "fileSize" to file.length(),
                                            "modifiedTime" to file.lastModified(),
                                            "appType" to sourceApp
                                        ))
                                    }
                                }
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w("MainActivity", "Error scanning directory: ${dir.absolutePath}", e)
            }
        }

        // 2. Scan via persisted SAF Tree URIs (crucial for Android 11+ Scoped Storage)
        if (scanWA) {
            val waTreeUri = getPersistedTreeUri("whatsapp")
            if (waTreeUri != null) {
                scanSafTree(waTreeUri, "whatsapp", visitedPaths, results)
            }
        }
        if (scanWB) {
            val wbTreeUri = getPersistedTreeUri("whatsappBusiness")
            if (wbTreeUri != null) {
                scanSafTree(wbTreeUri, "whatsappBusiness", visitedPaths, results)
            }
        }

        results.sortByDescending { (it["modifiedTime"] as? Long) ?: 0L }
        return results
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (::appUpdateHelper.isInitialized) {
            appUpdateHelper.handleActivityResult(resultCode)
        }
        if (requestCode == SAF_REQUEST_CODE_WA || requestCode == SAF_REQUEST_CODE_WB) {
            val isBusiness = (requestCode == SAF_REQUEST_CODE_WB)
            val treeUri = data?.data
            if (resultCode == RESULT_OK && treeUri != null) {
                try {
                    val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    contentResolver.takePersistableUriPermission(treeUri, takeFlags)

                    val prefKey = if (isBusiness) "saf_tree_wb" else "saf_tree_wa"
                    getSharedPreferences("whatsapp_status_prefs", MODE_PRIVATE)
                        .edit()
                        .putString(prefKey, treeUri.toString())
                        .apply()

                    safResultCallback?.invoke(true)
                } catch (e: Exception) {
                    Log.e("MainActivity", "Failed to persist tree URI", e)
                    val prefKey = if (isBusiness) "saf_tree_wb" else "saf_tree_wa"
                    getSharedPreferences("whatsapp_status_prefs", MODE_PRIVATE)
                        .edit()
                        .putString(prefKey, treeUri.toString())
                        .apply()
                    safResultCallback?.invoke(true)
                }
            } else {
                safResultCallback?.invoke(false)
            }
            safResultCallback = null
        }
    }

    private fun getPersistedTreeUri(appType: String): Uri? {
        val prefKey = if (appType == "whatsappBusiness") "saf_tree_wb" else "saf_tree_wa"
        val uriStr = getSharedPreferences("whatsapp_status_prefs", MODE_PRIVATE).getString(prefKey, null) ?: return null
        return try { Uri.parse(uriStr) } catch (_: Exception) { null }
    }

    private fun hasFolderPermission(appType: String): Boolean {
        // 1. If All Files Access is granted on Android 11+, we have full access
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && Environment.isExternalStorageManager()) {
            return true
        }

        // 2. Check persisted SAF tree URI
        val treeUri = getPersistedTreeUri(appType)
        if (treeUri != null) {
            val hasPersisted = contentResolver.persistedUriPermissions.any {
                it.uri == treeUri && it.isReadPermission
            }
            if (hasPersisted) {
                try {
                    val doc = DocumentFile.fromTreeUri(applicationContext, treeUri)
                    if (doc != null && doc.canRead()) return true
                } catch (_: Exception) {}
            }
            try {
                val doc = DocumentFile.fromTreeUri(applicationContext, treeUri)
                if (doc != null && doc.canRead()) return true
            } catch (_: Exception) {}
        }

        // 3. Check direct file access (Android 10 & below, or Android 11/12 with storage permission)
        val isBusiness = (appType == "whatsappBusiness")
        val dirs = if (isBusiness) {
            listOf(
                File("/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses"),
                File("/storage/emulated/0/WhatsApp Business/Media/.Statuses"),
                File(Environment.getExternalStorageDirectory(), "Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses"),
                File(Environment.getExternalStorageDirectory(), "WhatsApp Business/Media/.Statuses")
            )
        } else {
            listOf(
                File("/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses"),
                File("/storage/emulated/0/WhatsApp/Media/.Statuses"),
                File("/storage/emulated/0/Android/media/com.gbwhatsapp/GBWhatsApp/Media/.Statuses"),
                File(Environment.getExternalStorageDirectory(), "Android/media/com.whatsapp/WhatsApp/Media/.Statuses"),
                File(Environment.getExternalStorageDirectory(), "WhatsApp/Media/.Statuses")
            )
        }

        for (dir in dirs) {
            if (dir.exists() && dir.canRead()) {
                return true
            }
        }

        return false
    }

    private fun requestFolderPermission(appType: String, callback: (Boolean) -> Unit) {
        safResultCallback = callback
        val isBusiness = (appType == "whatsappBusiness")
        val reqCode = if (isBusiness) SAF_REQUEST_CODE_WB else SAF_REQUEST_CODE_WA

        val targetPath = if (isBusiness) {
            "Android%2Fmedia%2Fcom.whatsapp.w4b%2FWhatsApp%20Business%2FMedia"
        } else {
            "Android%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia"
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val waFolder = if (isBusiness) {
                    File(Environment.getExternalStorageDirectory(), "Android/media/com.whatsapp.w4b")
                } else {
                    File(Environment.getExternalStorageDirectory(), "Android/media/com.whatsapp")
                }
                val path = if (waFolder.exists()) {
                    targetPath
                } else {
                    if (isBusiness) "WhatsApp%20Business%2FMedia" else "WhatsApp%2FMedia"
                }
                val uri = Uri.parse("content://com.android.externalstorage.documents/document/primary%3A$path")
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, uri)
            }
        }
        try {
            startActivityForResult(intent, reqCode)
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to launch OPEN_DOCUMENT_TREE", e)
            callback(false)
            safResultCallback = null
        }
    }

    private fun scanSafTree(treeUri: Uri, appType: String, visitedNames: MutableSet<String>, results: MutableList<Map<String, Any>>) {
        val isBusiness = (appType == "whatsappBusiness")
        val treeDocId = DocumentsContract.getTreeDocumentId(treeUri) ?: ""

        val candidateStatusDocIds = mutableListOf<String>()

        if (treeDocId.endsWith("/.Statuses")) {
            candidateStatusDocIds.add(treeDocId)
        } else {
            if (isBusiness) {
                candidateStatusDocIds.add("primary:Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses")
                candidateStatusDocIds.add("primary:WhatsApp Business/Media/.Statuses")
                if (treeDocId.isNotEmpty()) {
                    candidateStatusDocIds.add("$treeDocId/.Statuses")
                    candidateStatusDocIds.add("$treeDocId/Media/.Statuses")
                }
            } else {
                candidateStatusDocIds.add("primary:Android/media/com.whatsapp/WhatsApp/Media/.Statuses")
                candidateStatusDocIds.add("primary:WhatsApp/Media/.Statuses")
                candidateStatusDocIds.add("primary:Android/media/com.gbwhatsapp/GBWhatsApp/Media/.Statuses")
                candidateStatusDocIds.add("primary:GBWhatsApp/Media/.Statuses")
                if (treeDocId.isNotEmpty()) {
                    candidateStatusDocIds.add("$treeDocId/.Statuses")
                    candidateStatusDocIds.add("$treeDocId/Media/.Statuses")
                }
            }
        }

        val cacheFolder = File(cacheDir, "whatsapp_statuses")
        if (!cacheFolder.exists()) cacheFolder.mkdirs()

        var scannedAny = false

        for (statusDocId in candidateStatusDocIds.distinct()) {
            try {
                val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, statusDocId)
                val projection = arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED
                )

                contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                    val idIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                    val nameIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                    val mimeIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
                    val sizeIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
                    val modIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)

                    while (cursor.moveToNext()) {
                        val docId = if (idIdx != -1) cursor.getString(idIdx) else null ?: continue
                        val name = if (nameIdx != -1) cursor.getString(nameIdx) else null ?: continue
                        if (name.startsWith(".nomedia", ignoreCase = true) || name.startsWith(".")) continue

                        val ext = name.substringAfterLast('.', "").lowercase()
                        val mime = if (mimeIdx != -1) cursor.getString(mimeIdx) ?: "" else ""
                        val isVideo = (ext == "mp4" || mime.startsWith("video/"))
                        val isImage = (ext == "jpg" || ext == "jpeg" || ext == "png" || mime.startsWith("image/"))

                        if (isImage || isVideo) {
                            if (visitedNames.add(name)) {
                                scannedAny = true
                                val fileSize = if (sizeIdx != -1) cursor.getLong(sizeIdx) else 0L
                                val lastMod = if (modIdx != -1) cursor.getLong(modIdx) else System.currentTimeMillis()
                                val fileDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)

                                val cachedFile = File(cacheFolder, name)
                                if (!cachedFile.exists() || cachedFile.length() == 0L || (fileSize > 0L && cachedFile.length() != fileSize)) {
                                    try {
                                        contentResolver.openInputStream(fileDocUri)?.use { input ->
                                            cachedFile.outputStream().use { output ->
                                                input.copyTo(output)
                                            }
                                        }
                                    } catch (e: Exception) {
                                        Log.e("MainActivity", "Failed caching status file $name", e)
                                    }
                                }

                                val finalPath = if (cachedFile.exists() && cachedFile.length() > 0L) {
                                    cachedFile.absolutePath
                                } else {
                                    fileDocUri.toString()
                                }

                                val thumbPath = if (isVideo) getVideoThumbnail(finalPath) else null

                                results.add(mapOf(
                                    "path" to finalPath,
                                    "fileName" to name,
                                    "isVideo" to isVideo,
                                    "thumbnailPath" to (thumbPath ?: ""),
                                    "fileSize" to if (cachedFile.exists()) cachedFile.length() else fileSize,
                                    "modifiedTime" to lastMod,
                                    "appType" to appType
                                ))
                            }
                        }
                    }
                }
                if (scannedAny) {
                    break
                }
            } catch (e: Exception) {
                Log.d("MainActivity", "Querying candidate statusDocId $statusDocId: ${e.message}")
            }
        }

        // Fallback: If direct candidate query returned nothing, try DocumentFile tree inspection
        if (!scannedAny) {
            try {
                val rootDoc = DocumentFile.fromTreeUri(applicationContext, treeUri)
                if (rootDoc != null && rootDoc.isDirectory) {
                    scanDocFileRecursive(rootDoc, treeUri, appType, visitedNames, results, cacheFolder, 0)
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Fallback scan error: ${e.message}")
            }
        }
    }

    private fun scanDocFileRecursive(
        dir: DocumentFile,
        treeUri: Uri,
        appType: String,
        visitedNames: MutableSet<String>,
        results: MutableList<Map<String, Any>>,
        cacheFolder: File,
        depth: Int
    ) {
        if (depth > 3) return
        val children = dir.listFiles()
        for (child in children) {
            if (child.isDirectory) {
                val name = child.name ?: ""
                if (name == ".Statuses" || name == "Media" || name.contains("WhatsApp", ignoreCase = true)) {
                    scanDocFileRecursive(child, treeUri, appType, visitedNames, results, cacheFolder, depth + 1)
                }
            } else if (child.isFile) {
                val name = child.name ?: continue
                if (name.startsWith(".nomedia", ignoreCase = true) || name.startsWith(".")) continue
                val ext = name.substringAfterLast('.', "").lowercase()
                val isVideo = (ext == "mp4" || (child.type ?: "").startsWith("video/"))
                val isImage = (ext == "jpg" || ext == "jpeg" || ext == "png" || (child.type ?: "").startsWith("image/"))
                if (isImage || isVideo) {
                    if (visitedNames.add(name)) {
                        val cachedFile = File(cacheFolder, name)
                        if (!cachedFile.exists() || cachedFile.length() == 0L) {
                            try {
                                contentResolver.openInputStream(child.uri)?.use { input ->
                                    cachedFile.outputStream().use { output ->
                                        input.copyTo(output)
                                    }
                                }
                            } catch (_: Exception) {}
                        }
                        val finalPath = if (cachedFile.exists() && cachedFile.length() > 0L) cachedFile.absolutePath else child.uri.toString()
                        val thumbPath = if (isVideo) getVideoThumbnail(finalPath) else null
                        results.add(mapOf(
                            "path" to finalPath,
                            "fileName" to name,
                            "isVideo" to isVideo,
                            "thumbnailPath" to (thumbPath ?: ""),
                            "fileSize" to if (cachedFile.exists()) cachedFile.length() else child.length(),
                            "modifiedTime" to child.lastModified(),
                            "appType" to appType
                        ))
                    }
                }
            }
        }
    }

    private fun saveStatusMedia(sourcePath: String, fileName: String, isVideo: Boolean): String? {
        val isContentUri = sourcePath.startsWith("content://")
        val sourceFile = if (!isContentUri) File(sourcePath) else null

        if (sourceFile != null && (!sourceFile.exists() || sourceFile.length() == 0L)) return null

        val ext = if (sourceFile != null) {
            sourceFile.extension.lowercase().ifEmpty { if (isVideo) "mp4" else "jpg" }
        } else {
            if (isVideo) "mp4" else "jpg"
        }
        val finalFileName = if (fileName.contains(".")) fileName else "status_${System.currentTimeMillis()}.$ext"
        val mimeType = if (isVideo) "video/mp4" else (if (ext == "png") "image/png" else "image/jpeg")

        var savedPath: String? = null

        val openInputStream: () -> java.io.InputStream? = {
            if (isContentUri) {
                contentResolver.openInputStream(Uri.parse(sourcePath))
            } else {
                sourceFile?.inputStream()
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val subFolder = if (isVideo) "Movies/WhatsAppStatus" else "Pictures/WhatsAppStatus"
            val targetUri = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI

            try {
                try {
                    resolver.delete(targetUri, "${MediaStore.MediaColumns.DISPLAY_NAME} = ?", arrayOf(finalFileName))
                } catch (_: Exception) {}

                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, finalFileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, subFolder)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }

                val uri = resolver.insert(targetUri, contentValues)
                if (uri != null) {
                    var copySuccess = false
                    try {
                        resolver.openOutputStream(uri)?.use { out ->
                            openInputStream()?.use { input ->
                                input.copyTo(out)
                                copySuccess = true
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed copying status stream to MediaStore", e)
                    }

                    if (copySuccess) {
                        contentValues.clear()
                        contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                        resolver.update(uri, contentValues, null, null)

                        resolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                val idx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                                if (idx != -1) {
                                    savedPath = cursor.getString(idx)
                                }
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "MediaStore status save failed", e)
            }
        }

        if (savedPath.isNullOrBlank()) {
            val baseDir = if (isVideo) {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
            } else {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            }
            val statusDir = File(baseDir, "WhatsAppStatus")
            if (!statusDir.exists()) statusDir.mkdirs()
            val destFile = File(statusDir, finalFileName)
            try {
                openInputStream()?.use { input ->
                    destFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                if (destFile.exists() && destFile.length() > 0L) {
                    savedPath = destFile.absolutePath
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Direct status copy failed", e)
            }
        }

        val finalPath = savedPath ?: sourcePath
        if (!finalPath.startsWith("content://")) {
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(finalPath),
                arrayOf(mimeType),
                null
            )
        }

        return savedPath ?: (if (!isContentUri) sourcePath else null)
    }

    private fun isStatusSaved(fileName: String, isVideo: Boolean): Boolean {
        try {
            val picturesDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "WhatsAppStatus")
            if (File(picturesDir, fileName).exists()) return true

            val moviesDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), "WhatsAppStatus")
            if (File(moviesDir, fileName).exists()) return true

            val downloadDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "WhatsAppStatus")
            if (File(downloadDir, fileName).exists()) return true

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val targetUri = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                val projection = arrayOf(MediaStore.MediaColumns._ID)
                val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
                contentResolver.query(targetUri, projection, selection, arrayOf(fileName), null)?.use {
                    if (it.count > 0) return true
                }
            }
        } catch (_: Exception) {}
        return false
    }

    private fun isWhatsAppInstalled(appType: String): Boolean {
        val packages = if (appType == "whatsappBusiness") {
            listOf("com.whatsapp.w4b")
        } else {
            listOf("com.whatsapp", "com.gbwhatsapp", "com.fmwhatsapp", "com.yowhatsapp", "com.whatsapp4b")
        }

        for (pkg in packages) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
                } else {
                    @Suppress("DEPRECATION")
                    packageManager.getPackageInfo(pkg, 0)
                }
                return true
            } catch (_: Exception) {}
            try {
                if (packageManager.getLaunchIntentForPackage(pkg) != null) {
                    return true
                }
            } catch (_: Exception) {}
        }

        // Check if WhatsApp directories exist on external storage
        val checkDirs = if (appType == "whatsappBusiness") {
            listOf(
                File("/storage/emulated/0/Android/media/com.whatsapp.w4b"),
                File("/storage/emulated/0/WhatsApp Business"),
                File(Environment.getExternalStorageDirectory(), "Android/media/com.whatsapp.w4b"),
                File(Environment.getExternalStorageDirectory(), "WhatsApp Business")
            )
        } else {
            listOf(
                File("/storage/emulated/0/Android/media/com.whatsapp"),
                File("/storage/emulated/0/WhatsApp"),
                File("/storage/emulated/0/Android/media/com.gbwhatsapp"),
                File("/storage/emulated/0/GBWhatsApp"),
                File(Environment.getExternalStorageDirectory(), "Android/media/com.whatsapp"),
                File(Environment.getExternalStorageDirectory(), "WhatsApp")
            )
        }
        for (dir in checkDirs) {
            if (dir.exists()) return true
        }

        // Check if tree URI is persisted
        if (getPersistedTreeUri(appType) != null) return true

        return false
    }

    private fun openWhatsAppApp(appType: String): Boolean {
        val packages = if (appType == "whatsappBusiness") {
            listOf("com.whatsapp.w4b")
        } else {
            listOf("com.whatsapp", "com.gbwhatsapp", "com.fmwhatsapp", "com.yowhatsapp", "com.whatsapp4b", "com.whatsapp.w4b")
        }

        for (pkg in packages) {
            val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
                return true
            }
        }
        return false
    }

    private fun openPlayStore(packageName: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$packageName")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun getVideoThumbnail(videoPath: String): String? {
        try {
            val cacheDir = File(applicationContext.cacheDir, "whatsapp_thumbs")
            if (!cacheDir.exists()) cacheDir.mkdirs()

            val hash = videoPath.hashCode().toString()
            val thumbFile = File(cacheDir, "thumb_$hash.jpg")
            if (thumbFile.exists() && thumbFile.length() > 0L) {
                return thumbFile.absolutePath
            }

            val retriever = MediaMetadataRetriever()
            try {
                if (videoPath.startsWith("content://")) {
                    retriever.setDataSource(applicationContext, Uri.parse(videoPath))
                } else {
                    val file = File(videoPath)
                    if (!file.exists() || file.length() == 0L) return null
                    retriever.setDataSource(videoPath)
                }

                val bitmap = retriever.getFrameAtTime(1000000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    ?: retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    ?: retriever.frameAtTime

                if (bitmap != null) {
                    thumbFile.outputStream().use { out ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
                    }
                    bitmap.recycle()
                    if (thumbFile.exists() && thumbFile.length() > 0L) {
                        return thumbFile.absolutePath
                    }
                }
            } finally {
                try { retriever.release() } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed generating video thumbnail: $videoPath", e)
        }
        return null
    }
}
