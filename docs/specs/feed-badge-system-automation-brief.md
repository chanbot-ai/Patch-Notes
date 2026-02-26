# Feed Badge System Automation Brief (Swift-first, Two-Stage Gated)

## Purpose

Preserve the approved feed badge system decisions from the planning thread so a later automation run can implement the work without depending on chat context.

This brief is the source of truth for the automation task covering:

1. A Swift-first implementation spec pass
2. A Swift client scaffolding pass (gated on the spec artifact existing)

## Project Context

- Workspace: `/Users/chanlowran/Documents/Patch-Notes-v1`
- Platform direction: Swift-first (iOS/client). Do not use TypeScript snippets unless explicitly documenting backend-only examples.
- User wants free-form posting preserved. Posts must not require explicit game tagging.

## Approved Product Decision Summary

### Feed badge requirement

Every feed post must show a badge or visual indicator indicating what the post is about.

- If the post is about a specific game, show a game badge.
- Use the attached game badge example from the original thread as the visual reference baseline.
- If the attachment is unavailable in automation mode, proceed with a placeholder visual scaffold and document the blocker/TODO for final art matching.

### Free-form posting requirement

Users should be able to post about:

- Specific games
- Multiple games
- Esports
- Streamers/creators/public figures
- Studios/publishers/industry news
- Platforms/services/hardware
- Events/showcases/tournaments
- General gaming ecosystem topics

The system must not force users to select a game before posting.

## Approved Badge Taxonomy (v1)

Primary badge categories:

- `game:<id>` (specific title badge, dynamic)
- `multi_game`
- `esports`
- `creator`
- `industry`
- `platform`
- `event`
- `general_gaming`
- `unspecified`

Notes:

- `game:<id>` is the hero tier but still within the shared badge system.
- `general_gaming` and `unspecified` are intentional fallbacks, not errors.

## Approved Primary Badge Decision Rules (v1)

1. Prefer a specific `game:<id>` badge when there is a clear, high-confidence single-game signal.
2. Use `multi_game` when multiple strong game candidates exist without a clear winner, or the post is clearly comparison/list/multi-title focused.
3. If no valid game result, assign the highest-confidence category (`esports`, `creator`, `industry`, `platform`, `event`) when confidence is strong enough.
4. If gaming-related signals exist but are weak/unclear, use `general_gaming`.
5. If there are no usable signals, use `unspecified`.

## Approved Assignment Precedence (highest wins)

- `user`
- `composer_context`
- `attachment`
- `text_rules`
- `link_metadata`
- `async_enrichment`

Critical rule:

- `user_overridden` assignments must not be overwritten by async enrichment.

## Approved Reclassification / Churn Rules

Allowed upgrade paths:

- `unspecified` -> category
- `general_gaming` -> category
- category -> `game:<id>` (when confidence is strong)

Churn controls:

- Prefer broad correct category over wrong game assignment
- Do not downgrade a game badge automatically after assignment (except moderator/admin correction)
- Avoid category flip-flopping unless confidence improvement is materially better

## Approved Badge Style System Direction (v1)

### Shared system

- Shared badge framework: icon + label + frame
- Category uniqueness should come from shape language, icon motif, and color family (not color alone)
- Game badges are visually richer but fit within a consistent outer frame system

### Feed sizing/anatomy

- Feed badge height around `24px` desktop (`22px` mobile acceptable)
- Compact layout defaults to icon + short label
- Category compact labels are short uppercase abbreviations
- Game labels use title case or curated short aliases/monograms

### Visual intent per category (high-level)

- `multi_game`: split/stacked visual motif
- `esports`: angular/competitive motif (brackets/trophy/versus)
- `creator`: broadcast/media motif
- `industry`: structured/business/studio motif
- `platform`: tech/platform motif
- `event`: ticket/stage/showcase motif
- `general_gaming`: broad gaming/controller motif
- `unspecified`: neutral intentional fallback motif

### Accessibility requirements

- Do not rely on color alone
- Preserve readable text contrast
- Icon-only badges require accessible labels/tooltips

## Approved Badge Content Spec (implementation requirements)

Required display variants:

- `feedCompact`
- `feedFull`
- `filterChip`
- `detailBadge`
- `iconOnly` (a11y label required)

Category labels (approved abbreviations/labels):

- `multi_game`: `MULTI`, `Multi-Game`
- `esports`: `ESP`, `Esports`
- `creator`: `CRT`, `Creator`
- `industry`: `IND`, `Industry`
- `platform`: `PLT`, `Platform`
- `event`: `EVT`, `Event`
- `general_gaming`: `GEN`, `Gaming` (compact/full UI labels), `General Gaming` in filters/detail
- `unspecified`: `UNSP` / `Unspec` / `Unspecified`

Dynamic game badge requirements:

- Key format: `game:<gameId>`
- Support curated short aliases/monograms for compact labels
- Preserve official titles for detail labels/a11y
- Use shared naming convention for icon IDs (category custom family + dynamic game badge IDs)

## Approved Topic Detection / Confidence Mapping (spec-level)

This is still spec/design work, not an ML implementation task.

### Output expectations

Assignment output should carry:

- primary badge key
- optional secondary badge key (detail view only; e.g., `esports`, `event`)
- confidence
- source
- status
- detected entities (games + categories with scores)

### Confidence behavior (v1)

- High confidence: assign specific game or strong category
- Medium confidence: prefer category fallback
- Low confidence but gaming signal present: `general_gaming`
- Very low/no signal: `unspecified`

### Ambiguity handling

- Maintain ambiguous alias handling (example collisions like short acronyms/common words)
- Require corroborating evidence before assigning a specific game when alias ambiguity is high
- Prefer category or fallback over guessing wrong game

## Swift-first Requirement (important)

All typed examples and client-facing contracts in the spec/scaffold should be written in Swift by default:

- `enum`
- `struct`
- `Codable`

Language-agnostic JSON payloads are allowed for backend API/schema sections, but include matching Swift request/response models.

Do not use TypeScript snippets unless a backend-only comparison is explicitly necessary (not expected for this task).

## Two-Stage Gated Automation Work

### Stage 1: Spec Pass (Swift-first, no production code changes)

Create:

- `/Users/chanlowran/Documents/Patch-Notes-v1/docs/specs/feed-badge-system-implementation-spec.md`

The spec must include:

1. Swift models (`enum`/`struct`/`Codable`) for:
   - taxonomy/categories
   - badge content spec
   - topic assignment output
   - confidence/source/status enums
   - manual override model
   - async reclassification event model
2. Approved taxonomy and fallback logic
3. Assignment precedence and `user_overridden` protection
4. Data schema for:
   - current badge assignments
   - confidence/source/status metadata
   - manual overrides
   - async reclassification events
   - audit/event logging
5. Backend-facing API/RPC contract:
   - create/read assignment
   - manual override submit/update
   - async reclassification apply/write
   - feed/detail assignment fetch
6. JSON payload shapes + matching Swift request/response models
7. Badge content spec variants (`feedCompact`, `feedFull`, `filterChip`, `detailBadge`, `iconOnly`)
8. Assumptions, non-goals, rollout order, open questions

### Stage 1 Gate (must pass before Stage 2)

Do not start Stage 2 unless:

- `/Users/chanlowran/Documents/Patch-Notes-v1/docs/specs/feed-badge-system-implementation-spec.md` exists
- It covers all major sections (Swift models, taxonomy/fallback logic, data schema, API/RPC contract, override/reclassification rules)

If gate fails:

- Stop
- Report blocker(s)
- Do not scaffold code

### Stage 2: Client Scaffolding Pass (Swift-first, incremental)

Read Stage 1 spec and implement a first-pass client scaffold (not full backend integration):

1. Swift `Codable` models for badge system entities and assignment data
2. Badge key parsing/validation:
   - category keys
   - `game:<id>`
   - graceful fallback to `unspecified`
3. Badge content spec in Swift for all approved categories/variants
4. Reusable SwiftUI badge component scaffold supporting:
   - feed compact
   - feed full
   - filter chip
   - detail badge
   - icon-only
5. Lightweight visual token/styling scaffold (with TODOs for final art assets)
6. Previews/demo showing categories + fallbacks + sample games
7. Focused unit tests:
   - badge key parsing
   - label lookup
   - fallback behavior
   - optional Codable round-trip tests

Create notes:

- `/Users/chanlowran/Documents/Patch-Notes-v1/docs/specs/feed-badge-system-scaffold-notes.md`

## Non-Goals (current automation scope)

- No production ML/NLP topic detection implementation
- No broad feed UI redesign
- No final custom badge art delivery
- No full backend integration unless trivial and already aligned with existing code structure

## Deliverable Expectations for Automation Response

The automation run should summarize:

- Whether Stage 1 passed gate
- Whether Stage 2 ran
- Files created/updated
- What is fully implemented vs scaffold/TODO
- Blockers/open questions

## Implementation Quality Notes

- Preserve existing user changes; avoid unrelated modifications
- Keep changes incremental and reviewable
- Prefer project structure/style conventions if discoverable; otherwise create a coherent `Feed/Badges` grouping and document the choice

