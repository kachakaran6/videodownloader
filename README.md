# Media Saver — YouTube MVP (Direct On-Device)

A high-performance, standalone Android mobile application built with Flutter and Material 3 that allows users to inspect authorized YouTube videos, select user-friendly stream qualities (720p HD, 360p Data Saver, or Audio Only), track real-time progress (speed, ETA, downloaded bytes), and save media directly to their device.

---

## Key Highlights & Architecture

- **100% Serverless / Standalone**: No separate backend, no cloud hosting bills, zero server storage needed.
- **Direct-from-CDN Streaming**: Media chunks stream directly from YouTube's edge CDN straight into Android device storage via [`youtube_explode_dart`](https://pub.dev/packages/youtube_explode_dart).
- **Maximum Download Speed**: Eliminates intermediate server hops and bandwidth chokepoints.
- **Responsible & Authorized Use**: Mandatory rights-confirmation checkbox required before every download, disallowing playlists, private content, and DRM.
- **Material 3 Design**: Dark mode aesthetic with custom indigo/cyan accents, micro-animations, glass cards, and status indicators.
- **Offline History & Export**: Completed files can be directly played via the device's native media player (`open_filex`) or shared/exported across apps (`share_plus`).

---

## App Screens

1. **First-Launch Notice**: Legal disclaimer and authorized-use terms modal requiring user acknowledgment.
2. **Home Screen**:
   - URL input card with 1-tap "PASTE" from clipboard and "CLEAR" controls.
   - Real-time link validation (supports `youtube.com/watch?v=...`, `youtu.be/...`, `youtube.com/shorts/...`).
   - "Check Video" button with loading feedback.
   - Quick-access "Recent Downloads" list.
3. **Video Details & Quality Picker Sheet**:
   - Thumbnail preview, duration badge, title, and channel author.
   - Friendly quality cards:
     - **720p HD** (Recommended · MP4 · Video + Audio)
     - **360p Data Saver** (MP4 · Video + Audio)
     - **Audio Only** (High-quality M4A track)
   - Wi-Fi warning banner if estimated file size > 200 MB.
   - Mandatory rights confirmation checkbox (*"I own this content or have explicit permission to download it."*).
4. **Download Detail & Live Progress**:
   - Live download percentage and linear progress indicator.
   - Real-time metrics: Downloaded / Total bytes, current Speed (e.g. `4.5 MB/s`), and ETA seconds.
   - One-tap Cancel action (aborts stream and cleans up partial file).
   - Post-download actions: **Play Video**, **Share / Export**, and **Done**.
5. **Download History**:
   - Filter by All, Completed, or Failed.
   - Tap to play, share/export, or delete.
6. **Settings**:
   - Default quality preference (720p / 360p / Audio).
   - Wi-Fi only download switch.
   - Download directory location.
   - Legal policy review and app version.

---

## Project Structure

```text
.
├── android/                  # Native Android configuration (app.mediaurl.applicaiton)
├── ios/                      # Native iOS project
├── web/                      # Web support
├── lib/                      # Flutter application source
│   ├── main.dart             # Bootstrap & ProviderScope initialization
│   ├── app/                  # App setup & Material 3 theming
│   ├── core/                 # Errors, storage, theme tokens, formatters, and validators
│   └── features/             # Modular feature slices
│       ├── disclaimer/       # Authorized-use notice modal
│       ├── inspect/          # Video metadata & stream inspection
│       ├── downloads/        # Direct CDN streaming & progress controller
│       ├── history/          # Local download persistence & export
│       └── settings/         # App settings & storage preferences
├── test/                     # Unit & widget tests
├── pubspec.yaml              # Dart dependencies & asset configuration
└── README.md
```

---

## Running the App

### Prerequisites
- Flutter SDK (>= 3.44.0)
- Android SDK or connected Android device / emulator

### Run on Device
```bash
flutter pub get
flutter run
```

Or target a specific device:
```bash
flutter run -d <DEVICE_ID>
```

### Run Tests
```bash
flutter test
```
