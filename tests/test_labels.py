import sys
import types
import importlib.util
from pathlib import Path

# Provide stub for cv2 to avoid system dependency issues during import
sys.modules['cv2'] = types.ModuleType('cv2')

spec = importlib.util.spec_from_file_location(
    'wai_runner',
    Path(__file__).resolve().parents[1] / 'python' / 'runner' / 'wai_runner.py'
)
wai_runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wai_runner)


def test_first_label_utf8_sig():
    _, _, labels = wai_runner.load_models()
    assert labels and labels[0] == "Abert's Towhee"
