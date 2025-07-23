#!/usr/bin/env python3
import argparse, json, os
from pathlib import Path
from kestrel_parser import to_lightroom_json

# TODO: wire to real ProjectKestrel. Placeholder simulate outputs.
def fake_analyze(path):
    # Simulate some values
    import random
    return {
        'species': 'Unknown',
        'species_confidence': random.randint(60, 99),
        'quality': random.randint(50, 100),
        'rating': random.randint(0, 100),
        'scene_count': random.randint(1, 5),
        'feature_similarity': random.randint(0, 100),
        'color_similarity': random.randint(0, 100),
        'color_confidence': random.randint(0, 100),
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--photo-list', required=True)
    ap.add_argument('--output-dir', required=True)
    args = ap.parse_args()

    with open(args.photo_list) as f:
        paths = [l.strip() for l in f if l.strip()]

    os.makedirs(args.output_dir, exist_ok=True)

    for p in paths:
        raw = fake_analyze(p)
        obj = to_lightroom_json(raw, p, args.output_dir)
        out_json = Path(p).with_suffix('.json')
        try:
            with open(out_json, 'w') as jf:
                json.dump(obj, jf, indent=2)
        except Exception:
            alt = Path(args.output_dir) / (Path(p).name + '.json')
            with open(alt, 'w') as jf:
                json.dump(obj, jf, indent=2)

if __name__ == '__main__':
    main()
