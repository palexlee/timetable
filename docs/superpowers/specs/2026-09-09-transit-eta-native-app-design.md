# Transit ETA: native SwiftUI menu bar app

Status: approved (architecture + visual design)
Date: 2026-09-09

## Why

The current tool is a SwiftBar plugin (`swiftbar_plugin/`): a Python script whose
output SwiftBar renders as a plain native `NSMenu`. That's a hard ceiling — a
plain menu can't reproduce SBB's visual language (typography, spacing, real
mode icons, brand color coding), because it isn't a view, it's text with a
tiny metadata DSL (`color=`, `font=`, `image=`).

This spec replaces the display layer with a small native macOS app so the
dropdown can be a real, fully custom SwiftUI view. `swiftbar_plugin/` is left
in place and untouched — this is a new, additive app, not a migration of the
existing code.

## Scope

Same feature set as the existing plugin, reskinned — no new features:

- Search a stop by name, pick from matches.
- Show the next 5 departures for the configured stop (line, destination, ETA,
  platform, delay).
- Pin one line+destination; the menu bar icon shows that pin's live ETA.
- Unpin; change stop; set/replace the API key.

## Decisions made during brainstorming

- **Full Swift rewrite**, not a Swift-UI-shell-over-Python-backend. One
  language, no IPC layer.
- **Ad-hoc/local signing only** — no Apple Developer account, no
  notarization. This is a personal tool run on your own Mac(s).
- **All-SwiftUI custom UI** — stop search, API key entry, and line pinning
  all become SwiftUI views inside the menu bar dropdown, not native
  `.alert`/`.sheet` dialogs bolted onto an otherwise plain menu.
- **Real SBB icons**, not "SBB-inspired" placeholders. Sourced from
  [`sbb-design-systems/sbb-icons`](https://github.com/sbb-design-systems/sbb-icons)
  (Apache-2.0, actively maintained). The SBB name/logo remains a trademark
  the app does not use as its own identity — only the transport-mode
  pictograms are pulled in.
- **Standard Xcode project**, not an SPM-only hand-bundled `.app`. Xcode owns
  entitlements, Info.plist, ad-hoc signing, and gives real
  debugging/previews — worth the one project file for a menu-bar app with
  actual SwiftUI layout to iterate on.

## Architecture

A new Xcode project, `TransitETAApp/`, at the repo root:

```
TransitETAApp/
  TransitETAApp.xcodeproj
  TransitETAApp/
    App.swift                # @main, MenuBarExtra(.window style)
    Models.swift              # StopEvent, StopMatch, TransitMode -> icon asset
    OJPHTTP.swift              # endpoint, auth header, timestamp, OjpError
    XMLTree.swift              # namespace-tolerant node walker (XMLDocument-based)
    LocationClient.swift       # OJPLocationInformationRequest (stop search)
    StopEventClient.swift      # OJPStopEventRequest (departures)
    Config.swift               # stop/pin JSON + API key in Keychain
    AppModel.swift             # ObservableObject: timer, published state, actions
    Views/
      MenuBarLabel.swift        # icon + line + destination + ETA (the title)
      DeparturesView.swift      # the dropdown's main content
      StopSearchView.swift
      APIKeyEntryView.swift
    Assets.xcassets/
      Icons/                    # imported SBB SVGs as template vector images
  TransitETAAppTests/
    LocationClientTests.swift
    StopEventClientTests.swift
    AppModelTests.swift         # matches_pin normalization, title formatting
    Fixtures/                   # the same XML fixtures used by the Python tests
```

Requires macOS 13 (Ventura)+ for `MenuBarExtra`.

Module-for-module, this mirrors the existing Python package
(`swiftbar_plugin/transit_eta/`), so porting is mechanical rather than a
redesign:

| Python | Swift |
|---|---|
| `ojp_http.py` | `OJPHTTP.swift` |
| `xml_util.py` | `XMLTree.swift` (built on Foundation's `XMLDocument`/`XMLElement` DOM API instead of a hand-rolled SAX tree) |
| `location_client.py` | `LocationClient.swift` |
| `ojp_client.py` | `StopEventClient.swift` |
| `models.py` | `Models.swift` (emoji → real icon asset names) |
| `config.py` | `Config.swift` (API key moves to Keychain, see below) |
| `transit-eta.10s.py` (entry point) | `App.swift` + `AppModel.swift` |
| `render.py` | `Views/*.swift` |

### Config and the Keychain change

Stop ref/name and the pin stay in a small JSON file (same shape as today).
The **API key moves to the macOS Keychain** instead of a chmod-600 JSON
file — a real security improvement, and close to free in Swift via the
`Security` framework. This is a deliberate behavior change from the existing
plugin, called out here since nothing in the current feature set asked for
it — it's the kind of improvement worth doing while the config layer is
already being rewritten, not because it was requested.

### Data flow

`AppModel` owns a repeating 10s `Timer` (replacing SwiftBar's poll interval)
that calls `StopEventClient.nextDepartures`, publishing either the events or
an error onto `@Published` properties the views observe directly. Pinning a
line is a **local state update** — the title updates instantly, rather than
waiting on SwiftBar's `refresh=true` subprocess round-trip as today.

### Error handling

Same categories the Python fixes already established: no API key, no stop
configured, HTTP/network failure, non-XML response body, pinned line not in
the next N departures. Every fetch is wrapped so a failure publishes an
error state instead of ever being allowed to crash the app or corrupt the
timer loop — carrying forward the "never crash the poll loop" discipline
from the recent Python bug fixes, just expressed as Swift's `do/catch`
instead of Python's `except`.

### Testing

Port the existing Python test suite's *cases* to XCTest, reusing the same
fixture XML files already validated against the live OJP API in this
session (not new assumed fixtures — that mismatch is exactly what caused
the `StopPlaceRef`/`PublicCode` bugs the Python version had). Covers: XML
parsing for both request types, `matches_pin`'s Unicode normalization,
title/ETA formatting, and the non-XML-body error path.

## Visual design

Mockups approved: https://claude.ai/code/artifact/9f6de602-b55a-4be6-b70c-7e3bb316bbbc
(4 screens: departures list, departures list with a line pinned, stop search,
API key entry.)

Design tokens established there, to carry into the SwiftUI implementation:

- **Colors**: SBB brand red `#EB0000` (line badges, delay text, pinned-row
  tint `#FDECEC`, primary button fill); ink `#1A1A1A` (primary text); muted
  ink `#8A8A8A` (secondary text, section labels); dividers `#E7E7E7`/`#EFEFEF`;
  field backgrounds `#F2F2F2`.
- **Typography**: Helvetica Neue (fallback Helvetica, Arial, sans-serif).
  Section labels are 10px, uppercase, 0.08em tracking, bold, muted ink —
  used as a Swiss-board-style "NEXT DEPARTURES" header rather than a plain
  list title.
- **Layout**: 320-360pt-wide popover card, 10pt corner radius, one drop
  shadow (`0 12px 28px rgba(0,0,0,.16)` at mockup scale) — no gradients, no
  left-border-accent cards. Each departure row: mode icon (24pt) · line name
  (bold) → destination (regular, truncates) on one line, platform + scheduled
  time (secondary, small) on a second line, ETA (bold, large) right-aligned
  with a red delay tag underneath when late.
- **Pinned state**: a full-row background tint (`#FDECEC`), not a border
  accent, plus a trailing red checkmark (`circle-tick`) icon — reads as a
  native list selection, not a decorative card.
- **Icons**: real SVGs from `sbb-design-systems/sbb-icons` (Apache-2.0),
  recolored via `currentColor` for tinting: `train-profile`, `tram-profile`,
  `bus-profile`, `underground-vehicule-profile`, `boat-profile`,
  `cable-car-profile`, `funicular-profile` for transport modes;
  `station-small` for the generic stop glyph; `magnifying-glass-small` for
  search; `key-small` for the API key field; `circle-tick-small` /
  `circle-cross-small` for pinned/unpin; `chevron-left-small` for back
  navigation; `platform-small` for the platform indicator. No icon exists in
  the set for "refresh" — the mockups use a small custom circular-arrow
  glyph in the same flat, filled style; port that same custom vector rather
  than searching for a nonexistent SBB one.

## Icons

SVGs pulled from `sbb-design-systems/sbb-icons`, one per OJP transport mode,
imported into the asset catalog as template (tintable) images:

| OJP `PtMode` | Icon |
|---|---|
| `rail`, `suburbanrail` | `train-profile-*.svg` |
| `tram` | `tram-profile-*.svg` |
| `bus`, `coach` | `bus-profile-*.svg` (or `long-distance-coach-profile-*.svg` for `coach`) |
| `metro`, `underground` | `underground-vehicule-profile-*.svg` |
| `water` | `boat-profile-*.svg` |
| `cableway` | `cable-car-profile-*.svg` |
| `funicular` | `funicular-profile-*.svg` |

## Out of scope (this spec)

- Multiple pinned/favorite stops, delay/cancellation styling, and the other
  README "next steps" items — explicitly deferred; this is a reskin, not a
  feature expansion.
- Notarized/distributable signing — ad-hoc only, for personal use.
