# Contributing to Media Downloader

Thank you for your interest in contributing to Media Downloader! We welcome community contributions, bug fixes, enhancements, and documentation improvements.

---

## Code of Conduct

All contributors are expected to follow our [Code of Conduct](CODE_OF_CONDUCT.md). Please treat all community members with courtesy and respect.

---

## Development Prerequisites

Before building the application locally, ensure your environment meets the following specifications:

- **Flutter SDK:** Version `3.22.0` or higher (tested with Dart `^3.12.2`).
- **Java Development Kit (JDK):** JDK 17 (required by Android Gradle Plugin 8.x / Gradle 9.x).
- **Android SDK:** API Level 34+ (Android 14) with Command-line Tools and Platform Tools installed.
- **Git:** Version 2.30+.

---

## Local Development Setup

1. **Fork and Clone the Repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/videodownloader.git
   cd videodownloader
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify Static Analysis:**
   ```bash
   flutter analyze
   ```
   *All pull requests must pass `flutter analyze` with 0 warnings or errors.*

4. **Run the Automated Test Suite:**
   ```bash
   flutter test
   ```
   *All existing unit and widget tests must pass.*

5. **Run the Application:**
   ```bash
   # Connected Android device or emulator
   flutter run
   ```

---

## Code Guidelines & Standards

- **Liquid Glass Design Language:** All user interfaces must adhere to the shared Liquid Glass token system (`lib/core/theme/liquid_glass_tokens.dart` and `LiquidGlassSurface` / `LiquidGlassCard`). Do NOT introduce hardcoded solid grey backgrounds, harsh drop shadows, or unstyled containers.
- **No Emojis in UI:** Use Material Icons or Cupertino Icons rather than decorative emojis.
- **Strict Client-Side Architecture:** Do not introduce dependencies requiring closed-source, proprietary external servers or cloud services. The application must remain 100% serverless and client-side executable.
- **Documentation & Comments:** Maintain clear, concise Dart docstrings for public classes and methods.

---

## Legal & Compliance Requirements for Contributions

To ensure the safety and longevity of the open-source project:

1. **NO DRM Circumvention:** Pull Requests containing algorithms, keys, or techniques intended to bypass, decrypt, or circumvent Digital Rights Management (DRM) protections (e.g. Widevine, FairPlay, PlayReady) or encrypted paywalled streams **will be rejected immediately**.
2. **Third-Party Rights:** Contributions must not infringe upon third-party copyrights, patents, or trade secrets.
3. **No Private Secrets or Keys:** Never commit API keys, signing keystores, or personal configuration files to Git.

---

## Pull Request Workflow

1. Create a feature branch off `master`:
   ```bash
   git checkout -b feat/my-new-feature
   ```

2. Follow Conventional Commits for commit messages:
   - `feat(...)`: A new user-facing feature
   - `fix(...)`: A bug fix
   - `docs(...)`: Documentation updates
   - `refactor(...)`: Code refactoring without behavioral change
   - `test(...)`: Adding or updating tests
   - `chore(...)`: Maintenance or CI tasks

3. Run full verification before pushing:
   ```bash
   flutter analyze
   flutter test
   ```

4. Push your branch and open a Pull Request against `master`. Fill out the [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md) completely.
