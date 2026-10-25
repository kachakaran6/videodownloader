package app.mediaurl.applicaiton.playcore

import android.app.Activity
import android.util.Log
import android.view.View
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.MainThread
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.google.android.material.snackbar.Snackbar
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallState
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.ActivityResult
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import kotlinx.coroutines.tasks.await
import java.lang.ref.WeakReference

/**
 * Production-grade helper for Google Play native In-App Updates (Flexible Flow).
 *
 * Implements 100% native Google Play UI — uses Play Store's built-in background
 * download and the standard recommended bottom-sheet / snackbar completion flow.
 *
 * Designed to be lifecycle-aware, leak-proof via [WeakReference], and safe across configuration changes.
 *
 * Usage:
 * ```kotlin
 * class MyActivity : AppCompatActivity() {
 *     private lateinit var updateHelper: AppUpdateHelper
 *
 *     override fun onCreate(savedInstanceState: Bundle?) {
 *         super.onCreate(savedInstanceState)
 *         updateHelper = AppUpdateHelper(this)
 *         updateHelper.checkForUpdate()
 *     }
 * }
 * ```
 *
 * @param activity Target [Activity] host for in-app update flows.
 * @param launcher Optional pre-registered [ActivityResultLauncher]. If omitted and [activity]
 *                 is a [ComponentActivity] in `INITIALIZED` or `CREATED` state, it is auto-registered.
 */
class AppUpdateHelper(
    activity: Activity,
    launcher: ActivityResultLauncher<IntentSenderRequest>? = null
) : DefaultLifecycleObserver {

    companion object {
        private const val TAG = "AppUpdateHelper"
        private const val REGISTRY_KEY = "play_app_update_launcher"
    }

    private val activityRef: WeakReference<Activity> = WeakReference(activity)
    private val appUpdateManager: AppUpdateManager = AppUpdateManagerFactory.create(activity)

    private var updateLauncher: ActivityResultLauncher<IntentSenderRequest>? = launcher
    private var isListenerRegistered: Boolean = false

    /**
     * Optional listener to receive updates when download status changes.
     */
    var onInstallStateChanged: ((InstallState) -> Unit)? = null

    /**
     * Optional custom handler when an update is downloaded.
     * If not provided, defaults to displaying Google Play's standard Material Snackbar.
     */
    var onUpdateDownloadedListener: (() -> Unit)? = null

    private val installStateUpdatedListener = InstallStateUpdatedListener { state ->
        onInstallStateChanged?.invoke(state)

        when (state.installStatus()) {
            InstallStatus.DOWNLOADED -> {
                Log.i(TAG, "In-app update download completed. Prompting user to restart.")
                if (onUpdateDownloadedListener != null) {
                    onUpdateDownloadedListener?.invoke()
                } else {
                    popupSnackbarForCompleteUpdate()
                }
            }
            InstallStatus.DOWNLOADING -> {
                val bytesDownloaded = state.bytesDownloaded()
                val totalBytes = state.totalBytesToDownload()
                Log.d(TAG, "Update downloading: $bytesDownloaded of $totalBytes bytes")
            }
            InstallStatus.FAILED -> {
                Log.e(TAG, "In-app update download failed with error code: ${state.installErrorCode()}")
                // Per guidelines: fail silently, do not crash or block user workflow
            }
            InstallStatus.CANCELED -> {
                Log.i(TAG, "In-app update download was canceled.")
            }
            InstallStatus.PENDING -> {
                Log.d(TAG, "In-app update download is pending.")
            }
            else -> {
                Log.d(TAG, "InstallStateUpdatedListener status: ${state.installStatus()}")
            }
        }
    }

    init {
        val compActivity = activity as? ComponentActivity
        if (updateLauncher == null && compActivity != null) {
            if (compActivity.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
                Log.w(
                    TAG,
                    "Activity is already STARTED. Cannot auto-register ActivityResultLauncher with registry. " +
                            "Instantiate AppUpdateHelper in onCreate() or pass a pre-registered launcher."
                )
            } else {
                try {
                    updateLauncher = compActivity.activityResultRegistry.register(
                        REGISTRY_KEY,
                        compActivity,
                        ActivityResultContracts.StartIntentSenderForResult()
                    ) { result ->
                        handleActivityResult(result.resultCode)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to auto-register ActivityResultLauncher", e)
                }
            }
        }
        compActivity?.lifecycle?.addObserver(this)
    }

    /**
     * Manually attach an [ActivityResultLauncher] if initialized after Activity STARTED state.
     */
    fun setLauncher(launcher: ActivityResultLauncher<IntentSenderRequest>) {
        this.updateLauncher = launcher
    }

    /**
     * Checks for available flexible updates asynchronously via Google Play Tasks.
     *
     * Call in `onCreate()` or `onStart()`.
     *
     * @param onCheckFinished Optional callback with update availability state.
     */
    @MainThread
    fun checkForUpdate(forceImmediate: Boolean = false, onCheckFinished: ((isAvailable: Boolean) -> Unit)? = null) {
        val updateInfoTask = appUpdateManager.appUpdateInfo

        updateInfoTask.addOnSuccessListener { appUpdateInfo ->
            val availability = appUpdateInfo.updateAvailability()
            val priority = appUpdateInfo.updatePriority()
            val isImmediateAllowed = appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
            val isFlexibleAllowed = appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)

            Log.d(TAG, "Check update success: availability=$availability, priority=$priority, flexibleAllowed=$isFlexibleAllowed, immediateAllowed=$isImmediateAllowed")

            when {
                availability == UpdateAvailability.UPDATE_AVAILABLE -> {
                    if ((priority >= 4 || forceImmediate) && isImmediateAllowed) {
                        Log.i(TAG, "Immediate update available (priority: $priority, version code: ${appUpdateInfo.availableVersionCode()}). Starting flow.")
                        startImmediateUpdate(appUpdateInfo)
                        onCheckFinished?.invoke(true)
                    } else if (isFlexibleAllowed) {
                        Log.i(TAG, "Flexible update available (priority: $priority, version code: ${appUpdateInfo.availableVersionCode()}). Starting flow.")
                        startFlexibleUpdate(appUpdateInfo)
                        onCheckFinished?.invoke(true)
                    } else if (isImmediateAllowed) {
                        Log.i(TAG, "Starting immediate update as fallback.")
                        startImmediateUpdate(appUpdateInfo)
                        onCheckFinished?.invoke(true)
                    } else {
                        Log.d(TAG, "Update available but neither immediate nor flexible allowed.")
                        onCheckFinished?.invoke(false)
                    }
                }
                availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS -> {
                    Log.i(TAG, "Developer-triggered update already in progress. Resuming flow.")
                    if (isImmediateAllowed) {
                        startImmediateUpdate(appUpdateInfo)
                    } else {
                        startFlexibleUpdate(appUpdateInfo)
                    }
                    onCheckFinished?.invoke(true)
                }
                appUpdateInfo.installStatus() == InstallStatus.DOWNLOADED -> {
                    Log.i(TAG, "Update is already downloaded. Showing restart prompt.")
                    if (onUpdateDownloadedListener != null) {
                        onUpdateDownloadedListener?.invoke()
                    } else {
                        popupSnackbarForCompleteUpdate()
                    }
                    onCheckFinished?.invoke(false)
                }
                else -> {
                    Log.d(TAG, "No update available.")
                    onCheckFinished?.invoke(false)
                }
            }
        }.addOnFailureListener { exception ->
            Log.w(TAG, "Failed to check for app update: ${exception.message}", exception)
            onCheckFinished?.invoke(false)
        }
    }

    /**
     * Coroutine-based update check using kotlinx-coroutines-play-services [await].
     *
     * Call within a lifecycle-scoped coroutine (e.g. `lifecycleScope.launch`).
     *
     * @return `true` if an update flow was initiated or resumed, `false` otherwise.
     */
    suspend fun checkForUpdateSuspend(forceImmediate: Boolean = false): Boolean {
        return try {
            val appUpdateInfo = appUpdateManager.appUpdateInfo.await()
            val availability = appUpdateInfo.updateAvailability()
            val priority = appUpdateInfo.updatePriority()
            val isImmediateAllowed = appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
            val isFlexibleAllowed = appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)

            when {
                availability == UpdateAvailability.UPDATE_AVAILABLE -> {
                    if ((priority >= 4 || forceImmediate) && isImmediateAllowed) {
                        startImmediateUpdate(appUpdateInfo)
                        true
                    } else if (isFlexibleAllowed) {
                        startFlexibleUpdate(appUpdateInfo)
                        true
                    } else if (isImmediateAllowed) {
                        startImmediateUpdate(appUpdateInfo)
                        true
                    } else false
                }
                availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS -> {
                    if (isImmediateAllowed) {
                        startImmediateUpdate(appUpdateInfo)
                    } else {
                        startFlexibleUpdate(appUpdateInfo)
                    }
                    true
                }
                appUpdateInfo.installStatus() == InstallStatus.DOWNLOADED -> {
                    if (onUpdateDownloadedListener != null) {
                        onUpdateDownloadedListener?.invoke()
                    } else {
                        popupSnackbarForCompleteUpdate()
                    }
                    false
                }
                else -> false
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error during suspend update check: ${e.message}", e)
            false
        }
    }

    /**
     * Launches the native Google Play immediate update flow.
     */
    fun startImmediateUpdate(appUpdateInfo: AppUpdateInfo) {
        val currentActivity = activityRef.get() ?: run {
            Log.w(TAG, "Cannot start immediate update: Activity is null")
            return
        }

        if (currentActivity.isFinishing || currentActivity.isDestroyed) {
            Log.w(TAG, "Cannot start immediate update: Activity is finishing or destroyed")
            return
        }

        val launcher = updateLauncher ?: run {
            Log.e(TAG, "Cannot start immediate update: ActivityResultLauncher is not configured.")
            return
        }

        try {
            val updateOptions = AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build()
            val started = appUpdateManager.startUpdateFlowForResult(
                appUpdateInfo,
                launcher,
                updateOptions
            )
            Log.i(TAG, "Google Play native immediate update flow started: $started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Google Play immediate update flow", e)
        }
    }

    /**
     * Launches the native Google Play flexible update bottom sheet.
     */
    fun startFlexibleUpdate(appUpdateInfo: AppUpdateInfo) {
        val currentActivity = activityRef.get() ?: run {
            Log.w(TAG, "Cannot start update: Activity is null")
            return
        }

        if (currentActivity.isFinishing || currentActivity.isDestroyed) {
            Log.w(TAG, "Cannot start update: Activity is finishing or destroyed")
            return
        }

        val launcher = updateLauncher ?: run {
            Log.e(
                TAG,
                "Cannot start update flow: ActivityResultLauncher is not configured. " +
                        "Make sure AppUpdateHelper is initialized in onCreate() or supply launcher via constructor."
            )
            return
        }

        try {
            val updateOptions = AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build()
            val started = appUpdateManager.startUpdateFlowForResult(
                appUpdateInfo,
                launcher,
                updateOptions
            )
            Log.i(TAG, "Google Play native update flow started: $started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Google Play update flow", e)
        }
    }

    /**
     * Handles ActivityResult callback from the update flow launcher.
     *
     * @param resultCode Standard Android result code from [ActivityResultLauncher].
     */
    fun handleActivityResult(resultCode: Int) {
        when (resultCode) {
            Activity.RESULT_OK -> {
                Log.i(TAG, "In-app update accepted by user; download initiating in background.")
            }
            Activity.RESULT_CANCELED -> {
                Log.w(TAG, "In-app update canceled or declined by user.")
            }
            ActivityResult.RESULT_IN_APP_UPDATE_FAILED -> {
                Log.e(TAG, "In-app update flow failed (RESULT_IN_APP_UPDATE_FAILED).")
            }
            else -> {
                Log.d(TAG, "In-app update flow returned result code: $resultCode")
            }
        }
    }

    /**
     * Displays Google Play's standard native completion prompt:
     * A persistent Snackbar with action button "RESTART" that invokes [completeUpdate].
     *
     * @param anchorView Optional specific View to anchor the Snackbar. Defaults to `android.R.id.content`.
     */
    fun popupSnackbarForCompleteUpdate(anchorView: View? = null) {
        val currentActivity = activityRef.get() ?: return
        if (currentActivity.isFinishing || currentActivity.isDestroyed) return

        val targetView = anchorView ?: currentActivity.findViewById(android.R.id.content) ?: return
        Snackbar.make(
            targetView,
            "An update has been downloaded.",
            Snackbar.LENGTH_INDEFINITE
        ).apply {
            setAction("RESTART") {
                completeUpdate()
            }
            show()
        }
    }

    /**
     * Completes an update that is in [InstallStatus.DOWNLOADED] state.
     * Restarts the app to finalize installation.
     */
    fun completeUpdate() {
        Log.i(TAG, "Triggering completeUpdate() to restart and install update.")
        appUpdateManager.completeUpdate()
    }

    /**
     * Registers the [InstallStateUpdatedListener] to monitor download progress and completion.
     */
    fun registerListener() {
        if (!isListenerRegistered) {
            appUpdateManager.registerListener(installStateUpdatedListener)
            isListenerRegistered = true
            Log.d(TAG, "InstallStateUpdatedListener registered.")
        }
    }

    /**
     * Unregisters the [InstallStateUpdatedListener] to avoid memory leaks.
     */
    fun unregisterListener() {
        if (isListenerRegistered) {
            appUpdateManager.unregisterListener(installStateUpdatedListener)
            isListenerRegistered = false
            Log.d(TAG, "InstallStateUpdatedListener unregistered.")
        }
    }

    // =========================================================================
    // Lifecycle Management (DefaultLifecycleObserver & Manual Invocations)
    // =========================================================================

    /**
     * Call from `Activity.onStart()` or `onResume()` if not using [DefaultLifecycleObserver].
     */
    fun onStart() {
        registerListener()
    }

    /**
     * Re-checks for completed downloads or stalled in-progress updates when returning to foreground.
     * Call from `Activity.onResume()` if not using [DefaultLifecycleObserver].
     */
    fun onResume() {
        registerListener()

        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                if (info.installStatus() == InstallStatus.DOWNLOADED) {
                    Log.i(TAG, "onResume: Update downloaded while app was in background. Showing prompt.")
                    if (onUpdateDownloadedListener != null) {
                        onUpdateDownloadedListener?.invoke()
                    } else {
                        popupSnackbarForCompleteUpdate()
                    }
                } else if (info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
                    Log.i(TAG, "onResume: Resuming developer-triggered update in progress.")
                    if (info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) {
                        startImmediateUpdate(info)
                    } else {
                        startFlexibleUpdate(info)
                    }
                }
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "onResume: Failed to re-check update info: ${e.message}", e)
            }
    }

    /**
     * Call from `Activity.onPause()` or `onStop()` if not using [DefaultLifecycleObserver].
     */
    fun onPause() {
        unregisterListener()
    }

    /**
     * Call from `Activity.onDestroy()` if not using [DefaultLifecycleObserver].
     */
    fun onDestroy() {
        unregisterListener()
        activityRef.clear()
    }

    // LifecycleOwner hooks
    override fun onStart(owner: LifecycleOwner) = onStart()
    override fun onResume(owner: LifecycleOwner) = onResume()
    override fun onPause(owner: LifecycleOwner) = onPause()
    override fun onDestroy(owner: LifecycleOwner) = onDestroy()
}
