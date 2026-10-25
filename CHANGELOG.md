# Changelog

All notable changes to the **Media Downloader & Saver** application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-10-25

### Added
- **Liquid Glass Design System**:
  - Translucent surfaces with background diffusion (`BackdropFilter`) and hairline borders (0.8 dp).
  - Floating Liquid Glass capsule bottom navigation bar (`64dp` height, `26dp` radius) with smooth scroll underlays.
  - Consistent Dark Mode (`#101014` background, dark translucent charcoal surfaces, `#B49AFF` accents) and Light Mode (`#F6F5FA` background, white translucent surfaces, `#7045E8` accents).
- **Multi-Platform Client-Side Media Inspection**:
  - **YouTube**: Stream inspection with quality presets (720p HD, 360p Data Saver, Audio-only M4A), Shorts, and embedded full-frame web view.
  - **Instagram**: Public post, reel, and story inspection via client-side metadata parsing.
  - **Facebook**: Watch, reel, and video link parsing with direct stream resolution.
  - **Spotify**: Canonical metadata extractor and full-track audio stream matching.
  - **WhatsApp Status Saver**: Direct on-device scanner for saved photos and video statuses with media player preview.
- **Standalone Architecture**:
  - 100% on-device client-side execution; requires zero external server hosting or backend microservices.
  - Direct CDN chunk streaming to internal storage.
- **Compliance & Legal Governance**:
  - Interactive terms of service and policy consent dialog on first launch.
  - Rights-confirmation verification for inspecting media.
  - Integrated in-app copyright complaint and DMCA takedown notice workflow.
- **Ecosystem Integration**:
  - Dynamic "Our Apps" catalog loaded from the Samyukt GitHub JSON registry.
  - Google Play in-app review and in-app update integrations.
- **Automated Open-Source CI/CD Release Pipeline**:
  - GitHub Actions workflow for building release APKs on version tags (`v*`) and `workflow_dispatch`.
  - Cryptographic SHA-256 checksum generation for verified sideloading.
