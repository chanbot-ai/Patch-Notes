# PatchNotes (iOS SwiftUI Prototype)

Sleeper-inspired iOS app prototype for video games, built in SwiftUI with a focus on high-density cards, feed-first layout, and glass-like native materials.

## What is implemented

- 5-tab architecture:
  - Home
  - Release Calendar
  - Social
  - My Games
  - Esports
- Shared `AppStore` with seeded mock data and cross-tab state:
  - Favoriting from Release Calendar auto-updates My Games and Social context.
- Release detail flow:
  - Tap any release card to see publisher/genre, review aggregates, similar games, and trending short-form video list.
- Social experience:
  - Game-scoped thread feed with "hot" labeling and interaction metrics.
- Esports odds UI:
  - Market cards and outcome pricing from mock data, designed to swap in real APIs later.
- Native UI styling:
  - `ultraThinMaterial` glass cards, layered gradients, rounded typography, and card motion transitions.

## Open in Xcode

1. Open `/Users/clowrance/Documents/PatchNotesv1/PatchNotes.xcodeproj`.
2. Select an iOS simulator.
3. Build and run the `PatchNotes` target.

## Planned integration phases

1. Data ingestion layer
   - Video game releases/news from provider APIs.
   - Creator short-video indexing and ranking.
2. Account + identity
   - Sign in, profile, and Steam OAuth sync.
3. Monetization
   - Ads system, premium ad-free subscription, and feature gating.
4. Payments and compliance
   - Subscription billing and regional policy controls.
5. Esports trading integration
   - Read/write connectivity to Polymarket/Kalshi with account linking.

