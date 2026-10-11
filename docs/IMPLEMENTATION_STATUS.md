# Implementation status

## Committed to main
- Flutter package manifest and lint configuration.
- Material 3 UI foundation with Home, Categories, Favourites, Contributions, service details, Settings, About, and Share Alaa entry point.
- Ghana/Nigeria country selector and local intent/service search prototype.
- USSD catalogue entry model with verification status and a safe, explicitly unverified demo seed.
- Catalogue manifest, record schema, and empty country catalogue files.
- Architecture and UX guidance, official-logo handling note, widget smoke test, local-preferences persistence tests, and GitHub Actions analyze/test workflow.
- CI now generates Android platform files in its runner, builds a debug APK after analysis/tests pass, and uploads the APK as a 14-day workflow artifact.
- Contribution-delivery contract documented, including server-side secret handling, validation, durable rate limiting, idempotency, and review requirements.
- Local contribution drafts now retain stable IDs, type, UTC creation time, and status; malformed optional fields are normalized during recovery so one wrongly typed field does not crash draft parsing.
- Contribution queue distinguishes reports from suggestions, with widget coverage for opening the respective forms.
- Public product landing page in `web/`, deployed to Vercel project `alaa` (project ID `prj_BK8MvRwCwCtKTgjXJz2CArByf8vm`); GitHub `main` is connected for automatic deployment.

## Not implemented yet
- Committed Android platform project; CI-generated debug APK is being validated. A physical-device build/install test remains outstanding.
- Transactional SQLite persistence for the catalogue and recents (favourites and draft contributions currently use local preferences).
- Physical-device verification of USSD launch/copy behavior across Android dialers and dual-SIM devices.
- Country/network auto-detection and provider filters.
- Signed catalogue update client and cryptographic key management.
- Serverless GitHub Issue creation endpoint, rate limiting, and idempotent delivery.
- Real, individually sourced and verified catalogue records.
- Official logo file, app icon, splash screen, privacy policy, and release signing.

## Important
This is a development scaffold, not a release-ready app. Demo entries are not working codes and must not be used for real transactions. No build/test result should be considered passing until the latest GitHub Actions workflow completes successfully and a physical Android device test is performed.
