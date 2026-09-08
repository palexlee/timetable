import os
import unittest

from transit_eta.location_client import parse_location_response

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def _load(name):
    with open(os.path.join(FIXTURES, name), "rb") as f:
        return f.read()


class ParseLocationResponseTest(unittest.TestCase):
    def test_parses_matches_sorted_by_probability(self):
        matches = parse_location_response(_load("location_response.xml"))
        self.assertEqual([m.name for m in matches], ["Bern", "Bern, Bahnhof"])
        self.assertEqual(matches[0].stop_ref, "8507000")
        self.assertEqual(matches[0].probability, 0.98)


if __name__ == "__main__":
    unittest.main()
