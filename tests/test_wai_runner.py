import csv
import json
import subprocess
from pathlib import Path
import shutil
import tempfile


def parse_expected(row, json_path: Path):
    return {
        "detected_species": row.get("species", ""),
        "species_confidence": int(float(row.get("species_confidence", 0)) * 100),
        "quality": int(float(row.get("quality", 0)) * 100),
        "rating": int(row.get("rating", 0)),
        "scene_count": int(row.get("scene_count", 0)),
        "feature_similarity": int(float(row.get("feature_similarity", 0)) * 100),
        "feature_confidence": int(float(row.get("feature_confidence", 0)) * 100),
        "color_similarity": int(float(row.get("color_similarity", 0)) * 100),
        "color_confidence": int(float(row.get("color_confidence", 0)) * 100),
        "json_path": str(json_path),
    }


def run_runner(csv_row, csv_header, out_dir: Path):
    single_csv = out_dir / "row.csv"
    with open(single_csv, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=csv_header)
        writer.writeheader()
        writer.writerow(csv_row)

    subprocess.run([
        "python",
        "python/runner/wai_runner.py",
        "--self-test",
        "--photo-list",
        str(single_csv),
        "--output-dir",
        str(out_dir),
    ], check=True)


def test_runner_against_database(capsys):
    tests_root = Path("tests")

    for folder in sorted(p for p in tests_root.iterdir() if p.is_dir()):
        csv_path = folder / "kestrel_database.csv"
        originals = folder / "original"
        if not csv_path.exists() or not originals.exists():
            continue

        with open(csv_path, newline="") as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            header = reader.fieldnames

        for row in rows:
            stem = Path(row["filename"]).stem
            with tempfile.TemporaryDirectory() as tmpdir:
                tmpdir_path = Path(tmpdir)
                run_runner(row, header, tmpdir_path)

                crop_src = folder / "crop" / f"{stem}_crop.jpg"
                export_src = folder / "export" / f"{stem}_export.jpg"
                if crop_src.exists():
                    shutil.copy(crop_src, tmpdir_path / f"{stem}_crop.jpg")
                if export_src.exists():
                    shutil.copy(export_src, tmpdir_path / f"{stem}_export.jpg")

                json_path = tmpdir_path / f"{stem}.json"
                data = json.loads(json_path.read_text())
                expected = parse_expected(row, json_path)

                for key, exp_val in expected.items():
                    got = data.get(key)
                    print(f"{folder.name} {row['filename']} {key}: got {got} expected {exp_val}")
                    assert got == exp_val

                print(f"PASS {folder.name} {row['filename']}")

    captured = capsys.readouterr()
    print(captured.out)
