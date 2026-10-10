# Alaa UI/UX principles

## Product promise
Alaa helps people find the right USSD service, understand it, and open it safely. Core discovery must work offline.

## Visual direction
- Calm, clear, practical utility; not a bank dashboard or social network.
- Use the official Alaa logo exactly as supplied by the owner. Do not redraw or approximate it.
- Until the original logo asset is committed, use the wordmark Alaa in text and a neutral placeholder treatment; never invent a replacement mark.
- Use Material 3, generous touch targets, strong contrast, restrained surfaces, and a green accent inspired by the existing brand asset. Confirm final tokens against the original logo.
- Avoid gradients, unnecessary animation, decorative cards, and excessive metrics.

## Navigation
Bottom navigation: Home, Categories, Favourites, Contributions. Settings and About are accessible from the app-bar menu. Search is available on Home and matches intent, service name, code, and provider.

## Service details
Show purpose, country, provider, code, instructions, verification state, source, and last checked date when known. Primary actions: Open USSD and Copy code. Never imply a transaction completed inside Alaa.

## Trust and safety
- Clearly distinguish verified catalogue records from community submissions.
- Explain that USSD may incur charges or initiate consequential actions.
- Do not request, store, or intercept PINs, USSD session responses, or transaction credentials.
- Submissions and broken-code reports remain pending until reviewed.
- Public GitHub Issues may expose submitted text; warn users not to include personal information.

## Accessibility and low-end devices
- Support system, light, and dark themes.
- Keep screens responsive on small Android devices.
- Use readable type, semantic labels, accessible contrast, and large tap targets.
- Prefer instant local search and avoid requiring sign-in.

## Implementation note
Initial catalogue entries are illustrative only, not an authoritative live catalogue. Never publish them as verified without individually checking reliable sources.
