# Feed Badge System Scaffold Notes (Stage 2)

## Stage Gate Result

- Stage 1 spec artifact exists: `docs/specs/feed-badge-system-implementation-spec.md`
- Gate coverage verified for required sections:
  - Swift models
  - taxonomy/fallback logic
  - data schema
  - API/RPC contract
  - override/reclassification rules
- Stage 2 execution: Proceeded

## Files Created / Updated

### Created

- `PatchNotes/Feed/Badges/FeedBadgeModels.swift`
- `PatchNotes/Feed/Badges/FeedBadgeStyle.swift`
- `PatchNotes/Feed/Badges/FeedBadgeView.swift`
- `PatchNotesTests/FeedBadgeSystemTests.swift` (test scaffold file only; no test target wired yet)
- `docs/specs/feed-badge-system-implementation-spec.md`
- `docs/specs/feed-badge-system-scaffold-notes.md`

### Updated

- `PatchNotes.xcodeproj/project.pbxproj` (adds `PatchNotes/Feed/Badges/*` files to app target + groups)

## What Is Implemented (Working Scaffold)

### 1) Swift Codable models and enums

Implemented in `FeedBadgeModels.swift`:

- `FeedBadgeKey` raw key wrapper with normalization/fallback
- `FeedBadgeCategory` taxonomy enum (approved categories)
- `FeedBadgeVariant` enum (`feedCompact`, `feedFull`, `filterChip`, `detailBadge`, `iconOnly`)
- Assignment metadata enums:
  - `FeedBadgeConfidenceTier`
  - `FeedBadgeAssignmentSource`
  - `FeedBadgeAssignmentStatus`
- `FeedBadgeDetectedEntity`
- `FeedBadgeAssignment` (`Codable`) with snake_case mapping
- `FeedBadgeVariantContent` / `FeedBadgeContentSpec`

### 2) Badge key parsing / validation + fallback

Implemented behavior:

- Accepts approved category keys
- Accepts `game:<id>` keys with non-empty ID
- Invalid/empty keys normalize to `unspecified`
- Provides helpers for `category`, `gameID`, `isGame`, `isFallback`

### 3) Badge content spec in Swift (all approved categories / all variants)

Implemented via `FeedBadgeContentRegistry` + `FeedBadgeLabels`:

- Content generated for every required variant
- Approved compact/full/detail labels applied for category badges
- Dynamic game badge content generation with optional title + compact alias
- Symbol placeholders use SF Symbols for now

### 4) Reusable SwiftUI badge component scaffold

Implemented in `FeedBadgeView.swift`:

- Single `FeedBadgeView` supports all required variants
- Shared rendering frame + icon + label anatomy
- `iconOnly` a11y label/hint included
- Variant sizing/corner radius via style tokens

### 5) Lightweight visual token/styling scaffold

Implemented in `FeedBadgeStyle.swift`:

- Tokenized color palettes by category/game/fallback
- Variant sizing and corner radius helpers
- Explicit TODO for final custom badge art assets

### 6) Previews / demos

Implemented in `FeedBadgeView.swift`:

- `FeedBadgeDemoGallery` preview samples category badges, fallbacks, and a game badge
- Includes invalid-key fallback sample to `unspecified`

## What Is Scaffolded / TODO (Not Fully Implemented)

- Final category/game badge art and shape language matching the original visual reference (placeholders only)
- Backend integration for assignment fetch/write/manual override/reclassification APIs
- Persistence schema/migrations and Supabase RPC implementation
- Feed/detail UI integration into existing `FeedView` / post rows
- Secondary badge rendering policy (detail-only) and actual data plumbing
- Churn/upgrade rule evaluator logic for async reclassification decisions
- Localization strategy for badge labels

## Tests

### Implemented (scaffolded test file)

`PatchNotesTests/FeedBadgeSystemTests.swift` includes focused XCTest cases for:

- category key parsing
- `game:<id>` parsing
- invalid key fallback to `unspecified`
- approved label lookup (`GEN`, `MULTI`)
- content registry lookup for icon-only/accessibility labels
- `Codable` round-trip for `FeedBadgeAssignment`

### Blocker

- The project currently has no XCTest target configured in `PatchNotes.xcodeproj`.
- Test file was created as a ready-to-wire scaffold but is not compiled/executed yet.

## Verification Performed

- Stage 1 gate checks via file existence + section grep: passed
- `swiftc -typecheck` on new badge scaffold files: passed
- `xcodebuild` full project build: blocked by sandbox cache/package resolution permission errors (SwiftPM / module cache path under user cache directories)

## Open Questions / Decisions Needed

1. Should `game:<id>` use slugs (current scaffold examples) or canonical UUIDs for production keys?
2. Should the first integration target be feed row chips only, or both feed row + detail header in same PR?
3. Should we add a dedicated `PatchNotesTests` target now, or defer until more unit-testable modules are extracted?
4. What is the source of truth for game aliases/monograms used in compact labels?
