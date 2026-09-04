fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android test

```sh
[bundle exec] fastlane android test
```

Run Flutter tests

### android preflight

```sh
[bundle exec] fastlane android preflight
```

Validate release readiness and environment without publishing

### android build

```sh
[bundle exec] fastlane android build
```

Build release AAB without uploading

### android internal

```sh
[bundle exec] fastlane android internal
```

Deploy release to Google Play Internal Testing track

### android closed

```sh
[bundle exec] fastlane android closed
```

Deploy release to Google Play Closed Testing track (Fastlane: alpha)

### android beta

```sh
[bundle exec] fastlane android beta
```

Deploy release to Google Play Open Testing track (beta)

### android production

```sh
[bundle exec] fastlane android production
```

Safely deploy release to Google Play Production (Explicit confirmation required)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
