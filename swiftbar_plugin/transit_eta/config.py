"""Loading/saving the small local config file.

Nothing here ever gets committed to the repo: the config lives under the
user's ``~/.config`` directory, outside any git working tree, and is written
with ``0600`` permissions since it can hold an API key.
"""

import json
import os
from pathlib import Path
from typing import Any, Dict, Optional

CONFIG_DIR = Path(os.environ.get("TRANSIT_ETA_HOME", Path.home() / ".config" / "transit-eta"))
CONFIG_FILE = CONFIG_DIR / "config.json"

DEFAULTS: Dict[str, Any] = {
    "api_key": None,
    "stop_ref": None,
    "stop_name": None,
    "pinned": None,  # {"mode": ..., "line_name": ..., "destination": ...}
}


def load() -> Dict[str, Any]:
    cfg = dict(DEFAULTS)
    if CONFIG_FILE.exists():
        try:
            cfg.update(json.loads(CONFIG_FILE.read_text()))
        except (json.JSONDecodeError, OSError):
            pass
    # An env var always wins, so the key never has to live on disk at all.
    env_key = os.environ.get("TRANSIT_ETA_API_KEY")
    if env_key:
        cfg["api_key"] = env_key
    return cfg


def save(cfg: Dict[str, Any]) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    # Don't persist a key that came from the environment.
    to_write = dict(cfg)
    if os.environ.get("TRANSIT_ETA_API_KEY"):
        to_write["api_key"] = None
    CONFIG_FILE.write_text(json.dumps(to_write, indent=2))
    os.chmod(CONFIG_FILE, 0o600)


def set_stop(stop_ref: str, stop_name: str) -> None:
    cfg = load()
    cfg["stop_ref"] = stop_ref
    cfg["stop_name"] = stop_name
    cfg["pinned"] = None
    save(cfg)


def set_pin(mode: str, line_name: str, destination: str) -> None:
    cfg = load()
    cfg["pinned"] = {"mode": mode, "line_name": line_name, "destination": destination}
    save(cfg)


def clear_pin() -> None:
    cfg = load()
    cfg["pinned"] = None
    save(cfg)


def set_api_key(api_key: Optional[str]) -> None:
    cfg = load()
    cfg["api_key"] = api_key
    save(cfg)
