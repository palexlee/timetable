"""Client for the OJP (Open Journey Planner / VDV 431) StopEventRequest.

opentransportdata.swiss (https://opentransportdata.swiss/en/) exposes OJP
as its live "next departures at a stop" API -- this is what a physical
departure board at a Swiss station uses.

IMPORTANT -- please verify before relying on this:
This sandbox's outbound network access to opentransportdata.swiss is
blocked, so the endpoint URL, auth header and exact response tags below
could not be checked against the live docs while writing this. They match
the published OJP 2.0 / VDV 431 spec as of this writing, but Swiss transport
APIs have moved endpoints before. After you register for an API key at
https://opentransportdata.swiss/en/ and subscribe to the "OJP" product in
their API Manager, double-check OJP_ENDPOINT and the auth header format
against the docs shown there, and adjust the two constants below if needed
-- the rest of the plugin doesn't care how this module gets its data.
"""

import urllib.request
import urllib.error
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from .models import StopEvent
from .xml_util import parse, Node
from .ojp_http import (
    OJP_ENDPOINT,
    REQUEST_TIMEOUT_SECONDS,
    OjpError,
    auth_headers,
    error_from_http_error,
    iso_now,
)


def build_stop_event_request(stop_ref: str, number_of_results: int) -> bytes:
    timestamp = iso_now()
    xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri" version="2.0">
  <OJPRequest>
    <siri:ServiceRequest>
      <siri:RequestTimestamp>{timestamp}</siri:RequestTimestamp>
      <siri:RequestorRef>transit-eta-swiftbar</siri:RequestorRef>
      <OJPStopEventRequest>
        <siri:RequestTimestamp>{timestamp}</siri:RequestTimestamp>
        <Location>
          <PlaceRef>
            <StopPlaceRef>{stop_ref}</StopPlaceRef>
          </PlaceRef>
          <DepArrTime>{timestamp}</DepArrTime>
        </Location>
        <Params>
          <NumberOfResults>{number_of_results}</NumberOfResults>
          <StopEventType>departure</StopEventType>
          <IncludeRealtimeData>true</IncludeRealtimeData>
        </Params>
      </OJPStopEventRequest>
    </siri:ServiceRequest>
  </OJPRequest>
</OJP>"""
    return xml.encode("utf-8")


def _parse_time(text: Optional[str]) -> Optional[datetime]:
    if not text:
        return None
    text = text.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone()


def _parse_stop_event(node: Node) -> Optional[StopEvent]:
    service = node.find("StopEvent", "Service")
    call = node.find("StopEvent", "ThisCall", "CallAtStop")
    if service is None or call is None:
        return None

    mode = service.text_of("Mode", "PtMode") or ""
    line_name = (
        service.text_of("PublishedLineName", "Text")
        or service.text_of("PublicCode")
        or service.text_of("LineRef")
        or "?"
    )
    destination = (
        service.text_of("DestinationText", "Text")
        or service.text_of("DestinationStopPointRef")
        or "?"
    )

    departure = call.find("ServiceDeparture")
    if departure is None:
        return None
    scheduled = _parse_time(departure.text_of("TimetabledTime"))
    estimated = _parse_time(departure.text_of("EstimatedTime"))
    if scheduled is None:
        return None

    platform = call.text_of("PlannedQuay", "Text") or call.text_of("EstimatedQuay", "Text")

    return StopEvent(
        mode=mode,
        line_name=line_name,
        destination=destination,
        scheduled_time=scheduled,
        estimated_time=estimated,
        platform=platform,
    )


def parse_stop_event_response(xml_bytes: bytes) -> List[StopEvent]:
    root = parse(xml_bytes)

    fault = root.find_all("ErrorMessage") or root.find_all("Fault")
    if fault:
        text = fault[0].text_of("Text") or fault[0].text or "unknown OJP error"
        raise OjpError(f"OJP returned an error: {text}")

    events: List[StopEvent] = []
    for result in root.find_all("StopEventResult"):
        event = _parse_stop_event(result)
        if event is not None:
            events.append(event)
    events.sort(key=lambda e: e.best_time)
    return events


def next_departures(cfg: Dict[str, Any], limit: int = 5) -> List[StopEvent]:
    api_key = cfg.get("api_key")
    stop_ref = cfg.get("stop_ref")
    if not api_key:
        raise OjpError("No API key configured (set TRANSIT_ETA_API_KEY or use the menu).")
    if not stop_ref:
        raise OjpError("No stop configured yet.")

    body = build_stop_event_request(stop_ref, limit)
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
        raise error_from_http_error(exc) from exc
    except urllib.error.URLError as exc:
        raise OjpError(f"Could not reach OJP API: {exc.reason}") from exc

    return parse_stop_event_response(payload)[:limit]
