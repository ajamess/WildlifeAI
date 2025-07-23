import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / 'plugin' / 'WildlifeAI.lrplugin'
DIST = ROOT / 'dist'
DIST.mkdir(exist_ok=True)

zip_base = DIST / 'WildlifeAI.lrplugin'
if zip_base.exists():
    if zip_base.is_dir():
        shutil.rmtree(zip_base)
    else:
        zip_base.unlink()

shutil.make_archive(str(zip_base), 'zip', PLUGIN)
print('Created', str(zip_base) + '.zip')
