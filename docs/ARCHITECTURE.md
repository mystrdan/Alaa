# Alaa architecture

## Target architecture
1. Presentation: Home, search, categories, service details, favourites, recents, contributions, settings, About.
2. Domain: catalogue entries, country/provider scoping, verification states, search, update and submission states.
3. Local data: SQLite for catalogue, favourites, recents, and persistent pending contributions.
4. Catalogue delivery: public GitHub-hosted JSON plus a versioned manifest; validate signature, hashes, schema and compatibility before transactional import.
5. Contribution delivery: a small serverless endpoint with a restricted GitHub App credential creates structured GitHub Issues. Never ship a token in the app. Offline submissions queue locally and retry with stable IDs.
6. Android integration: open USSD through supported Android intents/platform integration; offer copy fallback. Behaviour varies by device and SIM.
7. Quality: tests for models, search, validation, update rollback, retries, and widget flows.

## Trust model
- Published catalogue records are maintained through reviewed changes.
- Issues are an inbox, not a source of live trusted data.
- The app must not promote submissions automatically.
- If an update is invalid, retain the last known-good catalogue.
- Public submissions can be visible to anyone; show a privacy warning.

## Catalogue update flow
Fetch manifest -> verify signature and hashes -> validate schema and version -> stage data -> validate entries -> transactionally import -> record installed version. On failure, retain the prior catalogue and retry later.

## Contribution flow
Validate locally -> persist pending item -> when online send to endpoint -> endpoint validates size/content/rate limit and creates issue -> app marks delivered only after confirmed success. Retries must be idempotent or use stable IDs to prevent duplicates.

## Release plan
Catalogue updates do not require app reinstall. UI changes, native integration changes, and bug fixes require a normal app release. Bundle a known-good catalogue with each release for first-run offline use.
