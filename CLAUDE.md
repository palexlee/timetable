# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Two independent implementations of the same tool — a macOS menu bar app showing
live Swiss transit departures for one stop, from opentransportdata.swiss's OJP
(Open Journey Planner) API:

- `swiftbar_plugin/` — a Python [SwiftBar](https://swiftbar.app) plugin (the
  original, still-working version).
- `TransitETAApp/` — a native SwiftUI menu bar app (a from-scratch Swift port,
  styled after SBB's real departure boards) that replaces SwiftBar's plain-text
  dropdown with a real UI. Design rationale: `docs/superpowers/specs/2026-09-09-transit-eta-native-app-design.md`.

They are **not** layered on each other — the Swift app does not call the Python
code. Each has its own OJP HTTP client, XML parser, and models, deliberately
mirroring the other module-for-module so a fix discovered in one is easy to
port to the other (see "OJP API gotchas" below — several were found once,
live, against the real API, and had to be ported into both).

Both read/write **separate config files** so they never collide:
Python → `~/.config/transit-eta/config.json` (API key inline, chmod 600).
Swift → `~/.config/transit-eta/native-config.json` (API key in the Keychain
instead, service `local.transit-eta.app`).

## Commands

### Python plugin (`swiftbar_plugin/`)

```bash
./run_tests.sh                       # stdlib unittest, no network/API key needed
./install.sh                         # deploy to SwiftBar's Plugins folder
./install.sh /path/to/plugins        # ...or a custom folder
```

Single test: `PYTHONPATH="swiftbar_plugin" python3 -m unittest tests.test_ojp_client.ParseStopEventResponseTest.test_detects_delay -v`

No `pip install` — stdlib only (`urllib`, `xml.etree`, `json`), runs on
whatever `python3` macOS ships.

### Native app (`TransitETAApp/`)

```bash
cd TransitETAApp && xcodegen generate && cd ..     # regenerate .xcodeproj from project.yml after adding/removing files
bash TransitETAApp/run_tests.sh                    # xcodebuild test, all targets
```

Single test: `xcodebuild test -project TransitETAApp/TransitETAApp.xcodeproj -scheme TransitETAApp -destination 'platform=macOS' -only-testing:TransitETAAppTests/StopEventClientTests/testDetectsDelay`

Build manually: `xcodebuild build -project TransitETAApp/TransitETAApp.xcodeproj -scheme TransitETAApp -destination 'platform=macOS'`

**If `xcodebuild` fails with a Command Line Tools error**, full Xcode is
installed but not selected — prefix commands with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, or just open the
project in Xcode and run from there (doesn't need this).

**The `.xcodeproj` is committed, generated from `project.yml` (the source of
truth) via [XcodeGen](https://github.com/yonaskolb/XcodeGen).** Whenever a
Swift file is added or removed, `xcodegen generate` must be re-run and the
regenerated `TransitETAApp.xcodeproj` committed alongside — otherwise the new
file isn't in any build phase and silently isn't compiled (this has actually
happened mid-project: a commit shipped without its pbxproj update and only
worked because a later commit's regeneration happened to pick up the slack).

The test suite writes a temporary entry to the **login Keychain** during
`ConfigTests`/`AppModelTests` (service `local.transit-eta.tests`), cleaned up
by each class's `tearDown`.

To manually run/reinstall the built app outside Xcode:
```bash
pkill -x TransitETAApp
rm -rf /Applications/TransitETAApp.app
cp -R ~/Library/Developer/Xcode/DerivedData/TransitETAApp-*/Build/Products/Debug/TransitETAApp.app /Applications/
open /Applications/TransitETAApp.app
```

## Architecture: the module mapping

Both trees follow the identical layering; use this table to find the
equivalent file when porting a fix between them:

| Concern | Python | Swift |
|---|---|---|
| Endpoint/auth/timestamp/error formatting | `ojp_http.py` | `OJPHTTP.swift` |
| Namespace-tolerant XML tree walker | `xml_util.py` | `XMLTree.swift` (built on Foundation's `XMLDocument`, not hand-rolled) |
| Stop search (`OJPLocationInformationRequest`) | `location_client.py` | `LocationClient.swift` |
| Departures (`OJPStopEventRequest`) | `ojp_client.py` | `StopEventClient.swift` |
| Data models, mode→icon mapping | `models.py` | `Models.swift` (emoji → real SBB icon asset names) |
| Config persistence | `config.py` | `Config.swift` + `KeychainStore.swift` |
| Menu bar text/title logic | `render.py` | `Rendering.swift` (`menuBarState()`, pure/testable) + `AppModel.swift` (orchestration: timer, `@Published` state) |
| UI | SwiftBar's own plugin-format rendering | `Views/*.swift` (real SwiftUI) |

Every OJP request/response parser routes through the shared XML tree walker
(`xml_util.parse` / `XMLTree.parseXML`) specifically so that a non-XML
response body (an outage maintenance page, empty body, etc. — this happens
for real) raises a normal domain error instead of an uncaught parser
exception. The Swift `AppModel.refresh()` additionally guards every failure
path so it **never** throws — it polls on a 10s timer forever, so one bad
response must never take the loop down.

## OJP API gotchas (found live, against the real API — don't re-break these)

These are not obvious from reading the request-building code in isolation;
each is pinned by a test in both trees.

- **Departures must use `<StopPlaceRef>`, not `<StopPointRef>`.** The stop
  reference returned by location search is a StopPlace ref
  (`ch:1:sloid:7000`-style). Sending it as `<StopPointRef>` makes the live
  backend 500 ("ODMCH OJP Service Unavailable") instead of returning a clean
  error — confirmed live, only that one tag changed the response from 500 to
  200.
- **Line names: `PublishedLineName` isn't reliably sent.** The real API often
  omits it and sends `PublicCode` (e.g. `"IR"`) directly under `Service`
  instead. Fallback order matters: `PublishedLineName/Text` →
  `PublicCode` → `LineRef` → `"?"`.
- **A non-empty `User-Agent` header is required** — the gateway 403s requests
  with no `User-Agent`, which is Python's `urllib` default (not an issue in
  Swift's `URLSession`, but was a real bug in the Python client once).
- **Surface the HTTP error body, not just the status phrase** — `exc.reason`/
  the plain status code is uninformative; the body usually names the actual
  problem (invalid/expired key, wrong product subscription, quota). If that
  body is ever shown through a shell/AppleScript-based UI, escape it first —
  the Python plugin's AppleScript dialogs broke on unescaped quotes from a
  JSON error body until this was fixed.
- **`matchesPin()` needs Unicode-normalized comparison** (mode + line name +
  destination) — macOS can hand back accented text from a menu click as NFD
  while the API sends NFC, so raw `==` silently fails to match for any Swiss
  stop with an accent (Zürich, Genève, Rütihof, ...). In Python this is a
  real, necessary `unicodedata.normalize("NFC", ...)` call. In Swift it turns
  out to be unnecessary — `String ==` already does Unicode canonical-
  equivalence comparison natively — but the explicit normalization is kept
  anyway as harmless, documented defense-in-depth.
- **A pin is (mode, line, destination), not one specific trip** — several
  departures of the same line to the same destination at different times all
  match the same pin. `menuBarState()`/`AppModel` intentionally pick the
  *soonest* match (so the pin naturally advances as trips depart); UI code
  that highlights "the pinned row" must do the same soonest-match selection
  once and reuse it, not call `matchesPin` independently per row, or every
  matching row lights up at once.

## Swift/SwiftUI gotchas specific to this app

- **A computed property must not share a name with a free function it calls
  unqualified.** Swift's unqualified name lookup inside a type's own member
  favors that type's own same-named member over a module-scope function,
  even across a call-argument-label difference — and module-qualifying the
  call doesn't help if a type in the module also happens to share the
  module's name (the app's `@main` struct did, briefly). This is why
  `AppModel`'s title property is `menuBarLabelState`, not `menuBarState` (the
  free function in `Rendering.swift`).
- **`MenuBarExtra`'s label coerces its content to monochrome**, regardless of
  an individual `Image`'s `isTemplate` flag or a `Text`'s `.foregroundColor`
  — confirmed live twice (a colored `Text` run and, separately, a
  pre-rasterized colored `NSImage`, were both silently flattened to
  monochrome). Real color (line badges, delay-red) only renders reliably in
  the dropdown content, which is a normal SwiftUI view, not the status item
  itself. Achieving real color *in the menu bar title* would require
  managing a raw `NSStatusItem` directly instead of `MenuBarExtra` (how
  system icons like Siri's do it) — not attempted here.
- **A vector asset's `.resizable().frame()` isn't reliably respected inside
  `MenuBarExtra`'s label**, even though the identical modifier chain works
  correctly on the same assets in the dropdown. `MenuBarLabel.swift` works
  around this by forcing the underlying `NSImage`'s own `.size` before
  SwiftUI ever sees it, rather than relying on SwiftUI-level sizing.
- **`.sheet(isPresented:)` presented over `MenuBarExtra(.window)`'s borderless
  panel can leave the panel showing stale pixels after the sheet dismisses**,
  even though the SwiftUI state underneath already updated correctly
  (verified by direct instrumentation: the model update was always correct
  and immediate — the panel just didn't repaint). `StopSearchView` and
  `APIKeyEntryView` are therefore swapped in-place within `DeparturesView`'s
  own body (a three-way `if/else`), not presented as sheets.
- **A view that only calls methods on `AppModel` and never reads its
  `@Published` state should hold it as a plain `let`, not
  `@ObservedObject`.** Observing it reactively re-renders the whole view on
  every unrelated change — including the background 10s refresh timer, which
  can land mid-tap and drop the gesture. `StopSearchView`/`APIKeyEntryView`
  do this; `DeparturesView` legitimately needs `@ObservedObject` since it
  displays `events`/`errorMessage` directly.
- **`nextDepartures(config:)` reads `config.stopRef` synchronously before its
  network `await`**, so a request already in flight when the user changes
  stops is still for the *old* stop. `AppModel.refresh()` guards against the
  stale response arriving after a newer refresh with a monotonic generation
  counter — only the most recently *started* refresh is allowed to apply its
  result.
- **A static-analysis/SourceKit pass over this project reports many false
  "cannot find type/symbol in scope" diagnostics** for symbols that are
  genuinely defined in sibling files of the same Xcode target (confirmed
  repeatedly: `xcodebuild build`/`test` succeeds while the live diagnostics
  panel still complains). This is stale cross-file indexing, not a real
  compile error — verify against an actual `xcodebuild` run, not the
  diagnostics panel, before trusting a "cannot find in scope" report on this
  project.
