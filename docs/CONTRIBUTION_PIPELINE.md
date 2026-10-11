# Contribution delivery design

## Current client behaviour
- Suggestions and reports are stored on the device while offline.
- Drafts are not catalogue entries and must never become visible as verified services automatically.
- The UI warns contributors not to submit PINs, account numbers, phone numbers, or other personal information.
- Until a protected delivery endpoint is configured, the app must clearly say delivery is not connected; do not imply a draft reached maintainers.

## Vercel endpoint contract (planned)
The website is deployed from `web/`; an endpoint can live at `web/api/contribute.js` using Vercel's Node.js function runtime.

Expected request: `POST /api/contribute` with JSON fields `type` (`suggestion` or `report`), `countryCode` (`GH` or `NG`), `provider`, `title`, `description`, optional `sourceUrl`, and a `website` honeypot field which must remain empty.

Before enabling delivery:
1. Store a narrowly scoped GitHub token in Vercel environment variables only; never bundle it into Flutter or website JavaScript.
2. Validate JSON size, field types and lengths, country/type enums, and source URL protocol.
3. Reject unexpected origins and use a honeypot plus durable rate limiting (for example, an Upstash Redis counter or equivalent). In-memory rate limits alone are insufficient in serverless deployments.
4. Create an issue with a fixed label such as `community-contribution`; never allow clients to choose repository, labels, assignees, or issue state.
5. Return a stable receipt only after GitHub confirms issue creation. Use an idempotency key and server-side duplicate handling before enabling automatic retries.
6. Keep the public-issue disclosure visible; never send private data to a public issue tracker.

## Delivery states
- `pending`: saved locally and waiting for connectivity/delivery.
- `sending`: a request is currently in progress.
- `delivered`: endpoint confirmed issue creation and returned a receipt.
- `failed`: delivery was attempted but did not complete; preserve the draft for retry.

A successful HTTP response means the issue was created, not that the suggestion was approved. Maintainers review every report before catalogue changes.
