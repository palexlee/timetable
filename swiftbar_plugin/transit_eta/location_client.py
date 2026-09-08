"""Client for the OJP LocationInformationRequest (stop name -> stop ref).

Same caveat as ojp_client.py: the endpoint is shared with the StopEvent
request (OJP is one combined service), but the exact response tags for a
stop search could not be verified against the live docs from this sandbox
(outbound access to opentransportdata.swiss is blocked here). Adjust
_parse_place_result() if the portal's current schema differs.
"""

import urllib.request
import urllib.error
from typing import Any, Dict, List, Optional

from .models import StopMatch
from .ojp_http import (
    OJP_ENDPOINT,
    REQUEST_TIMEOUT_SECONDS,
    OjpError,
    auth_headers,
    iso_now,
    xml_escape,
)
from .xml_util import parse, Node


def build_location_request(query: str, number_of_results: int) -> bytes:
    timestamp = iso_now()
    xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri" version="2.0">
  <OJPRequest>
    <siri:ServiceRequest>
      <siri:RequestTimestamp>{timestamp}</siri:RequestTimestamp>
      <siri:RequestorRef>transit-eta-swiftbar</siri:RequestorRef>
      <OJPLocationInformationRequest>
        <siri:RequestTimestamp>{timestamp}</siri:RequestTimestamp>
        <InitialInput>
          <Name>{xml_escape(query)}</Name>
        </InitialInput>
        <Restrictions>
          <Type>stop</Type>
          <NumberOfResults>{number_of_results}</NumberOfResults>
        </Restrictions>
      </OJPLocationInformationRequest>
    </siri:ServiceRequest>
  </OJPRequest>
</OJP>"""
    return xml.encode("utf-8")


def _parse_place_result(node: Node) -> Optional[StopMatch]:
    place = node.find("Place")
    if place is None:
        return None

    stop_ref = (
        place.text_of("StopPlace", "StopPlaceRef")
        or place.text_of("StopPoint", "StopPointRef")
    )
    name = (
        place.text_of("StopPlace", "StopPlaceName", "Text")
        or place.text_of("Name", "Text")
    )
    if not stop_ref or not name:
        return None

    probability_text = node.text_of("Probability")
    probability = float(probability_text) if probability_text else None

    return StopMatch(stop_ref=stop_ref, name=name, probability=probability)


def parse_location_response(xml_bytes: bytes) -> List[StopMatch]:
    root = parse(xml_bytes)
    matches: List[StopMatch] = []
    for result in root.find_all("PlaceResult"):
        match = _parse_place_result(result)
        if match is not None:
            matches.append(match)
    matches.sort(key=lambda m: m.probability or 0, reverse=True)
    return matches


def search_stops(cfg: Dict[str, Any], query: str, limit: int = 8) -> List[StopMatch]:
    api_key = cfg.get("api_key")
    if not api_key:
        raise OjpError("No API key configured (set TRANSIT_ETA_API_KEY or use the menu).")
    if not query.strip():
        return []

    body = build_location_request(query.strip(), limit)
    request = urllib.request.Request(
        OJP_ENDPOINT,
        data=body,
        method="POST",
        headers={
            **auth_headers(api_key),
            "Content-Type": "application/xml",
            "Accept": "application/xml",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as resp:
            payload = resp.read()
    except urllib.error.HTTPError as exc:
        raise OjpError(f"HTTP {exc.code} from OJP API: {exc.reason}") from exc
    except urllib.error.URLError as exc:
        raise OjpError(f"Could not reach OJP API: {exc.reason}") from exc

    return parse_location_response(payload)[:limit]
