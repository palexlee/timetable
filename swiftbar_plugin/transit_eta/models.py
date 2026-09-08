"""Data types shared by the OJP client and the menu renderer."""

from dataclasses import dataclass
from datetime import datetime
from typing import Optional

# OJP/SIRI PtMode values -> a glyph we can put straight in the menu bar
# title (no image assets needed, renders correctly in light & dark mode).
MODE_ICONS = {
    "rail": "🚆",
    "suburbanrail": "🚆",
    "tram": "🚊",
    "bus": "🚌",
    "coach": "🚌",
    "metro": "🚇",
    "underground": "🚇",
    "water": "⛴",
    "cableway": "🚡",
    "funicular": "🚞",
}
DEFAULT_ICON = "🚏"


def icon_for_mode(mode: Optional[str]) -> str:
    return MODE_ICONS.get((mode or "").strip().lower(), DEFAULT_ICON)


@dataclass(frozen=True)
class StopEvent:
    """A single upcoming departure at a stop."""

    mode: str
    line_name: str
    destination: str
    scheduled_time: datetime
    estimated_time: Optional[datetime] = None
    platform: Optional[str] = None

    @property
    def best_time(self) -> datetime:
        return self.estimated_time or self.scheduled_time

    @property
    def is_delayed(self) -> bool:
        return bool(
            self.estimated_time and self.estimated_time > self.scheduled_time
        )

    @property
    def delay_minutes(self) -> int:
        if not self.is_delayed:
            return 0
        delta = self.estimated_time - self.scheduled_time
        return max(0, round(delta.total_seconds() / 60))

    @property
    def icon(self) -> str:
        return icon_for_mode(self.mode)

    def eta_minutes(self, now: datetime) -> int:
        delta = self.best_time - now
        return max(0, round(delta.total_seconds() / 60))

    def matches_pin(self, pin: dict) -> bool:
        """Whether this event belongs to the same route+destination as ``pin``."""
        if not pin:
            return False
        return (
            self.mode == pin.get("mode")
            and self.line_name == pin.get("line_name")
            and self.destination == pin.get("destination")
        )


@dataclass(frozen=True)
class StopMatch:
    """A candidate stop returned by the location search."""

    stop_ref: str
    name: str
    probability: Optional[float] = None
