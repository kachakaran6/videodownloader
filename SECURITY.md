# Security Policy

## Supported Versions

Security updates and patches are actively applied to the latest release of Media Downloader:

| Version | Supported          | Notes |
|:-------:|:------------------:|:------|
| 1.0.x   | :white_check_mark: | Current active release branch |
| < 1.0.0 | :x:                | Deprecated / Pre-release builds |

---

## Reporting a Vulnerability

We prioritize the security and privacy of our users. If you discover a security vulnerability in Media Downloader, please help us resolve it responsibly.

### How to Report

1. **Do NOT report security vulnerabilities via public GitHub issues, discussions, or social media.**
2. Send a confidential report using GitHub's built-in **[Private Vulnerability Reporting](https://github.com/kachakaran6/videodownloader/security/advisories/new)** feature.
3. Alternatively, contact the maintainer directly via email: `legal@mediasaver.app` with the subject line `[SECURITY] Media Downloader Vulnerability Report`.

Please include in your report:
- A clear description of the vulnerability.
- Steps to reproduce or proof-of-concept code.
- Impact assessment (e.g., potential unauthorized file access, memory leak, intent redirection).
- Any proposed remediations or patches.

### Response Timeline

- **Acknowledgment:** Within 48 hours of initial receipt.
- **Triage & Assessment:** Within 5 business days.
- **Fix & Public Advisory:** Coordinated release once the patch is thoroughly tested and verified across supported Android versions.

---

## Prohibited Reports

Please note the following are explicitly out of scope:
- Requests or vulnerability claims related to bypassing Digital Rights Management (DRM) or encryption on third-party media platforms (this application is strictly non-DRM by design).
- Denial of Service attacks targeting public third-party endpoints.
- Vulnerabilities affecting rooted or heavily modified custom Android ROMs where standard platform sandboxing has been disabled.

---

## Sideloading Safety & Integrity Verification

To protect your device against tampered or malicious builds:
1. Always download official APK builds exclusively from the [Official GitHub Releases](https://github.com/kachakaran6/videodownloader/releases).
2. Verify the SHA-256 cryptographic checksum of your downloaded APK against the published `SHA256SUMS.txt` file before installation:

```bash
# Linux / macOS
sha256sum MediaDownloader-v1.0.0-universal.apk

# Windows PowerShell
Get-FileHash -Algorithm SHA256 MediaDownloader-v1.0.0-universal.apk
```
