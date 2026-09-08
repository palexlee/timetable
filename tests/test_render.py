import os
import unittest
from datetime import timedelta

from transit_eta import render
from transit_eta.ojp_client import parse_stop_event_response

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def _events():
    with open(os.path.join(FIXTURES, "stop_event_response.xml"), "rb") as f:
        return parse_stop_event_response(f.read())


class TitleForTest(unittest.TestCase):
    def setUp(self):
        self.events = _events()

    def test_shows_stop_name_when_unpinned(self):
        cfg = {"stop_name": "Bern", "pinned": None}
        title = render.title_for(cfg, self.events, self.events[0].scheduled_time)
        self.assertEqual(title, "🚏 Bern")

    def test_shows_compact_eta_when_pinned(self):
        ic1 = self.events[0]
        cfg = {
            "stop_name": "Bern",
            "pinned": {"mode": "rail", "line_name": "IC 1", "destination": "Genève"},
        }
        now = ic1.scheduled_time - timedelta(minutes=4)
        self.assertEqual(render.title_for(cfg, self.events, now), "🚆IC 1 4′")

    def test_flags_delay_when_pinned_line_is_late(self):
        bus12 = next(e for e in self.events if e.line_name == "12")
        cfg = {
            "stop_name": "Bern",
            "pinned": {"mode": "bus", "line_name": "12", "destination": "Bern, Bahnhof"},
        }
        now = bus12.best_time - timedelta(minutes=2)
        self.assertEqual(render.title_for(cfg, self.events, now), "🚌12 2′ (+3)")

    def test_falls_back_when_pinned_line_not_in_next_events(self):
        cfg = {
            "stop_name": "Bern",
            "pinned": {"mode": "tram", "line_name": "99", "destination": "Nowhere"},
        }
        title = render.title_for(cfg, self.events, self.events[0].scheduled_time)
        self.assertEqual(title, "🚊 99 –")


class BuildMenuTest(unittest.TestCase):
    def setUp(self):
        self.events = _events()

    def test_lists_up_to_five_events_with_select_actions(self):
        cfg = {"stop_name": "Bern", "stop_ref": "8507000", "pinned": None}
        menu = render.build_menu(
            "/path/to/plugin.py", cfg, self.events, now=self.events[0].scheduled_time
        )
        lines = menu.splitlines()
        self.assertEqual(lines[0], "🚏 Bern")
        self.assertEqual(lines[1], render.SEPARATOR)
        self.assertEqual(
            sum(1 for l in lines if "param1=select" in l), len(self.events)
        )
        self.assertTrue(any("Genève" in l for l in lines))

    def test_marks_pinned_event(self):
        cfg = {
            "stop_name": "Bern",
            "stop_ref": "8507000",
            "pinned": {"mode": "rail", "line_name": "IC 1", "destination": "Genève"},
        }
        menu = render.build_menu(
            "/path/to/plugin.py", cfg, self.events, now=self.events[0].scheduled_time
        )
        pinned_line = next(l for l in menu.splitlines() if "Genève" in l)
        self.assertTrue(pinned_line.startswith("✓ "))


class CompactEtaTest(unittest.TestCase):
    def test_formats_zero_as_now(self):
        self.assertEqual(render.compact_eta(0), "now")

    def test_formats_minutes_with_prime(self):
        self.assertEqual(render.compact_eta(4), "4′")


if __name__ == "__main__":
    unittest.main()
