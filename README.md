# Transit ETA

A macOS menu bar tool that shows live bus/tram/train departures for one
Swiss stop, sourced from [opentransportdata.swiss](https://opentransportdata.swiss/fr/).

- Click the menu bar icon → **Search stop…** → type a stop name.
- The dropdown lists the next 5 departures through that stop (line,
  destination, ETA).
- Click one to pin it: the icon switches to that mode's glyph (🚆/🚌/🚊/…)
  and shows a compact live ETA, e.g. `🚆IC 1 4′`.

It's built as a [SwiftBar](https://swiftbar.app) plugin (a small Python
script), not a compiled app — no Xcode project, no code signing, easy to
read and modify.

## How it's built

```
swiftbar_plugin/
  transit-eta.10s.py     # the plugin SwiftBar runs (10s refresh interval)
  transit_eta/           # importable, unit-tested logic
    models.py             # StopEvent / StopMatch, mode -> emoji mapping
    xml_util.py           # namespace-tolerant XML tree walker
    ojp_http.py            # shared endpoint/auth/timestamp helpers
    ojp_client.py          # OJP StopEventRequest (next departures)
    location_client.py     # OJP LocationInformationRequest (stop search)
    config.py              # reads/writes ~/.config/transit-eta/config.json
    render.py              # builds the menu bar text SwiftBar displays
tests/                    # stdlib unittest, run with ./run_tests.sh
install.sh                # deploys the plugin (see note below on where things land)
```

Everything is stdlib-only Python (`urllib`, `xml.etree`, `json`) — no `pip
install` needed, which also means it runs on whatever `python3` macOS
already ships.

**Where install.sh actually puts things, and why:** SwiftBar scans its
whole Plugins folder (including subfolders) and tries to run *every* file
it finds as its own plugin. If `transit_eta/` were copied straight into
that folder, SwiftBar would also try to "run" each of its modules and fail
loudly on every one. So `install.sh` copies `transit_eta/` to a sibling
`TransitEtaLib` folder next to Plugins (never scanned) and rewrites
`transit-eta.10s.py`'s `TRANSIT_ETA_LIB_DIR` to point at it — only that one
script ends up inside the actual Plugins folder.

## ⚠️ Before you rely on this: verify the API details

This was written in a sandboxed environment with **outbound network access
to opentransportdata.swiss blocked**, so several details couldn't be
checked against the live docs while writing the first version. The auth
scheme is now confirmed straight from opentransportdata.swiss's own docs:
`Authorization: Bearer <key>` plus a non-empty `User-Agent` header (their
gateway 403s requests with no `User-Agent`, which is what Python's
`urllib` sends by default -- `auth_headers()` in `ojp_http.py` now sets
both). Still worth confirming against the portal once you have an
account, and adjusting if they've changed:

- `OJP_ENDPOINT` in `swiftbar_plugin/transit_eta/ojp_http.py`
- The response tag names in `_parse_stop_event()` (ojp_client.py) and
  `_parse_place_result()` (location_client.py), if a live request comes
  back with different tags than expected

All three are small, isolated spots — nothing else in the plugin needs to
change if the API details differ slightly.

## Setup

1. **Get an API key.** Register at
   [opentransportdata.swiss](https://opentransportdata.swiss/en/), then
   subscribe to the OJP product in their API Manager to get a key.

2. **Install SwiftBar** (menu bar plugin host):
   ```
   brew install --cask swiftbar
   ```
   On first launch it asks for a plugin folder — pick or create one, e.g.
   `~/Library/Application Support/SwiftBar/Plugins`.

3. **Install the plugin:**
   ```
   ./install.sh
   ```
   or pass your own plugin folder: `./install.sh /path/to/plugins`.

4. **Set your API key.** Either:
   - Click the menu bar icon → **Set API key…** and paste it (stored at
     `~/.config/transit-eta/config.json`, `chmod 600`), or
   - `export TRANSIT_ETA_API_KEY=...` in your shell profile and restart
     SwiftBar so it inherits the variable (this takes priority and is
     never written to disk).

5. Click the icon → **Search stop…**, type a stop name, pick from the list
   if several match. The dropdown now shows the next 5 departures.

6. Click a line/destination to pin it. The icon updates to show that
   route's live ETA; click **Unpin** to go back to just the stop name.

## Running the tests

```
./run_tests.sh
```

Runs the XML-parsing and menu-rendering logic against recorded sample OJP
responses in `tests/fixtures/` — no network or API key required. This is
the part of the tool I could verify from this environment; the live API
call and the macOS-only bits (menu bar rendering, `osascript` dialogs) need
to be checked on your Mac.

## Gaps and ideas for next steps

Things this first version deliberately leaves out, roughly in the order
I'd tackle them:

- **Multiple pinned/favorite stops.** Right now there's one stop and one
  pinned line. A natural next step is a small list of favorites you can
  cycle through (e.g. left-click cycles, right-click opens the picker), or
  rotate automatically every N seconds.
- **"Leave now" alerts.** Configure a walk-to-stop time and get a
  notification (`osascript -e 'display notification'`) when it's time to
  leave, not just when the vehicle is close.
- **Real-time disruption/cancellation handling.** OJP can flag cancelled
  services; the parser currently only reads scheduled/estimated times, not
  cancellation or "not via" flags — worth surfacing those distinctly
  (strike-through, ⚠️) rather than just an off-by-however-many-minutes ETA.
- **Nearby stops via location, not just name search.** OJP's
  `LocationInformationRequest` also supports a coordinate + radius query;
  hooking that up (e.g. via CoreLocation from a small helper, or just your
  Mac's IP-based location) would let you skip typing a stop name for your
  usual one.
- **Rate limiting / backoff.** No retry/backoff logic yet if the API
  throttles or errors repeatedly — currently it just shows the error and
  waits for the next poll (10s). Fine for personal use; worth hardening if
  the free tier has a strict quota.
- **Caching stop search results.** Repeated searches for the same text hit
  the API every time; an LRU cache keyed by query would cut latency and
  request volume.
- **Config UI instead of AppleScript dialogs.** `display dialog` /
  `choose from list` work but look dated. A tiny native SwiftUI settings
  window (still launched from the plugin) would feel nicer, at the cost of
  needing an actual small Swift helper app.
- **Localization.** opentransportdata.swiss serves French/German/Italian
  stop names; right now whatever the API returns is shown as-is. Could
  pick a language via `Accept-Language` if OJP honors it, or via a config
  setting.
- **Distinguishing "delayed" from "on time, just later than typetable"
  more precisely** — e.g. color the ETA text (SwiftBar supports
  `color=red`) when delay minutes cross a threshold.
- **Packaging as a native menu bar app.** SwiftBar is a great fit for a
  personal tool but adds a dependency. If this grows into something you'd
  want to hand to other people, a small Swift `MenuBarExtra` app (no
  Xcode-project ceremony beyond the initial scaffold) would remove the
  SwiftBar requirement — the `transit_eta` parsing logic here would port
  over conceptually even though the language would change.
