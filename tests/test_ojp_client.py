import os
import unittest

from transit_eta.ojp_client import parse_stop_event_response

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def _load(name):
    with open(os.path.join(FIXTURES, name), "rb") as f:
        return f.read()


class ParseStopEventResponseTest(unittest.TestCase):
    def setUp(self):
        self.events = parse_stop_event_response(_load("stop_event_response.xml"))

    def test_parses_events_sorted_by_time(self):
        self.assertEqual([e.line_name for e in self.events], ["IC 1", "12", "9"])

    def test_parses_mode_destination_and_platform(self):
        ic1 = self.events[0]
        self.assertEqual(ic1.mode, "rail")
        self.assertEqual(ic1.destination, "Genève")
        self.assertEqual(ic1.platform, "3")
        self.assertEqual(ic1.icon, "🚆")

    def test_detects_delay(self):
        bus12 = next(e for e in self.events if e.line_name == "12")
        self.assertTrue(bus12.is_delayed)
        self.assertEqual(bus12.delay_minutes, 3)
        self.assertEqual(bus12.icon, "🚌")

    def test_no_delay_when_estimated_equals_scheduled(self):
        ic1 = self.events[0]
        self.assertFalse(ic1.is_delayed)

    def test_falls_back_to_scheduled_time_when_no_estimate(self):
        tram9 = next(e for e in self.events if e.line_name == "9")
        self.assertIsNone(tram9.estimated_time)
        self.assertEqual(tram9.best_time, tram9.scheduled_time)


if __name__ == "__main__":
    unittest.main()
