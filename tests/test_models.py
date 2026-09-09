import unicodedata
import unittest
from datetime import datetime

from transit_eta.models import StopEvent


def _event(destination):
    return StopEvent(
        mode="bus",
        line_name="46",
        destination=destination,
        scheduled_time=datetime(2026, 9, 9, 10, 29),
    )


class MatchesPinUnicodeNormalizationTest(unittest.TestCase):
    def test_matches_despite_nfc_nfd_mismatch(self):
        # macOS hands SwiftBar's click args back as NFD ("u" + combining
        # diaeresis); the OJP API sends NFC (precomposed "ü"). Same text,
        # different codepoints -- matches_pin must not care which is which.
        nfc = "Rütihof"
        nfd = unicodedata.normalize("NFD", nfc)
        self.assertNotEqual(nfc, nfd)  # sanity: they really are different strings

        event = _event(nfc)
        pin = {"mode": "bus", "line_name": "46", "destination": nfd}
        self.assertTrue(event.matches_pin(pin))


if __name__ == "__main__":
    unittest.main()
