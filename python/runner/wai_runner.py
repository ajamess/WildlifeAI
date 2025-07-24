#!/usr/bin/env python3
import argparse
import json
import logging
import sys
import os
from pathlib import Path

import numpy as np
from PIL import Image
import cv2
try:
    import onnxruntime as ort
except Exception:  # pragma: no cover - optional at runtime
    ort = None
try:
    from tensorflow import keras
except Exception:  # pragma: no cover - optional at runtime
    keras = None
try:
    import rawpy
except Exception:  # pragma: no cover - optional at runtime
    rawpy = None

ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "models"


def load_models():
    """Load ONNX and Keras models if present."""
    species_session = None
    quality_model = None
    labels = []

    if (MODEL_DIR / "labels.txt").exists():
        with open(MODEL_DIR / "labels.txt") as f:
            labels = [l.strip() for l in f if l.strip()]

    if ort and (MODEL_DIR / "model.onnx").exists():
        try:
            species_session = ort.InferenceSession(str(MODEL_DIR / "model.onnx"))
        except Exception as exc:  # pragma: no cover
            logging.error("Failed to load ONNX model: %s", exc)

    if keras and (MODEL_DIR / "quality.keras").exists():
        try:
            quality_model = keras.models.load_model(str(MODEL_DIR / "quality.keras"))
        except Exception as exc:  # pragma: no cover
            logging.error("Failed to load Keras model: %s", exc)

    return species_session, quality_model, labels


def load_image(path):
    """Load an image file into a 224x224 RGB numpy array."""
    ext = Path(path).suffix.lower()
    img = None
    if rawpy and ext in {".arw", ".cr2", ".nef", ".dng", ".rw2"}:
        try:
            with rawpy.imread(path) as raw:
                img = raw.postprocess(no_auto_bright=True, output_color=rawpy.ColorSpace.sRGB)
        except Exception as exc:  # pragma: no cover
            logging.warning("Failed to read RAW %s: %s", path, exc)
    if img is None:
        img = np.array(Image.open(path).convert("RGB"))

    img = cv2.resize(img, (224, 224))
    img = img.astype("float32") / 255.0
    return img


def predict(species_session, quality_model, labels, img_array):
    """Run models on the given image array."""
    detected_species = "Unknown"
    species_conf = 0.0
    quality_score = 0.0

    if species_session:
        input_name = species_session.get_inputs()[0].name
        data = np.expand_dims(img_array.transpose(2, 0, 1), 0)
        try:
            preds = species_session.run(None, {input_name: data})[0]
            idx = int(np.argmax(preds))
            species_conf = float(np.max(preds)) * 100
            if labels and 0 <= idx < len(labels):
                detected_species = labels[idx]
            else:
                detected_species = str(idx)
        except Exception as exc:  # pragma: no cover
            logging.error("ONNX inference failed: %s", exc)

    if quality_model:
        data = np.expand_dims(img_array, 0)
        try:
            q = quality_model.predict(data, verbose=0)[0]
            quality_score = float(q if np.isscalar(q) else q[0]) * (100.0 if q.max() <= 1.0 else 1.0)
        except Exception as exc:  # pragma: no cover
            logging.error("Keras inference failed: %s", exc)

    return detected_species, int(species_conf), int(quality_score)

def setup_log(path):
    logging.basicConfig(
        filename=path, level=logging.DEBUG,
        format="%(asctime)s [%(levelname)s] %(message)s"
    )
    logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--photo-list", required=True)
    ap.add_argument("--output-dir", required=True)
    ap.add_argument("--log-file", default=None)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.log_file:
        os.makedirs(Path(args.log_file).parent, exist_ok=True)
        setup_log(args.log_file)
    else:
        logging.basicConfig(level=logging.DEBUG)

    logging.info("Runner start")

    if args.self_test:
        out_dir = Path(args.output_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        out = out_dir / "selftest.json"
        out.write_text(json.dumps({"detected_species":"TestBird","species_confidence":99,"quality":88,"rating":4,
                                   "scene_count":1,"feature_similarity":80,"feature_confidence":90,
                                   "color_similarity":70,"color_confidence":65,"json_path":str(out)}))
        logging.info("Self-test JSON written %s", out)
        return 0

    with open(args.photo_list) as f:
        photos = [l.strip() for l in f if l.strip()]

    species_session, quality_model, labels = load_models()
    if not species_session:
        logging.warning("ONNX model unavailable; predictions will be dummy")
    if not quality_model:
        logging.warning("Keras model unavailable; predictions will be dummy")

    os.makedirs(args.output_dir, exist_ok=True)

    for p in photos:
        img_arr = load_image(p)
        species, s_conf, quality = predict(species_session, quality_model, labels, img_arr)
        out = Path(args.output_dir) / (Path(p).name + ".json")
        data = {
            "detected_species": species,
            "species_confidence": s_conf,
            "quality": quality,
            "rating": 0,
            "scene_count": 0,
            "feature_similarity": 0,
            "feature_confidence": 0,
            "color_similarity": 0,
            "color_confidence": 0,
            "json_path": str(out),
        }
        out.write_text(json.dumps(data))
        logging.debug("Wrote %s", out)

    logging.info("Runner done")
    return 0

if __name__ == "__main__":
    sys.exit(main())
