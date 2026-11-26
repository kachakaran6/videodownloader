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
        val adView = layoutInflater.inflate(R.layout.native_ad_card, null) as NativeAdView

        // 1. Headline (Required)
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        // 2. Body Text
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        if (!nativeAd.body.isNullOrBlank()) {
            bodyView.text = nativeAd.body
            bodyView.visibility = View.VISIBLE
        } else {
            bodyView.visibility = View.GONE
        }
        adView.bodyView = bodyView

        // 3. Call to Action Button
        val ctaView = adView.findViewById<Button>(R.id.ad_call_to_action)
        if (!nativeAd.callToAction.isNullOrBlank()) {
            ctaView.text = nativeAd.callToAction
            ctaView.visibility = View.VISIBLE
        } else {
            ctaView.visibility = View.GONE
        }
        adView.callToActionView = ctaView

        // 4. App Icon
        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)
        val icon = nativeAd.icon
        if (icon?.drawable != null) {
            iconView.setImageDrawable(icon.drawable)
            iconView.clipToOutline = true
            iconView.visibility = View.VISIBLE
        } else {
            iconView.visibility = View.GONE
        }
        adView.iconView = iconView

        // 5. Advertiser
        val advertiserView = adView.findViewById<TextView>(R.id.ad_advertiser)
        if (!nativeAd.advertiser.isNullOrBlank()) {
            advertiserView.text = nativeAd.advertiser
            advertiserView.visibility = View.VISIBLE
        } else {
            advertiserView.visibility = View.GONE
        }
        adView.advertiserView = advertiserView

        // 6. Media View
        val mediaView = adView.findViewById<MediaView>(R.id.ad_media)
        val mediaContent = nativeAd.mediaContent
        if (mediaContent != null) {
            mediaView.mediaContent = mediaContent
            mediaView.clipToOutline = true
            mediaView.visibility = View.VISIBLE
        } else {
            mediaView.visibility = View.GONE
        }
        adView.mediaView = mediaView

        // Bind AdMob NativeAd to View
        adView.setNativeAd(nativeAd)
        return adView
    }
}
