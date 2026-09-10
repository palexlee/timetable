import os
import unittest

from transit_eta.ojp_client import build_stop_event_request, parse_stop_event_response
from transit_eta.ojp_http import OjpError


class BuildStopEventRequestTest(unittest.TestCase):
    def test_uses_stop_place_ref_not_stop_point_ref(self):
        # location_client.search_stops returns StopPlace refs (e.g.
        # "ch:1:sloid:7000"). Wrapping that in <StopPointRef> instead of
        # <StopPlaceRef> made the live OJP backend 500 -- confirmed against
        # the real API, see ojp_client.py's build_stop_event_request.
        xml = build_stop_event_request("ch:1:sloid:7000", 5).decode("utf-8")
        self.assertIn("<StopPlaceRef>ch:1:sloid:7000</StopPlaceRef>", xml)
        self.assertNotIn("StopPointRef", xml)

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def _load(name):
    with open(os.path.join(FIXTURES, name), "rb") as f:
        return f.read()


class ParseStopEventResponseNonXmlTest(unittest.TestCase):
    def test_non_xml_body_raises_ojp_error_not_parse_error(self):
        # A degraded/outage response can come back 2xx with a non-XML body
        # (maintenance page, empty body, ...) -- this must surface as a
        # normal OjpError, not an uncaught xml.etree.ElementTree.ParseError,
        # since the plugin re-runs on a timer and must never crash outright.
        with self.assertRaises(OjpError):
            parse_stop_event_response(b"Service Unavailable")


class ParseStopEventResponseTest(unittest.TestCase):
    def setUp(self):
        self.events = parse_stop_event_response(_load("stop_event_response.xml"))

    def test_parses_events_sorted_by_time(self):
        self.assertEqual([e.line_name for e in self.events], ["IC 1", "12", "9", "IR"])

    def test_falls_back_to_public_code_when_no_published_line_name(self):
        # Real OJP responses send PublicCode instead of PublishedLineName --
        # verified against the live API, see ojp_client.py's line_name fallback.
        ir = self.events[-1]
        self.assertEqual(ir.line_name, "IR")
        self.assertEqual(ir.destination, "Zürich Flughafen")

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
