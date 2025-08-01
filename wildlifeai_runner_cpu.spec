# -*- mode: python ; coding: utf-8 -*-
import os
from pathlib import Path

# Get the current directory and set up paths
current_dir = Path.cwd()
python_dir = current_dir / "python" / "runner"
models_dir = current_dir / "models"

block_cipher = None

a = Analysis(
    [str(python_dir / 'wildlifeai_runner.py')],
    pathex=[str(current_dir)],
    binaries=[],
    datas=[
        (str(models_dir / 'model.onnx'), 'models'),
        (str(models_dir / 'quality.keras'), 'models'),
        (str(models_dir / 'labels.txt'), 'models'),
    ],
    hiddenimports=[
        # TensorFlow components (for quality classifier)
        'tensorflow',
        'tensorflow.keras',
        'tensorflow.keras.models',
        'tensorflow.keras.layers',
        'tensorflow.keras.utils',
        'tensorflow.python',
        'tensorflow.python.keras',
        'tensorflow.python.keras.models',
        'tensorflow.python.keras.layers',
        'tensorflow.python.keras.engine',
        'tensorflow.python.keras.engine.sequential',
        'tensorflow.python.keras.engine.functional',
        'tensorflow.python.saved_model',
        'tensorflow.python.saved_model.loader',
        'tensorflow.python.framework',
        'tensorflow.python.framework.ops',
        'tensorflow.python.ops',
        'tensorflow.python.platform',
        'tensorflow.python.platform.gfile',
        'tensorflow.lite',
        'keras',
        'keras.models',
        'keras.layers',
        'keras.utils',
        'keras.saving',
        'keras.saving.legacy',
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
    ],
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
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
