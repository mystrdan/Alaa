# Implementation status

## Committed to main
- Flutter package manifest and lint configuration.
- Material 3 UI foundation with Home, Categories, Favourites, Contributions, service details, Settings, About, and Share Alaa entry point.
- Ghana/Nigeria country selector and local intent/service search prototype.
- USSD catalogue entry model with verification status and a safe, explicitly unverified demo seed.
- Catalogue manifest, record schema, and empty country catalogue files.
- Architecture and UX guidance, official-logo handling note, widget smoke test, local-preferences persistence tests, and GitHub Actions analyze/test workflow.
- Public product landing page in `web/`, deployed to Vercel project `alaa` (project ID `prj_BK8MvRwCwCtKTgjXJz2CArByf8vm`); GitHub `main` is connected for automatic deployment.

## Not implemented yet
- Generated Android platform project and device build.
- Transactional SQLite persistence for the catalogue and recents (favourites and draft contributions currently use local preferences).
- Physical-device verification of USSD launch/copy behavior across Android dialers and dual-SIM devices.
- Country/network auto-detection and provider filters.
- Signed catalogue update client and cryptographic key management.
- Serverless GitHub Issue creation endpoint, rate limiting, and idempotent delivery.
- Real, individually sourced and verified catalogue records.
- Official logo file, app icon, splash screen, privacy policy, and release signing.

## Important
This is a development scaffold, not a release-ready app. Demo entries are not working codes and must not be used for real transactions. No build/test result should be considered passing until the latest GitHub Actions workflow completes successfully and a physical Android device test is performed.
