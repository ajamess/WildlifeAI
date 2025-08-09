# -*- mode: python ; coding: utf-8 -*-
import os
from pathlib import Path
from PyInstaller.utils.hooks import collect_all, collect_dynamic_libs

# Collect additional data, binaries, and hidden imports
tf_datas, tf_bins, tf_hidden = collect_all("tensorflow")
ort_datas, ort_bins, ort_hidden = collect_all("onnxruntime")
keras_datas, keras_bins, keras_hidden = collect_all("keras")
torch_bins = collect_dynamic_libs("torch")
rawpy_bins = collect_dynamic_libs("rawpy")
# Collect Microsoft runtime and OpenMP libraries if present
runtime_bins = []
for lib in ["msvcp140", "vcruntime140", "libiomp5md"]:
    try:
        runtime_bins += collect_dynamic_libs(lib)
    except Exception:
        pass

# Get the current directory and set up paths
current_dir = Path.cwd()
python_dir = current_dir / "python" / "runner"
models_dir = current_dir / "models"

block_cipher = None

# Base lists for Analysis inputs
datas = [
    (str(models_dir / 'model.onnx'), 'models'),
    (str(models_dir / 'quality.keras'), 'models'),
    (str(models_dir / 'labels.txt'), 'models'),
]
binaries = []
hiddenimports = [
    # TensorFlow components (for quality classifier)
    'tensorflow',
    'tensorflow.lite',
    'keras',
    'keras.models',
    'keras.layers',
    'keras.utils',
    'keras.saving',
    # ONNX Runtime
    'onnxruntime',
    # Core Python libraries
    'numpy',
    'PIL',
    'cv2',
    'rawpy',
    'logging',
    'json',
    'csv',
    'argparse',
    'pathlib',
    'concurrent.futures',
    'time',
    'sys',
    'os',
    # PyTorch components (for Mask R-CNN)
    'torch',
    'torchvision',
    'torchvision.models',
    'torchvision.models.detection',
    'torchvision.models.detection.maskrcnn_resnet50_fpn',
    'torchvision.transforms',
    'torch.nn',
    'torch.nn.functional'
]

# Append collected items
datas += tf_datas + ort_datas + keras_datas
binaries += tf_bins + ort_bins + keras_bins + torch_bins + runtime_bins + rawpy_bins
hiddenimports += tf_hidden + ort_hidden + keras_hidden

a = Analysis(
    [str(python_dir / 'wildlifeai_runner.py')],
    pathex=[str(current_dir)],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'onnxruntime-gpu'
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='wildlifeai_runner_cpu',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
