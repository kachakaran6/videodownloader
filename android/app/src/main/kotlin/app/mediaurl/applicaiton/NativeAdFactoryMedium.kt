package app.mediaurl.applicaiton

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

class NativeAdFactoryMedium(private val layoutInflater: LayoutInflater) :
    NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = try {
            layoutInflater.inflate(R.layout.native_ad_card, null) as NativeAdView
        } catch (e: Throwable) {
            val fallback = NativeAdView(layoutInflater.context)
            fallback.setNativeAd(nativeAd)
            return fallback
        }

        try {
            // 1. Headline (Required)
            val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
            headlineView?.let {
                it.text = nativeAd.headline
                adView.headlineView = it
            }

            // 2. Body Text
            val bodyView = adView.findViewById<TextView>(R.id.ad_body)
            bodyView?.let {
                if (!nativeAd.body.isNullOrBlank()) {
                    it.text = nativeAd.body
                    it.visibility = View.VISIBLE
                } else {
                    it.visibility = View.GONE
                }
                adView.bodyView = it
            }

            // 3. Call to Action Button
            val ctaView = adView.findViewById<Button>(R.id.ad_call_to_action)
            ctaView?.let {
                if (!nativeAd.callToAction.isNullOrBlank()) {
                    it.text = nativeAd.callToAction
                    it.visibility = View.VISIBLE
                } else {
                    it.visibility = View.GONE
                }
                adView.callToActionView = it
            }

            // 4. App Icon
            val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)
            val icon = nativeAd.icon
            iconView?.let {
                if (icon?.drawable != null) {
                    it.setImageDrawable(icon.drawable)
                    it.clipToOutline = true
                    it.visibility = View.VISIBLE
                } else {
                    it.visibility = View.GONE
                }
                adView.iconView = it
            }

            // 5. Advertiser
            val advertiserView = adView.findViewById<TextView>(R.id.ad_advertiser)
            advertiserView?.let {
                if (!nativeAd.advertiser.isNullOrBlank()) {
                    it.text = nativeAd.advertiser
                    it.visibility = View.VISIBLE
                } else {
                    it.visibility = View.GONE
                }
                adView.advertiserView = it
            }

            // 6. Media View
            val mediaView = adView.findViewById<MediaView>(R.id.ad_media)
            val mediaContent = nativeAd.mediaContent
            mediaView?.let {
                if (mediaContent != null) {
                    it.mediaContent = mediaContent
                    it.clipToOutline = true
                    it.visibility = View.VISIBLE
                } else {
                    it.visibility = View.GONE
                }
                adView.mediaView = it
            }

            // Bind AdMob NativeAd to View
            adView.setNativeAd(nativeAd)
        } catch (e: Throwable) {
            // If any binding error occurs, safely associate the ad
            try {
                adView.setNativeAd(nativeAd)
            } catch (_: Throwable) {}
        }
        return adView
    }
}
