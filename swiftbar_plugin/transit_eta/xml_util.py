"""Namespace-tolerant XML helpers.

OJP (Open Journey Planner / VDV 431) responses mix the ``ojp`` and ``siri``
XML namespaces, and different server versions have used slightly different
namespace URIs. Rather than hard-code namespace maps that could go stale, we
flatten each element down to its local tag name (dropping the ``{uri}``
prefix ElementTree keeps) and walk the tree by tag name only. This makes the
parser resilient to namespace/version drift, at the cost of being slightly
less strict than a schema-aware parser -- an acceptable trade-off for a
small menu bar tool.
"""

from typing import List, Optional
from xml.etree import ElementTree as ET


class Node:
    __slots__ = ("tag", "text", "children")

    def __init__(self, tag: str, text: Optional[str], children: List["Node"]):
        self.tag = tag
        self.text = text
        self.children = children

    def find(self, *path: str) -> Optional["Node"]:
        """Depth-first, first-match lookup of a nested tag path."""
        current = [self]
        for tag in path:
            nxt: List[Node] = []
            for node in current:
                nxt.extend(c for c in node.children if c.tag == tag)
            current = nxt
            if not current:
                return None
        return current[0]

    def find_all(self, tag: str) -> List["Node"]:
        """All descendants (any depth) with the given local tag name."""
        results = []
        for child in self.children:
            if child.tag == tag:
                results.append(child)
            results.extend(child.find_all(tag))
        return results

    def text_of(self, *path: str) -> Optional[str]:
        node = self.find(*path)
        if node is None or node.text is None:
            return None
        text = node.text.strip()
        return text or None


def _strip_ns(tag: str) -> str:
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def _build(elem: ET.Element) -> Node:
    text = elem.text.strip() if elem.text else None
    children = [_build(c) for c in elem]
    return Node(_strip_ns(elem.tag), text, children)


def parse(xml_bytes: bytes) -> Node:
    root = ET.fromstring(xml_bytes)
    return _build(root)
