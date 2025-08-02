#!/usr/bin/env python3
"""Compatibility wrapper exposing ``ModelRunner`` and CLI for tests.

The real implementation lives in :mod:`wildlifeai_runner`. To avoid heavy
imports during test collection (which may require optional system libraries),
we lazily import the underlying module when ``ModelRunner`` is instantiated or
when the CLI is executed.
"""

from __future__ import annotations

import sys
from typing import Any


class ModelRunner:
    """Lazy wrapper around ``wildlifeai_runner.EnhancedModelRunner``."""

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        from wildlifeai_runner import EnhancedModelRunner

        self._impl = EnhancedModelRunner(*args, **kwargs)

    def __getattr__(self, name: str) -> Any:
        return getattr(self._impl, name)


def _main() -> int:
    from wildlifeai_runner import main

    return main()


if __name__ == "__main__":  # pragma: no cover - CLI entry
    sys.exit(_main())
