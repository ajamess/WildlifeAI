import shutil
from pathlib import Path
root = Path(__file__).resolve().parents[1]
plugin = root/'plugin'/'WildlifeAI.lrplugin'
dist = root/'dist'; dist.mkdir(exist_ok=True)
zipbase = dist/'WildlifeAI.lrplugin'
if zipbase.with_suffix('.zip').exists(): zipbase.with_suffix('.zip').unlink()
shutil.make_archive(str(zipbase), 'zip', plugin)
print('Created', zipbase.with_suffix('.zip'))
