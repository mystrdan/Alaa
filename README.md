# Alaa

**Your offline-first USSD assistant.**

Alaa helps people in Ghana and Nigeria discover USSD services by intent, understand what each code does, and launch supported codes from their Android device. The verified catalogue works offline and can update independently of the app.

## Project status

The repository is being initialized. The first milestone is the Flutter Android foundation, local catalogue model, and UX architecture.

## Product principles

- Offline-first: core discovery, details, favourites, and recents work without internet.
- Trust first: user submissions never become verified catalogue entries automatically.
- Independent catalogue updates: published catalogue data can change without reinstalling the app.
- Minimal data collection: no account required for core use; favourites and history stay local.
- Safe launching: Alaa opens the device's USSD handler when supported and provides a copy fallback.

## Planned stack

- Flutter / Dart
- SQLite local storage
- Android-native USSD launch integration where needed
- Public, versioned GitHub-hosted catalogue
- Secure serverless endpoint for creating GitHub Issues from in-app contributions

## Branding

Use the official Alaa logo asset supplied by the project owner as the source of truth. Do not redraw, distort, recolor, or substitute the logo. Until the original asset is added to `assets/branding/`, UI development should use a neutral placeholder treatment and not invent a replacement mark.

## Development

See `docs/` for architecture and UX decisions. Run `flutter pub get`, then `flutter analyze` and `flutter test` once the Flutter SDK is installed.