# URL Testing Guide for Instagram/YouTube/Spotify Downloader

## Device: Android (I2011)
**App Status:** Running in background via `flutter run -d I2011`

## Testing Approach

Since I cannot directly automate the Flutter UI, follow these steps on your Android device:

---

## 📋 TEST 1: Instagram Reel URL

**URL:** `https://www.instagram.com/reel/Df70Zc2IAAI/?evlk=NTV2OTRxYm9paDg5`

### Expected Behavior:
1. **URL Detection:** App should detect "Instagram Reel" platform
2. **Metadata Display:** Show reel title, author, duration, thumbnail
3. **Quality Options:** Display available video quality formats
4. **Download Options:** List downloadable formats (MP4, various resolutions)

### Test Steps:
1. Open the app on your Android device
2. Paste the Instagram Reel URL into the input field
3. Wait for platform detection (should show "Instagram Reel")
4. Check metadata displayed:
   - ✅ Author/username
   - ✅ Title/caption
   - ✅ Duration
   - ✅ Thumbnail preview
5. Tap "Download" or "Inspect"
6. **Verify available formats:**
   - Select different quality options (1080p, 720p, 480p, etc.)
   - Observe format labels change
7. **Test download:**
   - Select a format
   - Initiate download
   - Check download completion notification
   - Verify file plays correctly in device's media player

### Expected Formats (from code inspection):
- `1080p Full HD` (if width/height >= 1080)
- `720p HD` (if width/height >= 720)
- `480p SD` (if width/height >= 480)
- `High Quality (MP4)` (type 101)
- `Standard Quality (MP4)` (type 102)
- `Mobile Saver (MP4)` (type 103)

---

## 📋 TEST 2: YouTube Shorts URL

**URL:** `https://youtu.be/FYHvlRJXG2A?si=wu5WwGraPLTA17jU`

**Alternative URL:** `https://youtube.com/shorts/Ri3D9m__AMo?si=P3E50KNe8Af2c859`

### Expected Behavior:
1. **URL Detection:** App should detect "YouTube" platform
2. **Video Info:** Show video title, author, duration
3. **Streaming Options:** Display available quality levels
4. **Download Option:** Progressive download or streaming

### Test Steps:
1. Paste YouTube Shorts URL
2. Verify platform detection ("Video" or "YouTube")
3. Check displayed metadata:
   - ✅ Video title
   - ✅ Channel/author name
   - ✅ Duration (should be < 60s for Shorts, or > 60s for regular videos)
4. **Test streaming quality:**
   - Select different resolution options
   - Verify video player opens
5. **Test download (if available):**
   - Select "Download" option
   - Wait for download completion
   - Verify downloaded file plays correctly

### Notes:
- YouTube Shorts are typically < 60 seconds
- Regular YouTube videos may have multiple quality options (144p, 240p, 360p, 480p, 720p, 1080p, 4K)

---

## 📋 TEST 3: Spotify Track URL

**URL:** `https://open.spotify.com/track/43SKg10CCeaoyr7XSKfpTR?si=g6-h8n-RSEqrbpslfCqnSA&utm_source=copy-link&sci=spotify%3Acard-config%3A1tlOs2HwDQQms3VXp7wnCx`

### Expected Behavior:
1. **URL Detection:** App should detect "Spotify" platform
2. **Track Metadata:** Show track title, artist, album, duration
3. **Audio Quality Options:** Display available audio bitrates
4. **Preview Option:** 30-second preview if full track unavailable

### Test Steps:
1. Paste Spotify Track URL
2. Verify platform detection ("Music")
3. Check metadata displayed:
   - ✅ Track title
   - ✅ Artist name
   - ✅ Album name (if available)
   - ✅ Duration
   - ✅ Thumbnail/cover art
4. **Test audio stream options:**
   - "Full Length Audio (Full Bitrate)" - highest quality
   - "Standard Audio" - medium quality
   - "Audio Preview Snippet (30s)" - if full unavailable
5. **Test playback:**
   - Select an audio option
   - Verify audio starts playing
   - Check audio quality (bitrate displayed)
6. **Test download (if supported):**
   - Initiate audio download
   - Verify MP3/M4A file format
   - Check file in device's music player

### Expected Stream Options (from code):
- `Full Length Audio ($kbps kbps MP3)` - full track
- `Standard Audio ($kbps kbps MP3)` - standard quality
- `Audio Preview Snippet (30s Audio - Full Song Unavailable)` - if no full match

---

## 📋 TEST 4: Verification Checklist

After testing each URL, verify:

### ✅ Format Correctness
- [ ] Video files have correct extension (.mp4, .m4v, etc.)
- [ ] Audio files have correct extension (.mp3, .m4a, etc.)
- [ ] Video resolution matches selected quality
- [ ] Audio bitrate matches selected option
- [ ] Duration of downloaded file matches expected

### ✅ Feature Functionality
- [ ] URL detection works for all 4 URL types
- [ ] Metadata displays correctly (title, author, duration)
- [ ] Quality/format options are presented
- [ ] Download/stream initiates successfully
- [ ] Completed files are accessible in device storage
- [ ] Files play correctly in default media apps

### ✅ Error Handling
- [ ] Invalid URLs show appropriate error messages
- [ ] Private/age-restricted content handled gracefully
- [ ] Network errors displayed appropriately
- [ ] Offline behavior tested

---

## 🔧 Troubleshooting

### Common Issues:
1. **"Could not extract media"** - URL format may have changed, or content is restricted
2. **"No download options available"** - Content may have limited download permissions
3. **"Format not supported"** - Try selecting different quality option
4. **Download stalls** - Check internet connection, try again

### If Features Don't Work:
1. Ensure the Android app has necessary permissions (storage, network)
2. Verify the connected device has sufficient storage
3. Check that Instagram/YouTube/Spotify content is publicly accessible
4. Some content may be region-restricted or private

---

## 📊 Test Priority Order

Test in this order for best results:
1. **Instagram Reel** - Most commonly used, usually works well
2. **YouTube Shorts** - Verify YouTube integration
3. **Spotify Track** - Test audio streaming/download features

---

*Testing started: Sat Nov 28 2026*
*Device: Android 13 (API 33) - I2011*
*App Version: 1.0.8+43*