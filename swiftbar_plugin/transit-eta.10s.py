#!/usr/bin/env python3
# <xbar.title>Transit ETA</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author>you</xbar.author>
# <xbar.author.github>-</xbar.author.github>
# <xbar.desc>Live bus/tram/train departures for one Swiss stop, from opentransportdata.swiss. Click the icon to search a stop and pin a line; the icon then shows that line's live ETA.</xbar.desc>
# <xbar.dependencies>python3</xbar.dependencies>
#
# Rename this file to change the refresh interval, e.g. transit-eta.30s.py.
# Faster than ~10s is unlikely to be worth the extra API calls.
"""SwiftBar/xbar plugin entry point.

All the actual logic lives in transit_eta/ next to this file so it can be
unit tested (see ../tests) without SwiftBar or a network connection. This
file only wires stdin/argv/stdout to that package.
"""

import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from transit_eta import config, location_client, ojp_client, render
from transit_eta.ojp_http import OjpError

SCRIPT_PATH = os.path.abspath(__file__)


def _osascript(script: str) -> str:
    result = subprocess.run(
        ["osascript", "-e", script], capture_output=True, text=True
    )
    return result.stdout.strip()


def _prompt_text(title: str, prompt: str) -> str:
    script = (
        f'display dialog "{prompt}" default answer "" with title "{title}" '
        'buttons {"Cancel", "OK"} default button "OK"\n'
        "text returned of result"
    )
    return _osascript(script)


def _prompt_password(title: str, prompt: str) -> str:
    script = (
        f'display dialog "{prompt}" default answer "" with title "{title}" '
        'with hidden answer buttons {"Cancel", "OK"} default button "OK"\n'
        "text returned of result"
    )
    return _osascript(script)


def _choose_from_list(title: str, options: list) -> str:
    quoted = ", ".join(f'"{o}"' for o in options)
    script = (
        f'choose from list {{{quoted}}} with title "{title}" '
        f'with prompt "Multiple stops match - pick one:"'
    )
    result = _osascript(script)
    return "" if result in ("", "false") else result


def _notify(title: str, message: str) -> None:
    _osascript(f'display notification "{message}" with title "{title}"')


def action_set_key() -> None:
    key = _prompt_password("Transit ETA", "OJP API key (opentransportdata.swiss):")
    if key:
        config.set_api_key(key)


def action_search() -> None:
    cfg = config.load()
    if not cfg.get("api_key"):
        action_set_key()
        cfg = config.load()
        if not cfg.get("api_key"):
            return

    query = _prompt_text("Transit ETA", "Stop name:")
    if not query:
        return

    try:
        matches = location_client.search_stops(cfg, query)
    except OjpError as exc:
        _notify("Transit ETA", str(exc))
        return

    if not matches:
        _notify("Transit ETA", f"No stop found for '{query}'.")
        return

    chosen = matches[0]
    if len(matches) > 1:
        labels = [m.name for m in matches]
        picked_label = _choose_from_list("Transit ETA", labels)
        if not picked_label:
            return
        chosen = next((m for m in matches if m.name == picked_label), matches[0])

    config.set_stop(chosen.stop_ref, chosen.name)


def action_select(mode: str, line_name: str, destination: str) -> None:
    config.set_pin(mode, line_name, destination)


def action_unpin() -> None:
    config.clear_pin()


def main() -> None:
    args = sys.argv[1:]
    if args:
        action = args[0]
        if action == "search":
            action_search()
        elif action == "select" and len(args) >= 4:
            action_select(args[1], args[2], args[3])
        elif action == "unpin":
            action_unpin()
        elif action == "set_key":
            action_set_key()
        elif action == "refresh":
            pass  # no-op: refresh=true on the click already redraws the menu
        return

    cfg = config.load()
    if not cfg.get("api_key"):
        print(render.no_api_key_menu(SCRIPT_PATH))
        return
    if not cfg.get("stop_ref"):
        print(render.no_stop_menu(SCRIPT_PATH))
        return

    try:
        events = ojp_client.next_departures(cfg, limit=5)
    except OjpError as exc:
        print(render.error_menu(SCRIPT_PATH, cfg, str(exc)))
        return

    print(render.build_menu(SCRIPT_PATH, cfg, events))


if __name__ == "__main__":
    main()
