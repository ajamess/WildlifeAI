#!/usr/bin/env python3
import argparse, json, logging, sys, os
from pathlib import Path

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
        out = Path(args.output_dir) / "selftest.json"
        out.write_text(json.dumps({"detected_species":"TestBird","species_confidence":99,"quality":88,"rating":4,
                                   "scene_count":1,"feature_similarity":80,"feature_confidence":90,
                                   "color_similarity":70,"color_confidence":65,"json_path":str(out)}))
        logging.info("Self-test JSON written %s", out)
        return 0

    with open(args.photo_list) as f:
        photos = [l.strip() for l in f if l.strip()]

    # TODO: integrate ProjectKestrel ported pipeline here
    # For now, emit dummy JSON so Lightroom path can be tested
    for p in photos:
        out = Path(args.output_dir) / (Path(p).name + ".json")
        data = {"detected_species":"Unknown","species_confidence":0,"quality":0,"rating":0,
                "scene_count":0,"feature_similarity":0,"feature_confidence":0,
                "color_similarity":0,"color_confidence":0,"json_path":str(out)}
        out.write_text(json.dumps(data))
        logging.debug("Wrote %s", out)

    logging.info("Runner done")
    return 0

if __name__ == "__main__":
    sys.exit(main())
