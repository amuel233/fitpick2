# Firestore `users` document — field reference

This document lists fields stored in each user's Firestore document and how they are used to tailor "View Picks" (shopping/search suggestions) based on gender and profile data.

- `avatarURL` (string)
  - Example: `https://firebasestorage.googleapis.com/.../avatars/user_email_avatar.jpg?alt=media&token=...`
  - Usage: used to fetch the user's avatar when generating try-on previews or composing AI prompts for appearance-aware suggestions.

- `createdAt` (timestamp)
  - Example: `2026-01-23T12:45:30Z`
  - Usage: metadata only; not used for view-picks generation.

- `email` (string)
  - Example: `user@example.com`
  - Usage: primary key for user lookups and permissioned Firestore queries.

- `following` (array of strings)
  - Example: `["friend@example.com"]`
  - Usage: social features only; not used for view-picks suggestions.

- `gender` (string)
  - Example: `"Male"` or `"Female"` or other values (e.g., `"Non-binary"`).
  - Usage: CORE for gender-aware View Picks. The `HomeViewModel` and gap-detection heuristics use this field to prefer gendered item types (e.g., `Dress` vs `Suit`, `Pumps` vs `Dress Shoes`). If the field is missing or ambiguous, the system falls back to neutral categories.

- `hasProfile` (boolean)
  - Example: `true`
  - Usage: UI logic (complete profile check); not directly used for suggestions.

- `lastActive` (timestamp)
  - Example: `2026-02-02T04:45:54Z`
  - Usage: analytics/UI hints; not used for suggestion content.

- `measurements` (map)
  - Subfields (numbers):
    - `armLength`, `bodyWeight`, `chest`, `height`, `hips`, `inseam`, `shoeSize`, `shoulderWidth`, `waist`
  - Example: `"chest": 98, "height": 170`
  - Usage: Optional — when available, these values can be passed into AI prompts to generate better-fitting suggestions (e.g., recommending sizes or silhouettes). Current baseline heuristics do not require measurements, but AI prompts may include them for personalized phrasing.

- `selfie` (string)
  - Example: `https://firebasestorage.googleapis.com/.../users/user_email/selfie.jpg?alt=media&token=...`
  - Usage: Used as the base avatar for virtual try-on generation.

- `username` (string)
  - Example: `"TestUser"`
  - Usage: UI display and attribution; not used directly in view-picks generation.

Notes on View Picks generation
- Primary fields: `gender`, `avatarURL`/`selfie`, and `measurements` (if present) are valuable for tailoring suggestions.
- Flow summary (how Home uses Firestore fields):
  1. `HomeViewModel` loads the current user's `gender` at init (via `FirestoreManager.fetchUserGender`).
  2. When an upcoming calendar event is detected, the style-gap logic maps event keywords to required item categories and adjusts the required types by `gender`.
  3. If the closet lacks required items (via `FirestoreManager.fetchWardrobeCounts`), the AI-based `generateAIPicksURL` builds shopping/search phrases. The AI prompt may include `location`, `event`, and optionally `gender`/`measurements`/`avatar` URLs for better context.
  4. The generated phrases are converted into a Google search URL and surfaced as "View Picks" — opening the browser shows results tailored by the AI output.

Security & privacy
- Avoid embedding raw `selfie` or `avatarURL` binary content into third-party services. When sending these URLs to AI services, ensure your privacy policy and user consent cover such usage.
- Provide an opt-out in settings if users don't want their profile or measurements used for AI suggestions.

File: docs/firestore_user_fields.md
