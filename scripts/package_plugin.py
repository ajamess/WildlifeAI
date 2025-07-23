import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / 'plugin' / 'WildlifeAI.lrplugin'
DIST = ROOT / 'dist'
DIST.mkdir(exist_ok=True)
shutil.make_archive(str(DIST/'WildlifeAI.lrplugin'), 'zip', PLUGIN)
print('Created dist/WildlifeAI.lrplugin.zip')
