import math
from dataclasses import dataclass
from typing import List, Dict, Any, Optional

import pytest

DEFAULTS = {
    "timeGap": 2,
    "exposureTolerance": 0.1,
    "expectedBracketSize": 3,
    "collapseStacks": True,
}


@dataclass
class MockPhoto:
    capture_time: int
    shutter: Optional[float] = None
    aperture: Optional[float] = None
    iso: Optional[float] = None

    def getRawMetadata(self, key: str):
        return {
            "captureTime": self.capture_time,
            "shutterSpeed": self.shutter,
            "aperture": self.aperture,
            "isoSpeedRating": self.iso,
        }.get(key)


def _parse_number(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        if "/" in value:
            n, d = value.split("/", 1)
            return float(n) / float(d)
        try:
            return float(value)
        except ValueError:
            return 0
    return 0


def _get_exposure(photo: MockPhoto) -> float:
    shutter = _parse_number(photo.getRawMetadata("shutterSpeed"))
    aperture = _parse_number(photo.getRawMetadata("aperture"))
    iso = _parse_number(photo.getRawMetadata("isoSpeedRating"))
    if shutter <= 0 or aperture <= 0 or iso <= 0:
        return 0
    return math.log(aperture * aperture / shutter * 100 / iso, 2)


def _group_by_time(photos: List[MockPhoto], prefs: Dict[str, Any]):
    photos = sorted(photos, key=lambda p: p.getRawMetadata("captureTime") or 0)
    groups = []
    cur = None
    last = None
    gap = prefs["timeGap"]
    for p in photos:
        ct = p.getRawMetadata("captureTime") or 0
        if last is None or (ct - last) <= gap:
            if cur is None:
                cur = {"photos": [], "exposures": []}
            cur["photos"].append(p)
            cur["exposures"].append(_get_exposure(p))
        else:
            groups.append(cur)
            cur = {"photos": [p], "exposures": [_get_exposure(p)]}
        last = ct
    if cur:
        groups.append(cur)
    return groups


def _classify_group(group: Dict[str, Any], prefs: Dict[str, Any]):
    tol = prefs["exposureTolerance"]
    buckets = set()
    for ev in group["exposures"]:
        bucket = math.floor(ev / tol + 0.5)
        buckets.add(bucket)
    if len(buckets) > 1:
        group["type"] = "bracket"
    elif len(group["photos"]) > 1:
        group["type"] = "panorama"
    else:
        group["type"] = "single"


def _merge_incomplete(groups: List[Dict[str, Any]], prefs: Dict[str, Any]):
    expected = prefs["expectedBracketSize"]
    merged = []
    i = 0
    while i < len(groups):
        g = groups[i]
        if (
            g["type"] == "bracket"
            and len(g["photos"]) < expected
            and i + 1 < len(groups)
            and groups[i + 1]["type"] == "bracket"
        ):
            nxt = groups[i + 1]
            g["photos"].extend(nxt["photos"])
            g["exposures"].extend(nxt["exposures"])
            _classify_group(g, prefs)
            i += 1
        merged.append(g)
        i += 1
    return merged


def analyze_brackets(photos: List[MockPhoto], prefs: Dict[str, Any] | None = None):
    prefs = {**DEFAULTS, **(prefs or {})}
    groups = _group_by_time(photos, prefs)
    for g in groups:
        _classify_group(g, prefs)
    groups = _merge_incomplete(groups, prefs)
    for g in groups:
        _classify_group(g, prefs)
        if g["type"] == "bracket":
            idx = min(range(len(g["exposures"])), key=lambda i: abs(g["exposures"][i]))
            g["top"] = g["photos"][idx]
        else:
            g["top"] = g["photos"][0]
    return groups


def _make_photo(ev: float, capture_time: int) -> MockPhoto:
    shutter = 2 ** (-ev)
    return MockPhoto(capture_time=capture_time, shutter=shutter, aperture=1, iso=100)


@pytest.mark.parametrize("size", [3, 5, 7])
def test_standard_brackets(size):
    start = -(size // 2)
    exposures = list(range(start, start + size))
    photos = [_make_photo(ev, i) for i, ev in enumerate(exposures)]
    groups = analyze_brackets(photos, {"expectedBracketSize": size})
    assert len(groups) == 1
    g = groups[0]
    assert g["type"] == "bracket"
    assert len(g["photos"]) == size
    assert g["top"] is photos[size // 2]


def test_panorama_grouping():
    photos = [_make_photo(0, i) for i in range(3)]
    groups = analyze_brackets(photos)
    assert len(groups) == 1
    g = groups[0]
    assert g["type"] == "panorama"
    assert g["top"] is photos[0]


def test_incomplete_sequence_merge():
    photos = [
        _make_photo(-1, 0),
        _make_photo(0, 1),
        _make_photo(-1, 4),
        _make_photo(0, 5),
    ]
    groups = analyze_brackets(photos)
    assert len(groups) == 1
    g = groups[0]
    assert g["type"] == "bracket"
    assert len(g["photos"]) == 4


def test_missing_metadata_classification():
    photos = [
        MockPhoto(0),
        MockPhoto(1),
    ]
    groups = analyze_brackets(photos)
    assert len(groups) == 1
    g = groups[0]
    assert g["type"] == "panorama"
    assert g["top"] is photos[0]
