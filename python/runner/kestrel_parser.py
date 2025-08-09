from pathlib import Path


def to_lightroom_json(raw, src_path, output_dir):
    json_path = Path(output_dir) / Path(src_path).with_suffix('.json').name
    return {
        'source_path': src_path,
        'json_path': str(json_path),
        'detected_species': raw.get('detected_species') or raw.get('species', ''),
        'species_confidence': int(raw.get('species_confidence', 0)),
        'quality': int(raw.get('quality', 0)),
        'rating': int(raw.get('rating', 0)),
        'scene_count': int(raw.get('scene_count', 0)),
        'feature_similarity': int(raw.get('feature_similarity', 0)),
        'color_similarity': int(raw.get('color_similarity', 0)),
        'color_confidence': int(raw.get('color_confidence', 0)),
    }
