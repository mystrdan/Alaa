# Alaa

**Your offline-first USSD assistant.**

Alaa is an Android-first Flutter project for helping people in Ghana and Nigeria discover USSD services by intent, understand what a code does, and launch supported codes through the device dialer.

## Project status

Alaa is an active development prototype, **not ready for real transactions or public release**. The current catalogue contains illustrative, unverified demo content; it does not yet contain a verified live USSD catalogue. Do not rely on demo entries for financial or account actions.

## Current prototype

- Home/search and category navigation.
- Ghana/Nigeria country selector.
- Service details with verification-state safeguards.
- Favourites and contribution drafts saved locally.
- Settings, About, and native Share Alaa entry point.
- USSD launch is gated on verification; device behaviour and copy fallback still need physical-device testing.
- Responsive product landing page in `web/`, deployed at https://alaa-capsicom.vercel.app.

## Product principles

- **Offline first:** core discovery should remain usable without internet.
- **Trust first:** user submissions never become verified catalogue entries automatically.
- **Independent catalogue updates:** published catalogue data should update without reinstalling the app.
- **Minimal data collection:** no account is required for core use; favourites and drafts are stored locally.
- **Safe launching:** open the device's supported USSD handler when available, with a copy fallback; behaviour varies by Android version, dialer, and SIM setup.

## Planned stack and architecture

- Flutter / Dart for the Android app.
- SQLite is the target for durable catalogue and history storage; the current prototype uses local preferences for favourites and drafts.
- Versioned, public catalogue JSON with schema, integrity/signature checks, and rollback to the last known-good version.
- A protected serverless endpoint for in-app contribution delivery to GitHub Issues. Never ship a GitHub credential in the app.
- Review required before any submitted code can appear as verified catalogue content.

See `docs/ARCHITECTURE.md`, `docs/UX.md`, `docs/CONTRIBUTION_PIPELINE.md`, and `docs/IMPLEMENTATION_STATUS.md` for design constraints and gaps.

## Development

Install the Flutter SDK, then run:

```sh
flutter pub get
flutter analyze
flutter test
```

The GitHub Actions workflow runs analysis and tests, then builds a **debug-only Android APK** if checks pass. Open [GitHub Actions](https://github.com/mystrdan/Alaa/actions), select a successful run, and download the `alaa-android-debug-apk` artifact from its Artifacts section. Artifacts expire after 14 days. A debug APK is for development/testing, not a signed production release.

## Branding

The official Alaa logo supplied by the project owner is the source of truth. Do not redraw, distort, recolor, or substitute it. Until the original asset is committed under `assets/branding/`, use a neutral placeholder and do not invent a replacement mark.

## Before release

- Add and verify sourced Ghanaian and Nigerian catalogue entries.
- Implement and test signed catalogue updates and safe rollback.
- Implement secure, rate-limited, idempotent contribution delivery.
- Finish durable local storage, privacy policy, and delivery-status UX.
- Test installation and dialer/copy behaviour on physical Android devices, including dual-SIM configurations.
- Add the official logo, app icon, splash screen, and release signing.
