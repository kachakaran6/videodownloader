# Media Downloader & Saver

<div align="center">

[![Latest Release](https://img.shields.io/github/v/release/kachakaran6/videodownloader?color=7045E8&logo=github&label=Release)](https://github.com/kachakaran6/videodownloader/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter Version](https://img.shields.io/badge/Flutter-%3E%3D3.22.0-02569B?logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-8.0%2B%20(API%2026%2B)-3DDC84?logo=android)](https://developer.android.com)
[![Architecture](https://img.shields.io/badge/Architecture-100%25%20Serverless%20%2F%20Client--Side-brightgreen)](#-architecture--privacy-first)

**A high-performance, standalone Android media utility featuring a refined Liquid Glass design language, instant URL inspection, multi-platform stream resolution, and complete on-device privacy.**

[Download APK](#-download-the-android-apk) • [Features](#-features) • [Build from Source](#-build-from-source) • [Architecture](#-architecture--privacy-first) • [Legal Disclaimer](#-legal-disclaimer--acceptable-use-policy)

</div>

---

## 📥 Download the Android APK

You can download the pre-compiled, production-ready Android APK directly from our GitHub Releases page:

### 👉 **[Download Latest APK from GitHub Releases](https://github.com/kachakaran6/videodownloader/releases/latest)**

### Installation (Sideloading) Guide

1. Navigate to the **[Latest Release](https://github.com/kachakaran6/videodownloader/releases/latest)** page.
2. In the **Assets** section, download `MediaDownloader-v1.0.0-universal.apk`.
3. Open the downloaded `.apk` file on your Android device (via your browser's download manager or a file manager).
4. **Android Security Prompt:**
   - Android will typically display a standard system prompt: *"For your security, your phone is not allowed to install unknown apps from this source"*.
   - Tap **Settings** in the prompt, toggle **Allow from this source** for your browser or file manager, and tap **Install**.
   > **Why does Android show this?** This is standard Android operating system behavior for any application installed outside Google Play (sideloaded open-source software such as F-Droid, Signal, or VLC). The application contains no trackers, adware, or telemetry.
5. Launch the application and enjoy clean, direct media inspection!

### Cryptographic Checksum Verification (Optional)
To verify that your downloaded APK is untampered and authentic, check its SHA-256 hash against the published `SHA256SUMS.txt`:

```bash
# Linux / macOS
sha256sum MediaDownloader-v1.0.0-universal.apk

# Windows PowerShell
Get-FileHash -Algorithm SHA256 MediaDownloader-v1.0.0-universal.apk
```

---

## ✨ Features

- **Liquid Glass Design System:**
  - Optical backdrop blur diffusion (`BackdropFilter`) with fine 0.8 dp hairline borders.
  - Floating Liquid Glass capsule navigation bar (`64dp` height, `26dp` radius) with content scrolling seamlessly behind.
  - Handcrafted **Dark Mode** (`#101014` background, dark translucent charcoal surfaces, `#B49AFF` accents) and **Light Mode** (`#F6F5FA` background, white translucent surfaces, `#7045E8` accents).
  - Single integrated URL input field with 1-tap clipboard paste and clear controls.

- **Multi-Platform Client-Side Resolution:**
  - **YouTube:** Inspect authorized videos and Shorts. Choose stream quality presets:
    - **720p HD** (Direct MP4 stream)
    - **360p Data Saver** (Bandwidth-friendly MP4 stream)
    - **Audio Only** (Crisp standalone M4A track)
  - **In-App YouTube Browser:** Discover authorized media within an integrated web view with an animated floating Liquid Glass inspection banner.
  - **Instagram:** Direct resolution of public Reels, Posts, and Stories via client-side metadata parsing.
  - **Facebook:** Direct inspection of public Watch videos, Reels, and mobile page video streams.
  - **Spotify:** Canonical metadata inspection (track title, artist, album art) with automated audio matching.
  - **WhatsApp Status Saver:** Direct on-device scanner to view, preview, and save temporary photo and video statuses before they expire.

- **Media Management & Playback:**
  - Real-time download progress tracking with live speed metrics (e.g. `5.2 MB/s`), estimated time of arrival (ETA), and downloaded byte counters.
  - Integrated full-screen video player for instant local playback.
  - Direct system export and sharing (`share_plus`) and default Android media player launching (`open_filex`).

- **Ecosystem Integration:**
  - Centralized "Our Apps" catalog loaded from the Samyukt GitHub JSON registry.
  - Google Play in-app review and update workflow compatibility.

---

## 🛡️ Architecture & Privacy-First

### 100% Serverless & On-Device
Unlike many media downloader tools that route user requests through closed-source, third-party backend servers (e.g. FastAPI, Python scrapers, or remote proxies), **Media Downloader runs 100% on your personal device**:
- **Zero Intermediate Servers:** Media chunks stream directly from public content delivery networks (CDNs) into your Android storage.
- **Maximum Download Speed:** Eliminates intermediate bandwidth bottlenecks and server latency.
- **Complete Privacy:** No remote server logs your search queries, URLs, IP address, or downloaded media.
- **Zero Maintenance:** No backend infrastructure to deploy, pay for, or maintain.

---

## 💻 Build from Source

You can build the application locally from source using standard Flutter tools.

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.22.0`)
- [Java Development Kit (JDK)](https://adoptium.net/) (JDK 17)
- Android SDK (API Level 34+ recommended)

### Build Commands

```bash
# 1. Clone the repository
git clone https://github.com/kachakaran6/videodownloader.git
cd videodownloader

# 2. Fetch Dart dependencies
flutter pub get

# 3. Verify static analysis (0 issues)
flutter analyze

# 4. Run automated test suite
flutter test

# 5. Build release APK
flutter build apk --release
```

The compiled release APK will be generated at:
```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔑 Android Release Signing

By default, running `flutter build apk --release` without a private keystore will gracefully sign the release APK using the standard Android debug keystore (as configured in `android/app/build.gradle.kts`), ensuring that any developer or fork maintainer can compile and run a release APK immediately without signing errors.

### Configuring Custom Production Signing
To sign the APK with your own release keystore:

1. Create a `key.properties` file in `android/`:
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=YOUR_KEY_ALIAS
   storeFile=path/to/your/upload-keystore.jks
   ```
2. For automated GitHub Actions releases, configure these repository secrets:
   - `KEYSTORE_BASE64`: Base64-encoded string of your `.jks` file (`base64 -w 0 upload-keystore.jks`)
   - `KEYSTORE_PASSWORD`: Keystore password
   - `KEY_ALIAS`: Key alias name
   - `KEY_PASSWORD`: Key password

---

## ⚖️ Legal Disclaimer & Acceptable Use Policy

> **IMPORTANT LEGAL NOTICE — PLEASE READ CAREFULLY BEFORE USING OR CONTRIBUTING TO THIS SOFTWARE.**

### 1. Educational and Personal Archival Use Only
Media Downloader is developed, maintained, and distributed strictly for **personal archival, educational, interoperability, and fair-use research purposes**. It is designed solely to allow users to archive content that:
- They personally own or created;
- Is published under a Creative Commons or public domain license; or
- For which they have received explicit, express written authorization from the copyright holder.

### 2. Non-Affiliation Statement
This software and its developers are **NOT affiliated, associated, authorized, endorsed by, or in any way officially connected** with YouTube, Google LLC, Meta Platforms Inc., Instagram, Facebook, Spotify AB, WhatsApp LLC, or any of their parent companies, subsidiaries, or affiliates. All product names, logos, brands, and registered trademarks mentioned are property of their respective owners. Their mention in this repository does not imply endorsement or affiliation.

### 3. No DRM Circumvention (Digital Rights Management)
This software does **NOT** circumvent, bypass, decrypt, crack, or defeat any technological protection measures (TPMs), encryption algorithms, or Digital Rights Management (DRM) systems such as Google Widevine, Apple FairPlay, or Microsoft PlayReady.
- **Protected, encrypted, rented, paywalled, or subscription-gated streams are intentionally unsupported and rejected.**

### 4. Zero Content Hosting & Zero Storage
This application does **NOT** host, cache, index, store, re-transmit, or distribute copyrighted video, audio, or photographic files on any external server. All network activity is performed exclusively and directly on the end user's local device.

### 5. User Responsibility & Compliance
Users of this application assume **sole and exclusive legal responsibility** for compliance with all applicable local, regional, national, and international copyright laws, intellectual property rights, and third-party Terms of Service. The maintainers, authors, and contributors of this software explicitly disclaim all liability for any misuse, unauthorized downloading, reproduction, or statutory violation committed by end users.

### 6. Copyright Takedown & DMCA Policy
If you are a copyright owner or authorized representative and believe that any documentation or code in this repository infringes upon your intellectual property, please submit a formal notification to:
- **Email:** `legal@mediasaver.app`
- Please include: (a) Identification of the copyrighted work, (b) Exact URL or file location within this repository, (c) Your contact details, and (d) A statement of good-faith belief.

---

## 🤝 Contributing

We welcome community contributions! Please read our [CONTRIBUTING.md](CONTRIBUTING.md) guide and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before submitting pull requests.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for complete details and warranty disclaimers.
