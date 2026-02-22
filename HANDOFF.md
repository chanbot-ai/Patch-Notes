# Patch Notes iOS App Handoff

## Repo / Branch
- GitHub repo: `https://github.com/chanbot-ai/Patch-Notes`
- Default branch: `main`
- Local branch: `main` tracking `origin/main`
- Latest pushed commit before this handoff file: `81a1fd9` (`Initial Patch Notes iOS app prototype`)

## Project Goal
Build an iOS app (Swift + Xcode + native-first UI) that is to video games what Sleeper is to sports:
- Home feed for game news + short-form video
- Release calendar with deep game detail pages
- Social threads per game (Reddit/X hybrid)
- My Games library + favorited releases
- Esports scores/markets UI (prediction market style, no real wagering flow yet)

## Current App Status (Implemented)

### Global / App Shell
- 5-tab bottom nav: Home / Release Calendar / Social / My Games / Esports
- Persistent settings gear with sheet (account, accessibility toggles, appearance, membership placeholder, legal)
- Dark-first theme styling (reduced bright white UI)
- Personalized home header (`<User Name>'s Daily Pulse`)
- App icon + PN branding pass + launch animation (basic)

### Home
- Curated news cards
- Vertical video feed cards (short-form style)
- In-app inline video playback using `WKWebView` embeds (YouTube chosen as easiest reliable path)
- Per-video social discussion sheet:
  - emoji reactions (animated, selected-state color, counts)
  - nested reply chains

### Release Calendar
- Month pager with:
  - previous/next arrows
  - `Today` button
  - cleaner month header
- Full month grid with blocky day cells
- Clickable days and release detail cards below
- Calendar day cell typography tuned for readability
- Long-title logic (`> 14` chars) adjusts font scaling behavior

### Game Release Detail
- Detail page with:
  - image carousel
  - metadata / review aggregate
  - similar games
  - trending videos
- Similar games UI tightened to consistent row spacing (replaced overly spaced chip grid)

### Social
- Per-game community feed
- Mixed thread types:
  - text
  - photo
  - video
- Media previews in thread cards
- Thread detail pages render inline media (photo/video)
- Nested replies + emoji reaction interactions
- X/Tweet-style "X Pulse" feed cards with native discussion detail

### My Games
- "Your Library" and "Favorited Releases" sections separated into distinct containers
- Tile overlap/spacing issues improved
- Cover art backgrounds on owned game tiles
- Taps open detailed game pages (same detail view as releases)

### Esports
- Dark Sleeper-inspired score cards and odds/market UI structure
- Mocked esports scores + prediction market data layout
- User likes current structure; major UI changes intentionally limited recently

## Key Technical Decisions
- **Short-form video source**: YouTube links (Shorts/trailers) for in-app embed reliability.
- **Embedded playback**: `WKWebView` via reusable `EmbeddedVideoPlayer` in `PatchNotes/AppStyles.swift`.
- **Data layer**: Mock/seeded in-memory `AppStore` (`PatchNotes/Model/AppStore.swift`) to iterate UI quickly.
- **UI stack**: SwiftUI with shared theme styles (`GlassCard`, `SectionHeader`, theme colors, image helper).

## Important File Map
- App theme / shared components / media helpers:
  - `PatchNotes/AppStyles.swift`
- App seed data + store:
  - `PatchNotes/Model/AppStore.swift`
  - `PatchNotes/Model/Models.swift`
- Tabs / root:
  - `PatchNotes/RootTabView.swift`
  - `PatchNotes/PatchNotesApp.swift`
- Screens:
  - `PatchNotes/Views/HomeView.swift`
  - `PatchNotes/Views/ReleaseCalendarView.swift`
  - `PatchNotes/Views/SocialView.swift`
  - `PatchNotes/Views/MyGamesView.swift`
  - `PatchNotes/Views/EsportsView.swift`

## Known Issues / Follow-ups (Most Useful Next)
1. **Carousel images still need a truly robust source strategy**
   - We improved reliability by switching many screenshots to YouTube image CDN (`0.jpg`-`3.jpg`) and generating fallback variants.
   - Some games/trailers may still have weak/non-distinct secondary frames.
   - Best next step: move to a dedicated game media source (IGDB, RAWG, Steam capsules/screenshots, official press kits).

2. **`gh auth status` token weirdness in this environment**
   - `gh` login completed visually but sometimes reports token invalid in this shell.
   - Git pushes still succeeded using git credential flow.
   - On your new machine, just run `gh auth login` fresh.

3. **Real APIs not integrated yet**
   - Steam auth/library import
   - News/video ingestion backend
   - Esports odds APIs (Polymarket/Kalshi)
   - Auth/payments/ads/subscriptions

4. **Social backend is UI-only**
   - Reactions/replies are local state; no persistence yet.

## Build / Run Commands (New Machine)
Assumes Xcode is installed and Command Line Tools point to Xcode.

### Open in Xcode
```bash
cd Patch-Notes
open PatchNotes.xcodeproj
```

### CLI Build (Simulator)
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project PatchNotes.xcodeproj \
  -scheme PatchNotes \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PatchNotesDerived \
  CODE_SIGNING_ALLOWED=NO build
```

### Lint Xcode project file
```bash
plutil -lint PatchNotes.xcodeproj/project.pbxproj
```

### Simulator install/launch (example workflow)
```bash
xcrun simctl list devices
# install to a booted iPhone simulator using the correct UUID
xcrun simctl install <DEVICE_UUID> /tmp/PatchNotesDerived/Build/Products/Debug-iphonesimulator/PatchNotes.app
xcrun simctl launch <DEVICE_UUID> com.patchnotes.PatchNotes
```

## Git / Resume Workflow on New Machine
```bash
gh auth login -h github.com -p https -w
git clone https://github.com/chanbot-ai/Patch-Notes.git
cd Patch-Notes
```

## Resume Prompt (Use in Codex on New Machine)
Paste something like:

> Continue development of this SwiftUI iOS app from `HANDOFF.md`. Start by reading `HANDOFF.md`, then inspect `PatchNotes/Views/ReleaseCalendarView.swift` and `PatchNotes/Views/SocialView.swift`. Priorities: improve game detail carousel image reliability with a better source strategy, continue social/media polish, and preserve the current dark Sleeper-inspired aesthetic.

## Design Preferences to Preserve
- Dark mode / eye-friendly UI
- Sleeper-inspired energy and polish (but for gaming)
- Native-feeling interactions over web-ish patterns
- Keep esports page structure mostly intact unless requested
- Mixed-media social feed (text/photo/video) is a core differentiator

## Notes on Recent Fixes (for continuity)
- Calendar day title readability tuned with conditional long-title handling (`>14` chars)
- Similar games spacing normalized
- Release detail carousel now attempts stronger YouTube thumbnail variants for later slides
- Social threads support text/photo/video content types and inline media rendering
- Vertical videos play in-app and support their own reaction/reply thread UI
