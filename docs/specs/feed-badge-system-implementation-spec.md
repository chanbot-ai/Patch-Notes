# Feed Badge System Implementation Spec (Swift-first, v1)

## Status

- Stage: Stage 1 spec artifact for gated automation flow
- Scope: Swift-first client contract + backend-facing schema/API design for feed badge assignment
- Non-goal: production topic detection/ML implementation

## Goals

- Add a shared badge system that always renders a feed badge/indicator for every post.
- Preserve free-form posting (no required game tagging in composer).
- Standardize assignment metadata, override rules, and async reclassification behavior.
- Define Swift-first typed contracts (`enum` / `struct` / `Codable`) plus JSON payload shapes.

## Approved Taxonomy And Fallback Logic (v1)

### Primary badge keys

- Dynamic game badge: `game:<id>`
- Category badges:
  - `multi_game`
  - `esports`
  - `creator`
  - `industry`
  - `platform`
  - `event`
  - `general_gaming`
  - `unspecified`

### Primary assignment rules

1. Prefer `game:<id>` when there is a clear, high-confidence single game signal.
2. Use `multi_game` when multiple strong game candidates exist without a clear winner or the post is clearly multi-title.
3. If no valid game result, use the strongest non-game category (`esports`, `creator`, `industry`, `platform`, `event`) when confidence is strong.
4. If gaming-related signal exists but is weak/unclear, use `general_gaming`.
5. If no usable signal exists, use `unspecified`.

### Reclassification / churn controls

Allowed upgrades:

- `unspecified` -> category
- `general_gaming` -> category
- category -> `game:<id>`

Protections:

- Prefer broad correct category over wrong game badge.
- Do not auto-downgrade an assigned game badge (except moderator/admin correction).
- Avoid category flip-flopping without material confidence improvement.

## Assignment Precedence And Override Protection

### Precedence (highest wins)

1. `user`
2. `composer_context`
3. `attachment`
4. `text_rules`
5. `link_metadata`
6. `async_enrichment`

### Critical override rule

Assignments with status `user_overridden` MUST NOT be overwritten by `async_enrichment`.

Implementation implication:

- Async reclassification writes must validate the current assignment status before mutating state.
- Rejected async writes should be logged as no-op audit events with reason `blocked_user_override`.

## Swift Models (Client-facing + Shared Contract)

### Core badge keys / taxonomy

```swift
import Foundation

struct FeedBadgeGameKey: Codable, Hashable, Equatable {
    let gameID: String

    var rawKey: String { "game:\(gameID)" }
}

enum FeedBadgeCategoryKey: String, Codable, CaseIterable, Hashable {
    case multiGame = "multi_game"
    case esports
    case creator
    case industry
    case platform
    case event
    case generalGaming = "general_gaming"
    case unspecified
}

enum FeedBadgeKey: Codable, Hashable, Equatable {
    case game(FeedBadgeGameKey)
    case category(FeedBadgeCategoryKey)

    var rawKey: String {
        switch self {
        case .game(let key):
            return key.rawKey
        case .category(let category):
            return category.rawValue
        }
    }
}
```

### Content spec / variants

```swift
enum FeedBadgeVariant: String, Codable, CaseIterable {
    case feedCompact
    case feedFull
    case filterChip
    case detailBadge
    case iconOnly
}

enum FeedBadgeIconID: String, Codable {
    case multiGameSplit
    case esportsBracket
    case creatorBroadcast
    case industryStudio
    case platformChip
    case eventTicket
    case generalGamingController
    case unspecifiedNeutral
    case gameControllerFrame
    case gameCustomArt // placeholder until final art pipeline is defined
}

struct FeedBadgeVariantContent: Codable, Equatable {
    let label: String
    let iconID: FeedBadgeIconID
    let accessibilityLabel: String
    let tooltip: String?
}

struct FeedBadgeContentSpec: Codable, Equatable {
    let badgeKey: String
    let variants: [FeedBadgeVariant: FeedBadgeVariantContent]
    let colorFamilyToken: String
    let shapeToken: String
    let frameToken: String
}
```

### Assignment output / confidence / source / status

```swift
enum FeedBadgeConfidenceTier: String, Codable {
    case high
    case medium
    case low
    case none
}

enum FeedBadgeAssignmentSource: String, Codable, CaseIterable {
    case user
    case composerContext = "composer_context"
    case attachment
    case textRules = "text_rules"
    case linkMetadata = "link_metadata"
    case asyncEnrichment = "async_enrichment"
}

enum FeedBadgeAssignmentStatus: String, Codable {
    case assigned
    case userOverridden = "user_overridden"
    case pendingEnrichment = "pending_enrichment"
    case superseded
    case rejected
}

struct FeedBadgeScoredEntity: Codable, Equatable, Hashable {
    enum EntityKind: String, Codable {
        case game
        case esports
        case creator
        case industry
        case platform
        case event
        case generalGaming = "general_gaming"
    }

    let kind: EntityKind
    let key: String
    let displayName: String
    let score: Double
    let metadata: [String: String]?
}

struct FeedBadgeTopicAssignmentOutput: Codable, Equatable {
    let primaryBadgeKey: String
    let secondaryBadgeKey: String?
    let confidence: FeedBadgeConfidenceTier
    let confidenceScore: Double
    let source: FeedBadgeAssignmentSource
    let status: FeedBadgeAssignmentStatus
    let detectedEntities: [FeedBadgeScoredEntity]
    let assignedAt: Date
    let rationale: String?
}
```

### Manual override model

```swift
struct FeedBadgeManualOverride: Codable, Equatable, Identifiable {
    let id: UUID
    let postID: UUID
    let previousPrimaryBadgeKey: String?
    let newPrimaryBadgeKey: String
    let secondaryBadgeKey: String?
    let actorUserID: UUID
    let reasonCode: String
    let notes: String?
    let createdAt: Date
}
```

### Async reclassification event model

```swift
struct FeedBadgeAsyncReclassificationEvent: Codable, Equatable, Identifiable {
    enum Outcome: String, Codable {
        case applied
        case skippedNoImprovement = "skipped_no_improvement"
        case blockedUserOverride = "blocked_user_override"
        case rejectedInvalidPayload = "rejected_invalid_payload"
    }

    let id: UUID
    let postID: UUID
    let candidate: FeedBadgeTopicAssignmentOutput
    let previousPrimaryBadgeKey: String?
    let outcome: Outcome
    let evaluationReason: String
    let createdAt: Date
    let processedAt: Date?
}
```

## Badge Content Spec Requirements (Variants + Labels)

### Required variants

- `feedCompact`
- `feedFull`
- `filterChip`
- `detailBadge`
- `iconOnly` (must have a11y label)

### Approved category labels

| Key | Compact | Feed Full | Filter/Detail |
| --- | --- | --- | --- |
| `multi_game` | `MULTI` | `Multi-Game` | `Multi-Game` |
| `esports` | `ESP` | `Esports` | `Esports` |
| `creator` | `CRT` | `Creator` | `Creator` |
| `industry` | `IND` | `Industry` | `Industry` |
| `platform` | `PLT` | `Platform` | `Platform` |
| `event` | `EVT` | `Event` | `Event` |
| `general_gaming` | `GEN` | `Gaming` | `General Gaming` |
| `unspecified` | `UNSP` / `Unspec` | `Unspec` | `Unspecified` |

### Dynamic game badge requirements

- Key format: `game:<gameId>`
- Support curated compact aliases / monograms
- Preserve official title for detail labels and accessibility
- Use shared frame + token system; richer art is optional and can be placeholder-scaffolded

## Data Schema (Backend / Persistence)

This section defines persistence shape; actual SQL migrations are out of scope for this automation run.

### 1) Current badge assignments (`post_badge_assignments`)

Purpose: source of truth for the current effective badge displayed in feed/detail.

Suggested columns:

- `post_id` (UUID, PK / FK posts.id)
- `primary_badge_key` (TEXT, not null)
- `secondary_badge_key` (TEXT, nullable)
- `confidence_tier` (TEXT, not null)
- `confidence_score` (NUMERIC, nullable)
- `source` (TEXT, not null)
- `status` (TEXT, not null)
- `assigned_at` (TIMESTAMPTZ, not null default now())
- `updated_at` (TIMESTAMPTZ, not null default now())
- `detected_entities_json` (JSONB, not null default `[]`)
- `rationale` (TEXT, nullable)
- `version` (INT, not null default 1)

Indexes:

- `post_id` PK
- `primary_badge_key`
- `status`
- `source`

### 2) Manual overrides (`post_badge_manual_overrides`)

Purpose: immutable record of user/moderator/admin overrides.

Suggested columns:

- `id` (UUID, PK)
- `post_id` (UUID, FK)
- `previous_primary_badge_key` (TEXT, nullable)
- `new_primary_badge_key` (TEXT, not null)
- `secondary_badge_key` (TEXT, nullable)
- `actor_user_id` (UUID, FK)
- `reason_code` (TEXT, not null)
- `notes` (TEXT, nullable)
- `created_at` (TIMESTAMPTZ, not null default now())

Indexes:

- `(post_id, created_at desc)`
- `actor_user_id`

### 3) Async reclassification events (`post_badge_reclassification_events`)

Purpose: candidate assignments + application outcomes from enrichment pipeline.

Suggested columns:

- `id` (UUID, PK)
- `post_id` (UUID, FK)
- `candidate_assignment_json` (JSONB, not null)
- `previous_primary_badge_key` (TEXT, nullable)
- `outcome` (TEXT, not null)
- `evaluation_reason` (TEXT, not null)
- `created_at` (TIMESTAMPTZ, not null default now())
- `processed_at` (TIMESTAMPTZ, nullable)

Indexes:

- `(post_id, created_at desc)`
- `outcome`

### 4) Audit/event logging (`badge_assignment_audit_log`)

Purpose: operational trace for writes / rejections / overrides.

Suggested columns:

- `id` (UUID, PK)
- `post_id` (UUID, FK)
- `event_type` (TEXT, not null) // `create`, `update`, `override`, `reclassify_attempt`, `reclassify_blocked`, etc.
- `actor_type` (TEXT, not null) // `user`, `system`, `moderator`, `admin`
- `actor_id` (UUID, nullable)
- `payload_json` (JSONB, not null)
- `created_at` (TIMESTAMPTZ, not null default now())

## Backend-facing API / RPC Contract (v1)

The app can start with REST or Supabase RPC wrappers. The contract below is transport-agnostic and includes JSON + Swift models.

### Endpoints / operations

1. Create or upsert assignment (`POST /v1/posts/{postId}/badge-assignment`)
2. Read current assignment (`GET /v1/posts/{postId}/badge-assignment`)
3. Submit manual override (`POST /v1/posts/{postId}/badge-assignment/override`)
4. Update existing manual override metadata (`PATCH /v1/badge-overrides/{overrideId}`) if policy allows
5. Apply async reclassification (`POST /v1/posts/{postId}/badge-assignment/reclassify`)
6. Feed batch fetch (`POST /v1/feed/badge-assignments:batchGet`)
7. Detail fetch (`GET /v1/posts/{postId}/badge-assignment/detail`)

### Shared Swift request/response models

```swift
struct FeedBadgeAssignmentRecord: Codable, Equatable {
    let postID: UUID
    let assignment: FeedBadgeTopicAssignmentOutput
    let secondaryBadgeKey: String?
    let version: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case assignment
        case secondaryBadgeKey = "secondary_badge_key"
        case version
        case updatedAt = "updated_at"
    }
}

struct CreateFeedBadgeAssignmentRequest: Codable {
    let postID: UUID
    let primaryBadgeKey: String
    let secondaryBadgeKey: String?
    let confidence: FeedBadgeConfidenceTier
    let confidenceScore: Double?
    let source: FeedBadgeAssignmentSource
    let status: FeedBadgeAssignmentStatus
    let detectedEntities: [FeedBadgeScoredEntity]
    let rationale: String?

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case primaryBadgeKey = "primary_badge_key"
        case secondaryBadgeKey = "secondary_badge_key"
        case confidence = "confidence_tier"
        case confidenceScore = "confidence_score"
        case source
        case status
        case detectedEntities = "detected_entities"
        case rationale
    }
}

struct FeedBadgeAssignmentResponse: Codable {
    let record: FeedBadgeAssignmentRecord
}

struct SubmitFeedBadgeManualOverrideRequest: Codable {
    let postID: UUID
    let newPrimaryBadgeKey: String
    let secondaryBadgeKey: String?
    let actorUserID: UUID
    let reasonCode: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case newPrimaryBadgeKey = "new_primary_badge_key"
        case secondaryBadgeKey = "secondary_badge_key"
        case actorUserID = "actor_user_id"
        case reasonCode = "reason_code"
        case notes
    }
}

struct FeedBadgeManualOverrideResponse: Codable {
    let override: FeedBadgeManualOverride
    let updatedAssignment: FeedBadgeAssignmentRecord
}

struct ApplyAsyncReclassificationRequest: Codable {
    let postID: UUID
    let candidate: FeedBadgeTopicAssignmentOutput

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case candidate
    }
}

struct ApplyAsyncReclassificationResponse: Codable {
    let event: FeedBadgeAsyncReclassificationEvent
    let updatedAssignment: FeedBadgeAssignmentRecord?
}

struct FeedBadgeBatchGetRequest: Codable {
    let postIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case postIDs = "post_ids"
    }
}

struct FeedBadgeBatchGetResponse: Codable {
    let assignments: [FeedBadgeAssignmentRecord]
    let missingPostIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case assignments
        case missingPostIDs = "missing_post_ids"
    }
}
```

### JSON payload shapes (examples)

#### Create / upsert assignment request

```json
{
  "post_id": "0E4CB4CB-91B6-4A95-B20D-3D1F091C1123",
  "primary_badge_key": "game:elden-ring",
  "secondary_badge_key": "event",
  "confidence_tier": "high",
  "confidence_score": 0.94,
  "source": "text_rules",
  "status": "assigned",
  "detected_entities": [
    {
      "kind": "game",
      "key": "game:elden-ring",
      "displayName": "Elden Ring",
      "score": 0.94,
      "metadata": {
        "alias_match": "elden"
      }
    },
    {
      "kind": "event",
      "key": "event",
      "displayName": "Showcase",
      "score": 0.58,
      "metadata": null
    }
  ],
  "rationale": "Single high-confidence game mention with supporting title tokens."
}
```

#### Manual override request

```json
{
  "post_id": "0E4CB4CB-91B6-4A95-B20D-3D1F091C1123",
  "new_primary_badge_key": "multi_game",
  "secondary_badge_key": null,
  "actor_user_id": "8AA3B426-9BDE-4B2C-AEAD-B16AA720D9A0",
  "reason_code": "user_corrected_scope",
  "notes": "This post compares multiple Souls titles."
}
```

#### Async reclassification apply request

```json
{
  "post_id": "0E4CB4CB-91B6-4A95-B20D-3D1F091C1123",
  "candidate": {
    "primaryBadgeKey": "game:elden-ring",
    "secondaryBadgeKey": null,
    "confidence": "high",
    "confidenceScore": 0.97,
    "source": "async_enrichment",
    "status": "assigned",
    "detectedEntities": [],
    "assignedAt": "2026-02-26T10:00:00Z",
    "rationale": "Enrichment resolved ambiguous alias using link metadata."
  }
}
```

Notes:

- API JSON may use snake_case while Swift models can map via `CodingKeys`.
- `FeedBadgeTopicAssignmentOutput` is shared between local client state and request payloads; transport adapters may wrap/rename fields as needed.

## Override / Reclassification Rules (Normative Behavior)

### Manual override behavior

- Manual override updates current assignment status to `user_overridden`.
- Override event is appended to `post_badge_manual_overrides`.
- Audit event is recorded.
- Existing async pending events remain historical only; they do not mutate current state.

### Async reclassification behavior

1. Load current `post_badge_assignments` row.
2. If current status is `user_overridden`, reject apply and write event outcome `blocked_user_override`.
3. Validate candidate badge key format (`game:<id>` or approved category).
4. Compare against churn rules:
   - allow upgrade from `unspecified` / `general_gaming`
   - allow category -> `game:<id>` on material confidence improvement
   - avoid downgrading `game:<id>` automatically
5. If applied, update assignment row and set prior row status to `superseded` in audit semantics (or versioned update with incremented `version`).
6. Write audit log for attempt and result.

## Badge Rendering + Styling Direction (Client)

### Shared anatomy

- Outer frame + icon + label
- Category uniqueness via icon motif, shape language, and color family (not color alone)
- Game badges fit same outer frame system but can use richer fill/art

### Sizing targets

- Feed badge height target ~24px desktop equivalent, ~22px compact/mobile equivalent
- Compact layout favors icon + short label

### Accessibility

- Do not rely on color alone
- Maintain contrast for text and icon strokes/fills
- `iconOnly` must include accessibility label and tooltip/assistive description where supported

## Rollout Order (Recommended)

1. Ship client scaffold + local rendering with static/spec-driven content map
2. Add backend schema + APIs for current assignment reads/writes
3. Render badges in feed/detail using fallback `unspecified` when missing assignment
4. Add manual override UI flows (user/mod tools)
5. Add async enrichment pipeline integration with gated reclassification rules
6. Finalize badge art assets + category polish

## Assumptions

- Existing post records remain free-form and may have `game_id` absent.
- Badge assignment may be derived asynchronously and stored separately from `posts`.
- Supabase/Postgres is the backend persistence layer, but exact SQL migration names are not fixed in this spec.
- No final badge art assets are available in automation mode; placeholders are acceptable in scaffold stage.

## Non-Goals

- NLP/ML classifier implementation
- Composer UX redesign or required tagging flow
- Final art production pipeline
- Full backend implementation/migrations in this automation run

## Open Questions

1. Who can create manual overrides in v1 (author only vs moderator/admin roles)?
2. Should `secondaryBadgeKey` be persisted for feed only, or only generated for detail view on demand?
3. What confidence delta qualifies as “material improvement” for category flip or category -> game upgrade?
4. Should game badge IDs use internal UUIDs, slugs, or hybrid keys (`game:<uuid>` vs `game:<slug>`)?
5. Are badge labels localized in v1, or is English-only acceptable initially?
6. Should `unspecified` display be visually hidden in some feed contexts while still present for accessibility/logic?
