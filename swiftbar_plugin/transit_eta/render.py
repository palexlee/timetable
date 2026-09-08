"""Builds the plain-text menu SwiftBar reads from stdout.

SwiftBar/xbar plugin format: everything before the first line that is
exactly "---" is the menu bar title (only the first line of it is actually
shown in the bar); everything after becomes the dropdown, one item per
line, with optional "| key=value ..." trailing metadata (color, font,
click actions, ...).
"""

from datetime import datetime
from typing import Any, Dict, List, Optional

from .models import StopEvent, icon_for_mode

SEPARATOR = "---"


def _escape(text: str) -> str:
    # "|" delimits an item's metadata in the plugin format, and newlines
    # would start a new item -- neither may appear inside a label.
    return text.replace("|", "❘").replace("\n", " ").strip()


def _quote(value: str) -> str:
    # These become "key="value"" tokens in the plugin metadata line, so a
    # literal quote in a stop/line name would otherwise terminate it early.
    return value.replace('"', "'")


def _select_action(script_path: str, event: StopEvent) -> str:
    return (
        f"bash=\"{script_path}\" "
        f"param1=select "
        f"param2=\"{_quote(event.mode)}\" "
        f"param3=\"{_quote(event.line_name)}\" "
        f"param4=\"{_quote(event.destination)}\" "
        f"terminal=false refresh=true"
    )


def compact_eta(mins: int) -> str:
    if mins <= 0:
        return "now"
    return f"{mins}′"  # prime symbol, e.g. "4′"


def title_for(cfg: Dict[str, Any], events: List[StopEvent], now: datetime) -> str:
    pin = cfg.get("pinned")
    if not pin:
        stop_name = cfg.get("stop_name")
        return f"🚏 {stop_name}" if stop_name else "🚏 Transit ETA"

    match = next((e for e in events if e.matches_pin(pin)), None)
    if match is None:
        # Pinned route isn't in the next N departures right now (e.g. big
        # gap between runs) -- show the icon with a dash rather than
        # silently falling back to a different line.
        return f"{icon_for_mode(pin.get('mode'))} {pin.get('line_name', '?')} –"

    eta = compact_eta(match.eta_minutes(now))
    label = f"{match.icon}{match.line_name} {eta}"
    if match.is_delayed:
        label += f" (+{match.delay_minutes})"
    return label


def no_api_key_menu(script_path: str) -> str:
    return "\n".join(
        [
            "🚏 Set API key",
            SEPARATOR,
            "No API key configured",
            f"🔑 Set API key... | bash=\"{script_path}\" param1=set_key terminal=false refresh=true",
        ]
    )


def no_stop_menu(script_path: str) -> str:
    return "\n".join(
        [
            "🚏 Pick a stop",
            SEPARATOR,
            f"🔍 Search stop... | bash=\"{script_path}\" param1=search terminal=false refresh=true",
        ]
    )


def error_menu(script_path: str, cfg: Dict[str, Any], message: str) -> str:
    stop_name = cfg.get("stop_name") or "Transit ETA"
    lines = [
        f"⚠️ {stop_name}",
        SEPARATOR,
        _escape(f"Error: {message}"),
        f"🔄 Refresh | bash=\"{script_path}\" param1=refresh terminal=false refresh=true",
        f"🔍 Change stop... | bash=\"{script_path}\" param1=search terminal=false refresh=true",
    ]
    return "\n".join(lines)


def build_menu(
    script_path: str,
    cfg: Dict[str, Any],
    events: List[StopEvent],
    now: Optional[datetime] = None,
) -> str:
    now = now or datetime.now().astimezone()
    lines = [title_for(cfg, events, now), SEPARATOR]

    stop_name = cfg.get("stop_name", "?")
    lines.append(_escape(f"Next at {stop_name}"))

    if not events:
        lines.append("No upcoming departures found")
    for event in events[:5]:
        eta = compact_eta(event.eta_minutes(now))
        sched = event.scheduled_time.strftime("%H:%M")
        delay = f" (+{event.delay_minutes}′)" if event.is_delayed else ""
        platform = f" · plat. {event.platform}" if event.platform else ""
        text = (
            f"{event.icon} {event.line_name} → {event.destination}  "
            f"{eta} ({sched}{delay}){platform}"
        )
        pin = cfg.get("pinned")
        prefix = "✓ " if pin and event.matches_pin(pin) else "    "
        lines.append(f"{prefix}{_escape(text)} | {_select_action(script_path, event)}")

    lines.append(SEPARATOR)
    if cfg.get("pinned"):
        lines.append(
            f"✕ Unpin | bash=\"{script_path}\" param1=unpin terminal=false refresh=true"
        )
    lines.append(
        f"🔍 Change stop... | bash=\"{script_path}\" param1=search terminal=false refresh=true"
    )
    lines.append(
        f"🔄 Refresh now | bash=\"{script_path}\" param1=refresh terminal=false refresh=true"
    )
    lines.append(
        f"🔑 Set API key... | bash=\"{script_path}\" param1=set_key terminal=false refresh=true"
    )
    return "\n".join(lines)
