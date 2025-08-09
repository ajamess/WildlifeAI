import logging
import importlib.util
from pathlib import Path
import sys
import types

# Stub cv2 to avoid dependency during import
sys.modules["cv2"] = types.ModuleType("cv2")

spec = importlib.util.spec_from_file_location(
    "wildlifeai_runner",
    Path(__file__).resolve().parents[1] / "python" / "runner" / "wildlifeai_runner.py",
)
wildlifeai_runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wildlifeai_runner)

def test_warns_when_rawpy_missing(monkeypatch, caplog):
    monkeypatch.setattr(wildlifeai_runner, "rawpy", None)
    caplog.set_level(logging.WARNING)
    caplog.clear()
    result = wildlifeai_runner.read_image("example.cr2")
    assert result is None
    assert any("rawpy" in record.message.lower() for record in caplog.records)
