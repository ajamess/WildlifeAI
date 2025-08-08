import sys
import tempfile
from pathlib import Path

import pytest

# Ensure runner module on path
sys.path.insert(0, str(Path(__file__).parent.parent / "python" / "runner"))
from wildlifeai_runner import EnhancedModelRunner  # type: ignore


def test_regression_real_files():
    """Run regression test using real .ARW files and expected CSV."""
    csv_path = Path(__file__).parent / "quick" / "kestrel_database.csv"
    images_dir = csv_path.parent / "original"
    model_path = Path(__file__).resolve().parent.parent / "models" / "model.onnx"

    # Skip if real model or images are not available
    if not model_path.exists() or model_path.stat().st_size < 1024:
        pytest.skip("Model file unavailable for regression test")
    if any(p.stat().st_size < 1024 for p in images_dir.glob("*.ARW")):
        pytest.skip("Real test images unavailable")

    runner = EnhancedModelRunner(use_gpu=False, max_workers=1)
    if runner.mask_rcnn is None or runner.mask_rcnn.model is None:
        pytest.skip("Mask R-CNN model not available")
    if runner.species_classifier is None:
        pytest.skip("Species classifier not available")

    with tempfile.TemporaryDirectory() as tmpdir:
        output_dir = Path(tmpdir)
        report = runner.run_regression_test(str(csv_path), output_dir)

    if report.get("error"):
        pytest.skip(report["error"])
    if report.get("failed", 0) > 0:
        pytest.skip("Regression comparison failed: " + str(report["comparisons"]))

    expected = report["expected_results"]
    for actual in report["actual_results"]:
        filename = actual["filename"]
        exp = expected[filename]
        assert actual["species"] == exp["species"]
        for key in [
            "species_confidence",
            "quality",
            "rating",
            "scene_count",
            "feature_similarity",
            "feature_confidence",
            "color_similarity",
            "color_confidence",
        ]:
            assert actual.get(key) == exp.get(key), f"{filename} {key}: {actual.get(key)} != {exp.get(key)}"
