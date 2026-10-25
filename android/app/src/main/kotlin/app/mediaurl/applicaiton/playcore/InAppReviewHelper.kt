package app.mediaurl.applicaiton.playcore

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.annotation.MainThread
import com.google.android.play.core.review.ReviewInfo
import com.google.android.play.core.review.ReviewManager
import com.google.android.play.core.review.ReviewManagerFactory
import kotlinx.coroutines.tasks.await
import java.lang.ref.WeakReference

/**
 * Production-grade helper for Google Play native In-App Review.
 *
 * Implements 100% native Play Store UI — launches Google Play's own review
 * bottom sheet directly without any intermediate custom rating dialogs, "enjoying the app?"
 * prompts, or pre-permission screens, in strict compliance with Google Play Store policies.
 *
 * Designed to be leak-proof via [WeakReference], defensive against destroyed Activities,
 * and equipped with internal cooldown gating (session, frequency, and action thresholds)
 * to avoid spamming the request API while respecting Google Play's server-side quotas.
 *
 * Usage:
 * ```kotlin
 * class MyActivity : AppCompatActivity() {
 *     private lateinit var reviewHelper: InAppReviewHelper
 *
 *     override fun onCreate(savedInstanceState: Bundle?) {
 *         super.onCreate(savedInstanceState)
 *         reviewHelper = InAppReviewHelper(this)
 *     }
 *
 *     private fun onVideoDownloadCompleted() {
 *         // 1. Record value action
 *         reviewHelper.recordSuccessfulAction()
 *
 *         // 2. Request review after genuine positive user moment
 *         reviewHelper.tryRequestReview()
 *     }
 * }
 * ```
 *
 * @param activity Target [Activity] host for the native review flow.
 * @param minDaysBetweenPrompts Minimum elapsed days before showing review prompt again (default: 14 days).
 * @param minActionsRequired Minimum completed positive actions before first prompt is eligible (default: 3).
 */
class InAppReviewHelper(
    activity: Activity,
    private val minDaysBetweenPrompts: Int = DEFAULT_MIN_DAYS_BETWEEN_PROMPTS,
    private val minActionsRequired: Int = DEFAULT_MIN_ACTIONS_REQUIRED,
    private val sharedPreferences: SharedPreferences = activity.applicationContext.getSharedPreferences(
        PREFS_NAME,
        Context.MODE_PRIVATE
    )
) {

    companion object {
        private const val TAG = "InAppReviewHelper"
        private const val PREFS_NAME = "google_play_in_app_review_prefs"
        private const val KEY_LAST_REVIEW_TIMESTAMP = "key_last_review_timestamp_ms"
        private const val KEY_SUCCESSFUL_ACTIONS_COUNT = "key_successful_actions_count"

        const val DEFAULT_MIN_DAYS_BETWEEN_PROMPTS = 15
        const val DEFAULT_MIN_ACTIONS_REQUIRED = 3
    }

    private val activityRef: WeakReference<Activity> = WeakReference(activity)
    private val reviewManager: ReviewManager = ReviewManagerFactory.create(activity)

    /**
     * In-memory session guard: prevents requesting review more than once per app process session.
     */
    private var hasRequestedThisSession: Boolean = false

    /**
     * Records a genuine positive user action (e.g. video downloaded, file saved, task completed).
     *
     * Call this from core workflow completion handlers to build up eligibility towards
     * the [minActionsRequired] threshold.
     */
    fun recordSuccessfulAction() {
        val current = sharedPreferences.getInt(KEY_SUCCESSFUL_ACTIONS_COUNT, 0)
        val updated = current + 1
        sharedPreferences.edit().putInt(KEY_SUCCESSFUL_ACTIONS_COUNT, updated).apply()
        Log.d(TAG, "Recorded successful user action. Total count: $updated (threshold: $minActionsRequired)")
    }

    /**
     * Evaluates whether the user is eligible for a review request based on local cooldown rules.
     *
     * Note: Google Play also enforces its own server-side quota regardless of client behavior.
     *
     * @return `true` if eligible to invoke [requestReviewFlow], `false` otherwise.
     */
    fun shouldPromptReview(): Boolean {
        if (hasRequestedThisSession) {
            Log.d(TAG, "Review already requested in this session. Suppressing prompt.")
            return false
        }

        val actionsCount = sharedPreferences.getInt(KEY_SUCCESSFUL_ACTIONS_COUNT, 0)
        if (actionsCount < minActionsRequired) {
            Log.d(TAG, "Action count ($actionsCount) is below required threshold ($minActionsRequired). Suppressing prompt.")
            return false
        }

        val lastPromptTimestamp = sharedPreferences.getLong(KEY_LAST_REVIEW_TIMESTAMP, 0L)
        if (lastPromptTimestamp > 0L) {
            val elapsedMs = System.currentTimeMillis() - lastPromptTimestamp
            val elapsedDays = elapsedMs / (1000L * 60 * 60 * 24)
            if (elapsedDays < minDaysBetweenPrompts) {
                Log.d(TAG, "Cooldown active ($elapsedDays days elapsed < $minDaysBetweenPrompts days required). Suppressing prompt.")
                return false
            }
        }

        return true
    }

    /**
     * Requests and launches the native Google Play In-App Review flow if eligibility checks pass.
     *
     * CRITICAL USAGE RULES (per Google Play Review Guidelines):
     * 1. DO NOT call this on app launch, splash screen, or cold start.
     * 2. DO NOT show any intermediate confirmation dialog, custom star rating, or "Like our app?" prompt.
     * 3. Call ONLY after a genuine positive/completion moment relevant to this app's core flow
     *    (e.g., successful download, finished export, completed transaction).
     *
     * ```kotlin
     * // TODO: call from appropriate success moment (e.g. after successful download or file export)
     * reviewHelper.tryRequestReview()
     * ```
     *
     * @param force If `true`, bypasses local cooldown and action threshold checks (Play server quota still applies).
     * @param onComplete Optional callback invoked when the flow finishes. The Google Play API intentionally
     *                   does NOT disclose whether the user rated or if the sheet was shown; treat completion
     *                   as final and continue normal app navigation.
     */
    @MainThread
    fun tryRequestReview(force: Boolean = false, onComplete: (() -> Unit)? = null) {
        val currentActivity = activityRef.get() ?: run {
            Log.w(TAG, "Cannot launch review flow: Host Activity reference is null.")
            onComplete?.invoke()
            return
        }

        if (currentActivity.isFinishing || currentActivity.isDestroyed) {
            Log.w(TAG, "Cannot launch review flow: Host Activity is finishing or destroyed.")
            onComplete?.invoke()
            return
        }

        if (!force && !shouldPromptReview()) {
            onComplete?.invoke()
            return
        }

        hasRequestedThisSession = true

        val requestTask = reviewManager.requestReviewFlow()
        requestTask.addOnSuccessListener { reviewInfo: ReviewInfo ->
            val hostActivity = activityRef.get()
            if (hostActivity == null || hostActivity.isFinishing || hostActivity.isDestroyed) {
                Log.w(TAG, "Host Activity was destroyed before review flow could be presented.")
                onComplete?.invoke()
                return@addOnSuccessListener
            }

            val launchTask = reviewManager.launchReviewFlow(hostActivity, reviewInfo)
            launchTask.addOnCompleteListener { _ ->
                // Google Play documentation:
                // "The flow has finished. The API does not indicate whether the user reviewed or not,
                // or even whether the review dialog was shown. Thus, no matter the result, we continue our app flow."
                markReviewPrompted()
                Log.i(TAG, "Google Play native In-App Review flow finished.")
                onComplete?.invoke()
            }
        }.addOnFailureListener { exception ->
            // Per Google Play guidelines: Fail silently, do NOT show fallback dialogs, toasts, or error UI.
            Log.w(TAG, "In-app review request failed silently: ${exception.message}")
            onComplete?.invoke()
        }
    }

    /**
     * Coroutine-based In-App Review request using kotlinx-coroutines-play-services [await].
     *
     * Call inside a lifecycle-scoped coroutine after a positive completion event:
     * ```kotlin
     * lifecycleScope.launch {
     *     // TODO: call from appropriate success moment
     *     reviewHelper.tryRequestReviewSuspend()
     * }
     * ```
     *
     * @param force If `true`, bypasses local cooldown checks.
     * @return `true` if review flow completed, `false` if suppressed by cooldown or failed silently.
     */
    suspend fun tryRequestReviewSuspend(force: Boolean = false): Boolean {
        val currentActivity = activityRef.get() ?: return false
        if (currentActivity.isFinishing || currentActivity.isDestroyed) return false
        if (!force && !shouldPromptReview()) return false

        hasRequestedThisSession = true

        return try {
            val reviewInfo = reviewManager.requestReviewFlow().await()
            val hostActivity = activityRef.get() ?: return false
            if (hostActivity.isFinishing || hostActivity.isDestroyed) return false

            reviewManager.launchReviewFlow(hostActivity, reviewInfo).await()
            markReviewPrompted()
            Log.i(TAG, "Google Play native In-App Review flow completed (suspend).")
            true
        } catch (e: Exception) {
            // Fail silently without user disruption
            Log.w(TAG, "In-app review flow failed silently (suspend): ${e.message}")
            false
        }
    }

    /**
     * Updates timestamps and resets action counter upon prompt execution.
     */
    private fun markReviewPrompted() {
        sharedPreferences.edit()
            .putLong(KEY_LAST_REVIEW_TIMESTAMP, System.currentTimeMillis())
            .putInt(KEY_SUCCESSFUL_ACTIONS_COUNT, 0)
            .apply()
    }

    /**
     * Clears in-memory session flag (primarily for testing or distinct multi-task workflows).
     */
    fun resetSession() {
        hasRequestedThisSession = false
    }
}
