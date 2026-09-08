"""Shared bits for talking to the OJP endpoint: auth, timestamps, errors.

See the module docstring in ojp_client.py for the caveat on why
OJP_ENDPOINT needs to be double-checked against opentransportdata.swiss's
live docs. The auth scheme (Authorization: Bearer <key>, plus a
non-empty User-Agent) is confirmed against opentransportdata.swiss's own
docs -- their gateway 403s requests with no User-Agent set, which is
Python's urllib default.
"""

import urllib.error
from datetime import datetime, timezone
from typing import Dict

OJP_ENDPOINT = "https://api.opentransportdata.swiss/ojp20"
REQUEST_TIMEOUT_SECONDS = 15
USER_AGENT = "transit-eta-swiftbar/1.0"


class OjpError(RuntimeError):
    """Raised for network/auth/parsing failures talking to the OJP API."""


def auth_headers(api_key: str) -> Dict[str, str]:
    return {
        "Authorization": f"Bearer {api_key}",
        "User-Agent": USER_AGENT,
    }


def iso_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def error_from_http_error(exc: "urllib.error.HTTPError") -> OjpError:
    # exc.reason is just the status phrase (e.g. "Forbidden"); the body
    # usually carries the actual reason (invalid/expired key, not
    # subscribed to this product, quota exceeded, ...), so surface it.
    try:
        detail = exc.read().decode("utf-8", errors="replace").strip()
    except Exception:
        detail = ""
    detail = detail[:300] if detail else exc.reason
    return OjpError(f"HTTP {exc.code} from OJP API: {detail}")


def xml_escape(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )
