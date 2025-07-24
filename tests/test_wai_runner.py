import csv
import json
import subprocess
from pathlib import Path
import tempfile


def load_expected(csv_path: Path, out_dir: Path):
    expected = []
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            dest = out_dir / f"{Path(row['filename']).stem}.json"
            expected.append({
                "detected_species": row.get("species", ""),
                "species_confidence": int(float(row.get("species_confidence", 0)) * 100),
                "quality": int(float(row.get("quality", 0)) * 100),
                "rating": int(row.get("rating", 0)),
                "scene_count": int(row.get("scene_count", 0)),
                "feature_similarity": int(float(row.get("feature_similarity", 0)) * 100),
                "feature_confidence": int(float(row.get("feature_confidence", 0)) * 100),
                "color_similarity": int(float(row.get("color_similarity", 0)) * 100),
                "color_confidence": int(float(row.get("color_confidence", 0)) * 100),
                "json_path": str(dest),
            })
    return expected


def test_self_test_matches_csv():
    csv_path = Path("tests/quick/kestrel_database.csv")
    with tempfile.TemporaryDirectory() as tmpdir:
        subprocess.run([
            "python",
            "python/runner/wai_runner.py",
            "--self-test",
            "--photo-list",
            str(csv_path),
            "--output-dir",
            tmpdir,
        ], check=True)

        result_file = Path(tmpdir) / "selftest.json"
        data = json.loads(result_file.read_text())

        expected = load_expected(csv_path, Path(tmpdir))
        assert data == expected
