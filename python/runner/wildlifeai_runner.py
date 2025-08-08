#!/usr/bin/env python3
import argparse
import csv
import json
import logging
import sys
import os
import time
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

import numpy as np
from PIL import Image
import cv2
try:
    import torchvision
    import torch
    import torchvision.transforms as T
except ImportError:
    torchvision = None
    torch = None
    T = None
try:
    import onnxruntime as ort
except ImportError:
    ort = None

# Try to import TensorFlow directly for PyInstaller compatibility
try:
    import tensorflow as tf
    from tensorflow import keras
    _tensorflow_available = True
except ImportError:
    tf = None
    keras = None
    _tensorflow_available = False

def load_tensorflow():
    """Load TensorFlow - for PyInstaller builds, it should already be imported."""
    global tf, keras, _tensorflow_available
    
    # Force reimport attempt for PyInstaller compatibility
    try:
        import tensorflow as _tf
        from tensorflow import keras as _keras
        tf = _tf
        keras = _keras
        _tensorflow_available = True
        logging.debug(f"TensorFlow loaded successfully: {tf.__version__}")
        return True
    except ImportError as e:
        logging.error(f"Failed to import TensorFlow: {e}")
        tf = None
        keras = None
        _tensorflow_available = False
        return False
try:
    import rawpy
except ImportError:
    rawpy = None
try:
    from wand.image import Image as WandImage
except ImportError:
    WandImage = None

ROOT = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parents[2]))
MODEL_DIR = ROOT / "models"


def find_model_directory():
    """Find the models directory in various possible locations derived from ROOT."""
    candidates = [
        MODEL_DIR,
        ROOT.parent / "models",
        ROOT.parent.parent / "models",
    ]

    for candidate in candidates:
        if (candidate / "model.onnx").exists() and (candidate / "quality.keras").exists():
            return candidate

    # Return the default and let the calling code handle missing files
    return MODEL_DIR

def read_image(path):
    """Uses ImageMagick to read any input image and returns nparray of image contents in height x width x RGB"""
    if WandImage:
        try:
            # Use ImageMagick with orientation correction (original implementation)
            with WandImage(filename=path) as img:
                if img.orientation == 'left_bottom':
                    img.rotate(270)
                elif img.orientation == 'right_bottom':
                    img.rotate(90)
                elif img.orientation == 'bottom':
                    img.rotate(180)
                elif img.orientation == 'top':
                    pass  # No rotation needed
                return np.array(img)
        except Exception as exc:
            logging.warning(f"Wand failed for {path}, falling back to rawpy/PIL: {exc}")
    
    # Fallback to rawpy/PIL approach
    ext = Path(path).suffix.lower()
    img = None
    
    # Handle RAW files
    if rawpy and ext in {".arw", ".cr2", ".nef", ".dng", ".rw2"}:
        try:
            with rawpy.imread(path) as raw:
                img = raw.postprocess(no_auto_bright=True, output_color=rawpy.ColorSpace.sRGB)
            logging.debug(f"Loaded RAW file: {path}")
            return img
        except Exception as exc:
            logging.error(f"Failed to load RAW file {path}: {exc}")
            # Try fallback to PIL for preview
            try:
                img_pil = Image.open(path)
                img = np.array(img_pil.convert('RGB'))
                logging.warning(f"Using PIL preview for RAW file: {path}")
                return img
            except Exception as exc2:
                logging.error(f"Failed to load RAW preview: {exc2}")
                return None
    else:
        # Handle regular image files
        try:
            img_pil = Image.open(path)
            img = np.array(img_pil.convert('RGB'))
            return img
        except Exception as exc:
            logging.error(f"Failed to load image {path}: {exc}")
            return None

def compute_image_similarity_akaze(img1, img2, max_dim=1600):
    """Compute image similarity using AKAZE features (exact original implementation)."""
    if img1 is None or img2 is None:
        return {
            'feature_similarity': -1,
            'feature_confidence': -1,
            'color_similarity': -1,
            'color_confidence': -1,
            'similar': False,
            'confidence': 0
        }
    if img1.shape != img2.shape:
        return {
            'feature_similarity': -1,
            'feature_confidence': -1,
            'color_similarity': -1,
            'color_confidence': -1,
            'similar': False,
            'confidence': 0
        }
    try:
        # Resize for speed
        def resize(img):
            h, w = img.shape[:2]
            scale = max_dim / max(h, w)
            if scale < 1.0:
                img = cv2.resize(img, (int(w*scale), int(h*scale)), interpolation=cv2.INTER_AREA)
            return img
        img1 = resize(img1)
        img2 = resize(img2)

        # Convert to grayscale for AKAZE
        gray1 = cv2.cvtColor(img1, cv2.COLOR_RGB2GRAY) if img1.ndim == 3 else img1
        gray2 = cv2.cvtColor(img2, cv2.COLOR_RGB2GRAY) if img2.ndim == 3 else img2

        akaze = cv2.AKAZE_create()
        kp1, des1 = akaze.detectAndCompute(gray1, None)
        kp2, des2 = akaze.detectAndCompute(gray2, None)

        # Keep best 300 keypoints
        if des1 is not None and len(kp1) > 300:
            kp1, des1 = zip(*sorted(zip(kp1, des1), key=lambda x: x[0].response, reverse=True)[:300])
            kp1 = list(kp1)
            des1 = np.array(des1)

        if des2 is not None and len(kp2) > 300:
            kp2, des2 = zip(*sorted(zip(kp2, des2), key=lambda x: x[0].response, reverse=True)[:300])
            kp2 = list(kp2)
            des2 = np.array(des2)

        # Compute feature confidence as minimum of keypoints detected
        feature_confidence = min(len(kp1), len(kp2)) / 300

        # if feature confidence is low, fall back to color similarity
        if feature_confidence < 0.25 or des1 is None or des2 is None or len(kp1) == 0 or len(kp2) == 0:
            mean1 = np.mean(img1.reshape(-1, img1.shape[-1]), axis=0)
            mean2 = np.mean(img2.reshape(-1, img2.shape[-1]), axis=0)
            color_diff = np.sum(np.abs(mean1 - mean2))
            return {
                'feature_similarity': 0,
                'feature_confidence': 0,
                'color_similarity': color_diff,
                'color_confidence': abs((768 - color_diff) / 768) if color_diff <= 150 else abs(color_diff / 768),
                'similar': color_diff <= 150,
                'confidence': abs((768 - color_diff) / 768) if color_diff <= 150 else abs(color_diff / 768)
            }
        
        # Match features using BFMatcher
        bf = cv2.BFMatcher(cv2.NORM_HAMMING)
        matches = bf.knnMatch(des1, des2, k=2)
        m_arr = np.array([m.distance for m, n in matches])
        n_arr = np.array([n.distance for m, n in matches])

        # Vectorized Lowe's ratio test
        good_mask = m_arr < 0.7 * n_arr

        # Compute feature similarity
        feature_similarity = np.sum(good_mask) / ((len(kp1) + len(kp2)) / 2) if (len(kp1) + len(kp2)) > 0 else 0
        
        similar = feature_similarity >= 0.05
        return {
            'feature_similarity': feature_similarity,
            'feature_confidence': feature_confidence,
            'color_similarity': 0,
            'color_confidence': 0,
            'similar': similar,
            'confidence': feature_confidence
        }
    except Exception as e:
        logging.error(f"Error in compute_image_similarity_akaze: {e}")
        return {
            'feature_similarity': -1,
            'feature_confidence': -1,
            'color_similarity': -1,
            'color_confidence': -1,
            'similar': False,
            'confidence': 0
        }

class MaskRCNN:
    """Mask R-CNN for bird detection (exact original implementation)."""
    
    def __init__(self):
        if not torchvision:
            logging.error("PyTorch/torchvision not available for Mask R-CNN")
            self.model = None
            return
            
        self.COCO_INSTANCE_CATEGORY_NAMES = [
            '__background__', 'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus',
            'train', 'truck', 'boat', 'traffic light', 'fire hydrant', 'N/A', 'stop sign',
            'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep', 'cow',
            'elephant', 'bear', 'zebra', 'giraffe', 'N/A', 'backpack', 'umbrella', 'N/A', 'N/A',
            'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball',
            'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
            'bottle', 'N/A', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl',
            'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza',
            'donut', 'cake', 'chair', 'couch', 'potted plant', 'bed', 'N/A', 'dining table',
            'N/A', 'N/A', 'toilet', 'N/A', 'tv', 'laptop', 'mouse', 'remote', 'keyboard', 'cell phone',
            'microwave', 'oven', 'toaster', 'sink', 'refrigerator', 'N/A', 'book',
            'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
        ]
        
        try:
            self.model = torchvision.models.detection.maskrcnn_resnet50_fpn_v2(
                weights=torchvision.models.detection.MaskRCNN_ResNet50_FPN_V2_Weights.DEFAULT
            )
            self.model.eval()
            logging.info("Mask R-CNN model loaded successfully")
        except Exception as exc:
            logging.error(f"Failed to load Mask R-CNN: {exc}")
            self.model = None
    
    def get_prediction(self, image_data, threshold=0.2):
        """Perform Object Detection on the given image using Mask-RCNN (exact original implementation)."""
        if self.model is None:
            return None, None, None, None
            
        try:
            transform = T.Compose([T.ToTensor()])
            img = transform(image_data)
            
            # Perform inference
            with torch.no_grad():
                pred = self.model([img])
            
            # Extract confidence scores
            pred_score = list(pred[0]['scores'].detach().numpy())
            
            # Filter predictions based on threshold
            if (np.array(pred_score) > threshold).sum() == 0:
                return None, None, None, None
            
            pred_t = [pred_score.index(x) for x in pred_score if x > threshold][-1]
            
            # Extract masks, class labels, and bounding boxes
            masks = (pred[0]['masks'] > 0.5).squeeze().detach().cpu().numpy()
            
            if len(masks.shape) == 2:
                masks = np.expand_dims(masks, axis=0)
                
            pred_class = [self.COCO_INSTANCE_CATEGORY_NAMES[i] for i in list(pred[0]['labels'].numpy())]
            pred_boxes = [[(i[0], i[1]), (i[2], i[3])] for i in list(pred[0]['boxes'].detach().numpy())]
            
            # Keep only predictions above threshold
            masks = masks[:pred_t + 1]
            pred_boxes = pred_boxes[:pred_t + 1]
            pred_class = pred_class[:pred_t + 1]
            
            return masks, pred_boxes, pred_class, pred_score[:pred_t + 1]
            
        except Exception as exc:
            logging.error(f"Mask R-CNN prediction failed: {exc}")
            return None, None, None, None
    
    def _get_center_of_mass(self, mask):
        """Get center of mass of mask (exact original implementation)."""
        y, x = np.where(mask > 0)
        center_of_mass = (int(np.mean(x)), int(np.mean(y)))
        return center_of_mass

    def _fsolve(self, func, xmin, xmax):
        """Binary search for root finding (exact original implementation)."""
        def f(x):
            return func(x)

        x_min = xmin
        x_max = xmax

        while x_max - x_min > 10:
            x_mid = (x_min + x_max) / 2
            if f(x_mid) < 0:
                x_min = x_mid
            else:
                x_max = x_mid

        return (x_min + x_max) / 2

    def _get_bounding_box(self, mask):
        """Get optimal bounding box (exact original implementation)."""
        center_of_mass = self._get_center_of_mass(mask)

        def get_fraction_inside(center_of_mass, S):
            x_min = int(center_of_mass[0] - S / 2)
            x_max = int(center_of_mass[0] + S / 2)
            y_min = int(center_of_mass[1] - S / 2)
            y_max = int(center_of_mass[1] + S / 2)

            x_min = max(0, x_min)
            x_max = min(mask.shape[1], x_max)
            y_min = max(0, y_min)
            y_max = min(mask.shape[0], y_max)

            fraction_inside = np.sum(mask[y_min:y_max, x_min:x_max]) / np.sum(mask)
            return fraction_inside
        
        # Find the side length S such that 80% of the mask is inside the central 60% of the bounding box
        S = self._fsolve(lambda S: get_fraction_inside(center_of_mass, S) - 0.8, 10, 3000)
        S = int(S*1/0.5)

        # Get the bounding box
        x_min = int(center_of_mass[0] - S / 2)
        x_max = int(center_of_mass[0] + S / 2)
        y_min = int(center_of_mass[1] - S / 2)
        y_max = int(center_of_mass[1] + S / 2)

        # Make sure the bounding box is inside the image
        x_min = max(0, x_min)
        x_max = min(mask.shape[1], x_max)
        y_min = max(0, y_min)
        y_max = min(mask.shape[0], y_max)

        # Make sure the bounding box is square
        SLX = x_max - x_min
        SLY = y_max - y_min

        if(SLX > SLY):
            center_of_mass = (int((x_min + x_max) / 2), int((y_min + y_max) / 2))
            S_new = SLY
            x_min = int(center_of_mass[0] - S_new / 2)
            x_max = int(center_of_mass[0] + S_new / 2)
            y_min = int(center_of_mass[1] - S_new / 2)
            y_max = int(center_of_mass[1] + S_new / 2)
        else:
            center_of_mass = (int((x_min + x_max) / 2), int((y_min + y_max) / 2))
            S_new = SLX
            x_min = int(center_of_mass[0] - S_new / 2)
            x_max = int(center_of_mass[0] + S_new / 2)
            y_min = int(center_of_mass[1] - S_new / 2)
            y_max = int(center_of_mass[1] + S_new / 2)

        return x_min, x_max, y_min, y_max
    
    def get_square_crop(self, mask, img, resize=True):
        """Get a square crop around the mask for quality estimation (exact original implementation)."""
        x_min, x_max, y_min, y_max = self._get_bounding_box(mask)

        crop = img[y_min:y_max, x_min:x_max]
        mask_crop = mask[y_min:y_max, x_min:x_max]

        if resize:
            crop = cv2.resize(crop,(1024,1024))
            mask_crop = cv2.resize(mask_crop.astype(np.uint8),(1024,1024))

        return crop, mask_crop

    def get_species_crop(self, box, img):
        """Get the crop for the bird species classifier (exact original implementation)."""
        xmin, xmax, ymin, ymax = box[0][0].astype(int), box[1][0].astype(int), box[0][1].astype(int), box[1][1].astype(int)
        species_classifier_crop = img[ymin:ymax, xmin:xmax]
        return species_classifier_crop

class BirdSpeciesClassifier:
    """Bird species classifier (exact original implementation)."""
    
    def __init__(self, model_path, labels_path, onnx_providers):
        self.model_path = model_path
        self.labels_path = labels_path
        with open(labels_path, "r") as f:
            self.labels = [line.strip() for line in f.readlines()]
            self.labels = np.array(self.labels)

        self.session = ort.InferenceSession(self.model_path, providers=onnx_providers)
    
    def _preprocess_image(self, image):
        """Preprocess the image data to the model input tensor dimensions (exact original implementation)."""
        image = cv2.resize(image, dsize=(300,300)).astype(np.float32)
        image = np.transpose(image, (2, 0, 1))
        image = np.expand_dims(image, axis=0)
        return image
    
    def classify_bird(self, image, top_k=5):
        """Run Bird species Classifier on the image (exact original implementation)."""
        input_tensor = self._preprocess_image(image)
        input_name = self.session.get_inputs()[0].name
        outputs = self.session.run(None, {input_name: input_tensor})
        
        top_k_indices = np.argsort(outputs[0][0])[-top_k:][::-1]
        top_k_scores = outputs[0][0][top_k_indices]
        
        predicted_class_index = np.argmax(outputs[0][0])
        predicted_label = self.labels[predicted_class_index]
        confidence = outputs[0][0][predicted_class_index]
        top_k_labels = self.labels[top_k_indices]
        
        return predicted_label, confidence, top_k_labels, top_k_scores

class QualityClassifier:
    """Quality classifier (exact original implementation)."""
    
    def __init__(self, model_path):
        self.model_path = model_path
        self.model = tf.keras.models.load_model(self.model_path)
        
    def _preprocess_image_classifier(self, cropped_img, cropped_mask):
        """Preprocess image for quality classification (exact original implementation)."""
        img = cv2.cvtColor(cropped_img, cv2.COLOR_RGB2GRAY)
        sobel_x = cv2.Sobel(img, cv2.CV_32F, 1, 0, ksize=5)
        sobel_y = cv2.Sobel(img, cv2.CV_32F, 0, 1, ksize=5)
        img = np.sqrt(sobel_x**2 + sobel_y**2)
        img1 = cv2.bitwise_and(img, img, mask=cropped_mask.astype(np.uint8))
        images = np.array([img1]).transpose(1,2,0)
        return images

    def classify_quality(self, cropped_image, cropped_mask, retry=5):
        """Classify the quality of an image (exact original implementation)."""
        for _ in range(retry):
            try:
                input_data = self._preprocess_image_classifier(cropped_image, cropped_mask)
                output_value = self.model.predict(np.expand_dims(input_data, axis=0), verbose=0)
                return output_value[0][0]
            except Exception as e:
                logging.error(f"Error during quality classification: {e}")
        return -1

class EnhancedModelRunner:
    def __init__(self, use_gpu: bool = False, max_workers: int = 4):
        self.use_gpu = use_gpu
        self.max_workers = max_workers
        self.mask_rcnn = None
        self.species_classifier = None
        self.quality_classifier = None
        self.previous_image = None
        self.scene_count = self._load_global_scene_count()
        self._state_lock = threading.Lock()
        
        # Find the actual model directory
        self.model_dir = find_model_directory()
        logging.info(f"Using model directory: {self.model_dir}")
        
        # Check model files exist
        onnx_path = self.model_dir / "model.onnx"
        keras_path = self.model_dir / "quality.keras"
        labels_path = self.model_dir / "labels.txt"
        
        logging.info(f"ONNX model exists: {onnx_path.exists()} at {onnx_path}")
        logging.info(f"Keras model exists: {keras_path.exists()} at {keras_path}")
        logging.info(f"Labels file exists: {labels_path.exists()} at {labels_path}")
        
        # Configure providers and load models
        self.onnx_providers = self._get_onnx_providers()
        self._load_models()

    def _get_onnx_providers(self) -> List[str]:
        """Get ONNX Runtime providers based on GPU preference."""
        if not ort:
            return []
            
        available_providers = ort.get_available_providers()
        logging.info(f"Available ONNX providers: {available_providers}")
        
        providers = []
        if self.use_gpu:
            # Prefer GPU providers
            gpu_providers = ['CUDAExecutionProvider', 'DmlExecutionProvider', 'CoreMLExecutionProvider']
            for provider in gpu_providers:
                if provider in available_providers:
                    providers.append(provider)
                    break
        
        # Always add CPU as fallback
        if 'CPUExecutionProvider' in available_providers:
            providers.append('CPUExecutionProvider')
            
        logging.info(f"Using ONNX providers: {providers}")
        return providers

    def _load_global_scene_count(self) -> int:
        """Load the global scene counter from persistent storage."""
        try:
            # Store scene count in user's temp directory
            import tempfile
            scene_file = Path(tempfile.gettempdir()) / "wildlifeai_scene_count.txt"
            
            if scene_file.exists():
                with open(scene_file, 'r') as f:
                    count = int(f.read().strip())
                    logging.info(f"Loaded global scene count: {count}")
                    return count
            else:
                logging.info("No existing scene count found, starting from 0")
                return 0
        except Exception as e:
            logging.warning(f"Failed to load scene count: {e}, starting from 0")
            return 0
    
    def _save_global_scene_count(self):
        """Save the current scene count to persistent storage."""
        try:
            import tempfile
            scene_file = Path(tempfile.gettempdir()) / "wildlifeai_scene_count.txt"
            
            with open(scene_file, 'w') as f:
                f.write(str(self.scene_count))
            logging.debug(f"Saved global scene count: {self.scene_count}")
        except Exception as e:
            logging.warning(f"Failed to save scene count: {e}")

    def _configure_tensorflow_gpu(self):
        """Configure TensorFlow GPU usage."""
        if not tf:
            return
            
        try:
            gpus = tf.config.experimental.list_physical_devices('GPU')
            if gpus and self.use_gpu:
                # Enable memory growth for all GPUs
                for gpu in gpus:
                    tf.config.experimental.set_memory_growth(gpu, True)
                logging.info(f"TensorFlow GPU enabled with {len(gpus)} GPU(s)")
            else:
                # Force CPU usage
                tf.config.set_visible_devices([], 'GPU')
                logging.info("TensorFlow using CPU")
        except Exception as exc:
            logging.warning(f"TensorFlow GPU configuration failed: {exc}")

    def _load_models(self):
        """Load all models (exact original implementation)."""
        # Load Mask R-CNN for bird detection
        self.mask_rcnn = MaskRCNN()
        
        # Load ONNX model for species detection
        onnx_path = self.model_dir / "model.onnx"
        labels_path = self.model_dir / "labels.txt"
        if ort and onnx_path.exists() and labels_path.exists():
            try:
                self.species_classifier = BirdSpeciesClassifier(
                    str(onnx_path), 
                    str(labels_path), 
                    self.onnx_providers
                )
                logging.info(f"ONNX species classifier loaded")
            except Exception as exc:
                logging.error(f"Failed to load ONNX species classifier: {exc}")

        # Load Keras model for quality assessment (with lazy loading)
        keras_path = self.model_dir / "quality.keras"
        if keras_path.exists():
            try:
                if load_tensorflow():
                    self._configure_tensorflow_gpu()
                    self.quality_classifier = QualityClassifier(str(keras_path))
                    logging.info("Keras quality classifier loaded")
                else:
                    logging.warning("TensorFlow not available for quality classifier")
            except Exception as exc:
                logging.error(f"Failed to load Keras quality classifier: {exc}")

    def predict_single(self, photo_path: str) -> Tuple[str, float, float, Dict, int]:
        """Run inference on a single image (exact original implementation logic)."""
        try:
            # Read the image using ImageMagick (original approach)
            img = read_image(photo_path)
            
            if img is None:
                logging.warning(f"Failed to read image: {photo_path}")
                return "Failed to Read", 0, -1, {
                    'feature_similarity': -1,
                    'feature_confidence': -1,
                    'color_similarity': -1,
                    'color_confidence': -1,
                    'similar': False,
                    'confidence': 0
                }
            
            # Compute similarity with previous image for scene detection
            with self._state_lock:
                similarity = compute_image_similarity_akaze(self.previous_image, img)
                if not similarity['similar']:
                    self.scene_count += 1
                self.previous_image = img.copy()
                current_scene = self.scene_count
            
            # Get predictions from Mask-RCNN
            if not self.mask_rcnn or self.mask_rcnn.model is None:
                return "No Bird", 0, -1, similarity
                
            masks, pred_boxes, pred_class, pred_score = self.mask_rcnn.get_prediction(img)
            
            if masks is None or pred_boxes is None or pred_class is None or pred_score is None:
                logging.debug(f"No valid predictions found in {photo_path}")
                return "No Bird", 0, -1, similarity
            
            # Find bird predictions
            bird_indices = [i for i, c in enumerate(pred_class) if c == 'bird']
            
            if not bird_indices:
                logging.debug(f"No bird predictions found in {photo_path}")
                return "No Bird", 0, -1, similarity
            
            # Get highest confidence bird
            highest_confidence_index = bird_indices[np.argmax([pred_score[i] for i in bird_indices])]
            best_mask = masks[highest_confidence_index]
            best_box = pred_boxes[highest_confidence_index]
            
            species = "Unknown"
            species_confidence = 0
            quality_score = -1
            
            # Species classification on bird crop
            if self.species_classifier:
                try:
                    species_crop = self.mask_rcnn.get_species_crop(best_box, img)
                    if species_crop.size > 0:
                        species, species_confidence, _, _ = self.species_classifier.classify_bird(species_crop)
                        logging.debug(f"Species prediction: {species} ({int(species_confidence * 100)}%)")
                except Exception as exc:
                    logging.error(f"Species prediction failed: {exc}")
            
            # Quality classification on square crop
            if self.quality_classifier:
                try:
                    quality_crop, quality_mask = self.mask_rcnn.get_square_crop(best_mask, img, resize=True)
                    
                    if quality_crop is not None and quality_mask is not None:
                        quality_score = self.quality_classifier.classify_quality(quality_crop, quality_mask)
                        logging.debug(f"Quality prediction: {int(quality_score * 100) if quality_score != -1 else quality_score}")
                except Exception as exc:
                    logging.error(f"Quality prediction failed: {exc}")
            
            return species, species_confidence, quality_score, similarity, current_scene
            
        except Exception as e:
            logging.error(f"Error processing {photo_path}: {e}")
            with self._state_lock:
                current_scene = self.scene_count
            return "No Bird", 0, -1, {
                'feature_similarity': -1,
                'feature_confidence': -1,
                'color_similarity': -1,
                'color_confidence': -1,
                'similar': False,
                'confidence': 0
            }, current_scene

    def process_photo(self, photo_path: str, output_dir: Path, generate_crops: bool = True) -> Dict:
        """Process a single photo and return results (enhanced with full similarity data)."""
        start_time = time.time()
        
        # Run inference
        species, species_confidence, quality_score, similarity, scene_count = self.predict_single(photo_path)
        
        # Generate outputs if requested
        export_path = ""
        crop_path = ""
        
        if generate_crops and output_dir:
            try:
                # Create output directories
                export_dir = output_dir / "export"
                crop_dir = output_dir / "crop"
                export_dir.mkdir(parents=True, exist_ok=True)
                crop_dir.mkdir(parents=True, exist_ok=True)
                
                # Load original image for export/crop using our RAW-capable read_image function
                try:
                    # Use the same read_image function that handles RAW files properly
                    img_array = read_image(photo_path)
                    
                    if img_array is not None:
                        # Convert numpy array to PIL Image
                        original_img = Image.fromarray(img_array.astype('uint8'))
                        if original_img.mode != 'RGB':
                            original_img = original_img.convert('RGB')
                        
                        # Create export (resized version)
                        filename_stem = Path(photo_path).stem
                        export_filename = f"{filename_stem}_export.jpg"
                        export_path = export_dir / export_filename
                        
                        # Resize maintaining aspect ratio
                        original_img.thumbnail((1920, 1920), Image.Resampling.LANCZOS)
                        original_img.save(export_path, "JPEG", quality=85)
                        logging.debug(f"Created export: {export_path}")
                        
                        # Create crop (center crop for now - could be enhanced with detection)
                        crop_filename = f"{filename_stem}_crop.jpg"
                        crop_path = crop_dir / crop_filename
                        
                        # Simple center crop 
                        width, height = original_img.size
                        crop_size = min(width, height)
                        left = (width - crop_size) // 2
                        top = (height - crop_size) // 2
                        right = left + crop_size
                        bottom = top + crop_size
                        
                        cropped = original_img.crop((left, top, right, bottom))
                        cropped = cropped.resize((300, 300), Image.Resampling.LANCZOS)
                        cropped.save(crop_path, "JPEG", quality=85)
                        logging.debug(f"Created crop: {crop_path}")
                    else:
                        logging.warning(f"Could not read image for crop generation: {photo_path}")
                        
                except Exception as exc:
                    logging.warning(f"Failed to generate crop for {photo_path}: {exc}")
                    
            except Exception as exc:
                logging.warning(f"Failed to create output directories: {exc}")
        
        # Calculate rating based on quality score (exact original logic)
        rating = 0
        if quality_score == -1:
            rating = 0
        elif quality_score < 0.15:
            rating = 1
        elif quality_score < 0.3:
            rating = 2
        elif quality_score < 0.6:
            rating = 3
        elif quality_score < 0.9:
            rating = 4
        else:
            rating = 5
            
        processing_time = time.time() - start_time
        
        # Convert values to match original format with proper percentage conversion
        converted_species_confidence = int(float(species_confidence) * 100) if species_confidence != 0 else 0
        converted_quality = int(quality_score * 100) if quality_score != -1 else -1
        converted_feature_similarity = int(similarity.get('feature_similarity', 0) * 100) if similarity.get('feature_similarity', 0) > 0 else int(similarity.get('feature_similarity', 0))
        converted_feature_confidence = int(similarity.get('feature_confidence', 0) * 100) if similarity.get('feature_confidence', 0) > 0 else int(similarity.get('feature_confidence', 0))
        converted_color_similarity = int(similarity.get('color_similarity', 0))
        converted_color_confidence = int(similarity.get('color_confidence', 0) * 100) if similarity.get('color_confidence', 0) > 0 else int(similarity.get('color_confidence', 0))
        
        
        result = {
            "filename": Path(photo_path).name,
            "species": species,
            "species_confidence": converted_species_confidence,
            "quality": converted_quality,
            "export_path": str(export_path) if export_path else "",
            "crop_path": str(crop_path) if crop_path else "",
            "rating": rating,
            "scene_count": scene_count,
            "feature_similarity": converted_feature_similarity,
            "feature_confidence": converted_feature_confidence,
            "color_similarity": converted_color_similarity,
            "color_confidence": converted_color_confidence,
            "processing_time": processing_time
        }
        
        # Enhanced logging to show both raw and converted values for debugging
        logging.info(f"Processed {Path(photo_path).name}: Species: {species}, Confidence: {result['species_confidence']}, Quality: {result['quality']}, Rating: {rating}, Similarity: {similarity.get('similar', False)}, Scene Count: {scene_count}")
        
        # Always show detailed results for debugging/regression testing
        logging.info(f"Raw Values - Species Conf: {species_confidence:.6f}, Quality: {quality_score:.6f}")
        logging.info(f"Converted Values - Species Conf: {result['species_confidence']}, Quality: {result['quality']}")
        logging.info(f"Similarity Raw - Feature: {similarity.get('feature_similarity', 0):.6f}, Feature Conf: {similarity.get('feature_confidence', 0):.6f}, Color: {similarity.get('color_similarity', 0):.6f}, Color Conf: {similarity.get('color_confidence', 0):.6f}")
        logging.info(f"Similarity Converted - Feature: {result['feature_similarity']}, Feature Conf: {result['feature_confidence']}, Color: {result['color_similarity']}, Color Conf: {result['color_confidence']}")
        
        return result

    def process_batch(self, photo_paths: List[str], output_dir: Path,
                     generate_crops: bool = True, progress_callback: Optional[callable] = None) -> List[Dict]:
        """Process multiple photos concurrently."""
        results: List[Dict] = []
        results_file = output_dir / "results.json"
        status_file = output_dir / "status.json"

        status = {
            "status": "processing",
            "start_time": time.strftime("%Y-%m-%d %H:%M:%S"),
            "total_photos": len(photo_paths),
            "processed": 0,
            "current_photo": "",
            "progress_percent": 0
        }
        try:
            with open(status_file, 'w') as f:
                json.dump(status, f, indent=2)
            logging.info(f"Created status file: {status_file}")
        except Exception as e:
            logging.warning(f"Failed to create status file: {e}")

        file_lock = threading.Lock()

        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            future_to_photo = {
                executor.submit(self.process_photo, path, output_dir, generate_crops): path
                for path in photo_paths
            }

            for i, future in enumerate(as_completed(future_to_photo), 1):
                photo_path = future_to_photo[future]
                try:
                    result = future.result()
                except Exception as exc:
                    logging.error(f"Failed to process {photo_path}: {exc}")
                    result = {
                        "filename": Path(photo_path).name,
                        "species": "Unknown",
                        "species_confidence": 0,
                        "quality": 0,
                        "error": str(exc)
                    }
                with file_lock:
                    results.append(result)

                    try:
                        with open(results_file, 'w') as f:
                            json.dump(results, f, indent=2, default=str)
                        logging.debug(f"Updated results.json with {len(results)} results")
                    except Exception as e:
                        logging.warning(f"Failed to write results file: {e}")

                    status.update({
                        "processed": i,
                        "current_photo": Path(photo_path).name,
                        "progress_percent": (i / len(photo_paths)) * 100
                    })
                    try:
                        with open(status_file, 'w') as f:
                            json.dump(status, f, indent=2)
                    except Exception as e:
                        logging.warning(f"Failed to update status file: {e}")

                if progress_callback:
                    progress_callback(i, len(photo_paths), Path(photo_path).name)

        status.update({
            "status": "completed",
            "end_time": time.strftime("%Y-%m-%d %H:%M:%S"),
            "processed": len(photo_paths),
            "current_photo": "",
            "progress_percent": 100
        })
        try:
            with open(status_file, 'w') as f:
                json.dump(status, f, indent=2)
            logging.info("Processing completed - updated status file")
        except Exception as e:
            logging.warning(f"Failed to write final status: {e}")

        self._save_global_scene_count()

        return results

    def load_expected_results_from_csv(self, csv_path: str) -> Dict[str, Dict]:
        """Load expected results from CSV for regression testing."""
        expected_results = {}
        
        try:
            with open(csv_path, 'r', encoding='utf-8-sig') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    filename = row['filename']
                    expected_results[filename] = {
                        'species': row['species'],
                        'species_confidence': int(float(row['species_confidence']) * 100),  # Convert to percentage
                        'quality': int(float(row['quality']) * 100) if float(row['quality']) != -1 else -1,  # Convert to percentage  
                        'rating': int(float(row['rating'])) if row['rating'] else 0,
                        'scene_count': int(row['scene_count']) if row['scene_count'] else 1,
                        'feature_similarity': int(float(row['feature_similarity']) * 100) if float(row['feature_similarity']) > 0 else int(float(row['feature_similarity'])),
                        'feature_confidence': int(float(row['feature_confidence']) * 100) if float(row['feature_confidence']) > 0 else int(float(row['feature_confidence'])),
                        'color_similarity': int(float(row['color_similarity'])) if row['color_similarity'] else 0,
                        'color_confidence': int(float(row['color_confidence']) * 100) if float(row['color_confidence']) > 0 else int(float(row['color_confidence'])),
                    }
                    
        except Exception as exc:
            logging.error(f"Failed to load expected results from {csv_path}: {exc}")
            
        return expected_results

    def compare_results(self, actual: Dict, expected: Dict, tolerances: Dict = None) -> Dict:
        """Compare actual vs expected results with tolerances."""
        if tolerances is None:
            tolerances = {
                'species_confidence': 10,
                'quality': 15, 
                'rating': 1,
                'scene_count': 0,
                'feature_similarity': 20,
                'feature_confidence': 15,
                'color_similarity': 20,
                'color_confidence': 15
            }
            
        comparison = {
            'filename': actual.get('filename', 'unknown'),
            'passed': True,
            'failures': []
        }
        
        # Compare species (exact match required)
        if actual.get('species') != expected.get('species'):
            comparison['passed'] = False
            comparison['failures'].append(f"Species mismatch: got '{actual.get('species')}', expected '{expected.get('species')}'")
        
        # Compare numeric fields with tolerances
        numeric_fields = ['species_confidence', 'quality', 'rating', 'scene_count', 
                         'feature_similarity', 'feature_confidence', 'color_similarity', 'color_confidence']
        
        for field in numeric_fields:
            actual_val = actual.get(field, 0)
            expected_val = expected.get(field, 0)
            tolerance = tolerances.get(field, 0)
            
            diff = abs(actual_val - expected_val)
            if diff > tolerance:
                comparison['passed'] = False
                comparison['failures'].append(f"{field}: got {actual_val}, expected {expected_val} (diff: {diff}, tolerance: {tolerance})")
                
        return comparison

    def run_regression_test(self, csv_path: str, output_dir: Path) -> Dict:
        """Run regression test against expected results."""
        logging.info("Starting regression test mode")
        
        # Load expected results
        expected_results = self.load_expected_results_from_csv(csv_path)
        if not expected_results:
            return {"error": "No expected results loaded"}
            
        logging.info(f"Loaded {len(expected_results)} expected results from {csv_path}")
        
        # Get photo paths - resolve relative paths properly
        csv_path_obj = Path(csv_path).resolve()
        csv_dir = csv_path_obj.parent
        original_dir = csv_dir / "original"
        
        logging.info(f"CSV directory: {csv_dir}")
        logging.info(f"Looking for images in: {original_dir}")
        
        if not original_dir.exists():
            return {"error": f"Original images directory not found: {original_dir}"}
            
        photo_paths = []
        for filename in expected_results.keys():
            photo_path = original_dir / filename
            if photo_path.exists():
                photo_paths.append(str(photo_path))
            else:
                logging.warning(f"Photo not found: {photo_path}")
                
        if not photo_paths:
            return {"error": "No photos found for regression test"}
            
        logging.info(f"Running regression test on {len(photo_paths)} images")
        
        # Process photos
        def progress_callback(current, total, filename):
            logging.info(f"Regression test progress: {current}/{total} - {filename}")
            
        start_time = time.time()
        actual_results = self.process_batch(photo_paths, output_dir, generate_crops=False, progress_callback=progress_callback)
        processing_time = time.time() - start_time
        
        # Compare results
        comparisons = []
        passed_count = 0
        species_correct = 0
        
        for actual in actual_results:
            filename = actual['filename']
            if filename in expected_results:
                expected = expected_results[filename]
                comparison = self.compare_results(actual, expected)
                comparisons.append(comparison)
                
                if comparison['passed']:
                    passed_count += 1
                    logging.info(f"✓ {filename}: PASSED")
                else:
                    logging.warning(f"✗ {filename}: FAILED")
                    for failure in comparison['failures']:
                        logging.warning(f"  - {failure}")
                        
                # Check species accuracy separately
                if actual.get('species') == expected.get('species'):
                    species_correct += 1
                    
        # Generate report
        total_tests = len(comparisons)
        pass_rate = (passed_count / total_tests * 100) if total_tests > 0 else 0
        species_accuracy = (species_correct / total_tests * 100) if total_tests > 0 else 0
        
        # Calculate average differences
        confidence_diffs = []
        quality_diffs = []
        
        for actual in actual_results:
            filename = actual['filename']
            if filename in expected_results:
                expected = expected_results[filename]
                confidence_diffs.append(abs(actual.get('species_confidence', 0) - expected.get('species_confidence', 0)))
                quality_diffs.append(abs(actual.get('quality', 0) - expected.get('quality', 0)))
                
        avg_confidence_diff = np.mean(confidence_diffs) if confidence_diffs else 0
        avg_quality_diff = np.mean(quality_diffs) if quality_diffs else 0
        
        report = {
            "test_date": time.strftime("%Y-%m-%d %H:%M:%S"),
            "total_images": total_tests,
            "passed": passed_count,
            "failed": total_tests - passed_count,
            "pass_rate": pass_rate,
            "species_accuracy": species_accuracy,
            "avg_confidence_diff": avg_confidence_diff,
            "avg_quality_diff": avg_quality_diff,
            "processing_time": processing_time,
            "comparisons": comparisons,
            "actual_results": actual_results,
            "expected_results": expected_results
        }
        
        # Save detailed report
        report_path = output_dir / "regression_test_report.json"
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2, default=str)
            
        # Save summary report
        summary_path = output_dir / "regression_test_summary.txt"
        with open(summary_path, 'w') as f:
            f.write("WildlifeAI Regression Test Report\n")
            f.write("=" * 50 + "\n")
            f.write(f"Test Date: {report['test_date']}\n")
            f.write(f"Total Images: {report['total_images']}\n")
            f.write(f"Passed: {report['passed']}\n")
            f.write(f"Failed: {report['failed']}\n")
            f.write(f"Pass Rate: {report['pass_rate']:.1f}%\n")
            f.write(f"Species Accuracy: {report['species_accuracy']:.1f}%\n")
            f.write(f"Avg Confidence Diff: {report['avg_confidence_diff']:.1f}%\n")
            f.write(f"Avg Quality Diff: {report['avg_quality_diff']:.1f}%\n")
            f.write(f"\nProcessing Time: {report['processing_time']:.1f}s\n")
            
            # Add failed tests details
            failed_tests = [c for c in comparisons if not c['passed']]
            if failed_tests:
                f.write(f"\nFailed Tests:\n")
                f.write("-" * 30 + "\n")
                for test in failed_tests:
                    f.write(f"\n{test['filename']}:\n")
                    for failure in test['failures']:
                        f.write(f"  - {failure}\n")
        
        logging.info(f"Regression test complete: {passed_count}/{total_tests} passed ({pass_rate:.1f}%)")
        logging.info(f"Detailed report: {report_path}")
        logging.info(f"Summary report: {summary_path}")
        
        return report

def capture_debug_environment():
    """Capture comprehensive environment and debugging information."""
    import tempfile
    import subprocess
    
    debug_info = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "command_line": sys.argv,
        "python_info": {
            "version": sys.version,
            "executable": sys.executable,
            "frozen": getattr(sys, 'frozen', False),
            "meipass": getattr(sys, '_MEIPASS', None),
        },
        "process_info": {
            "pid": os.getpid(),
            "ppid": os.getppid() if hasattr(os, 'getppid') else None,
            "cwd": os.getcwd(),
        },
        "environment": {
            "PATH": os.environ.get('PATH', '')[:500],  # Truncate for readability
            "TEMP": os.environ.get('TEMP', ''),
            "TMP": os.environ.get('TMP', ''),
            "USERPROFILE": os.environ.get('USERPROFILE', ''),
            "USERNAME": os.environ.get('USERNAME', ''),
        },
        "file_system_tests": {},
        "startup_errors": []
    }
    
    # Test file system access
    try:
        temp_dir = tempfile.gettempdir()
        debug_info["file_system_tests"]["temp_dir"] = temp_dir
        test_file = Path(temp_dir) / f"wai_debug_{os.getpid()}.txt"
        with open(test_file, 'w') as f:
            f.write("debug test")
        test_file.unlink()
        debug_info["file_system_tests"]["temp_write"] = "SUCCESS"
    except Exception as e:
        debug_info["file_system_tests"]["temp_write"] = f"FAILED: {e}"
        debug_info["startup_errors"].append(f"Temp write failed: {e}")
    
    # Test PyInstaller environment
    if hasattr(sys, '_MEIPASS'):
        try:
            models_dir = ROOT / "models"
            debug_info["pyinstaller"] = {
                "meipass": getattr(sys, '_MEIPASS', None),
                "models_exist": models_dir.exists(),
            }
            if models_dir.exists():
                debug_info["pyinstaller"]["model_files"] = [f.name for f in models_dir.iterdir()]
        except Exception as e:
            debug_info["startup_errors"].append(f"PyInstaller environment error: {e}")
    
    return debug_info

def main():
    parser = argparse.ArgumentParser(description="Enhanced WildlifeAI Model Runner")
    parser.add_argument("photos", nargs="*", help="Photo paths to process")
    parser.add_argument("--photo-list", help="Path to file containing list of photos")
    parser.add_argument("--output-dir", help="Output directory for results")
    parser.add_argument("--max-workers", type=int, default=4, help="Maximum worker threads")
    parser.add_argument("--gpu", action="store_true", help="Enable GPU acceleration")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")
    parser.add_argument("--generate-crops", action="store_true", help="Generate crop images")
    parser.add_argument("--regression-test", action="store_true", help="Run regression test mode")
    parser.add_argument("--async-mode", action="store_true", help="Run in asynchronous mode (for Lightroom plugin)")
    parser.add_argument("--debug-env", action="store_true", help="Debug environment and exit")
    
    # Capture debug info early, before argument parsing can fail
    debug_info = None
    try:
        debug_info = capture_debug_environment()
    except Exception as e:
        print(f"Failed to capture debug info: {e}")
    
    try:
        args = parser.parse_args()
    except SystemExit as e:
        # Argument parsing failed - save debug info and re-raise
        if debug_info:
            try:
                debug_path = Path("C:/temp/wai_debug_args_failed.json")
                debug_path.parent.mkdir(exist_ok=True)
                with open(debug_path, 'w') as f:
                    json.dump(debug_info, f, indent=2, default=str)
                print(f"Debug info saved to: {debug_path}")
            except:
                pass
        raise
    
    # Handle debug environment mode first
    if args.debug_env:
        try:
            # Save debug info to multiple locations
            debug_paths = [
                Path("C:/temp/wai_debug_environment.json"),
                Path(args.output_dir) / "debug_environment.json" if args.output_dir else Path("debug_environment.json"),
                Path.cwd() / "debug_environment.json"
            ]
            
            for debug_path in debug_paths:
                try:
                    debug_path.parent.mkdir(parents=True, exist_ok=True)
                    with open(debug_path, 'w') as f:
                        json.dump(debug_info, f, indent=2, default=str)
                    print(f"Debug environment saved to: {debug_path}")
                except Exception as e:
                    print(f"Failed to save debug to {debug_path}: {e}")
            
            # Print key debug info
            print("\n=== ENVIRONMENT DEBUG ===")
            print(f"PID: {debug_info['process_info']['pid']}")
            print(f"PPID: {debug_info['process_info']['ppid']}")
            print(f"CWD: {debug_info['process_info']['cwd']}")
            print(f"Frozen: {debug_info['python_info']['frozen']}")
            print(f"MEIPASS: {debug_info['python_info']['meipass']}")
            print(f"TEMP: {debug_info['environment']['TEMP']}")
            print(f"USERNAME: {debug_info['environment']['USERNAME']}")
            print(f"Startup errors: {len(debug_info['startup_errors'])}")
            for error in debug_info['startup_errors']:
                print(f"  - {error}")
            print("========================\n")
            
            return 0
        except Exception as e:
            print(f"Debug environment mode failed: {e}")
            return 1
    
    # Setup logging with comprehensive file output and error handling
    log_level = logging.DEBUG if args.verbose else logging.INFO
    
    # Create multiple log files for different scenarios
    log_files = []
    if args.output_dir:
        log_files.append(Path(args.output_dir) / "runner_debug.log")
    
    # Always try to create logs in multiple locations
    log_files.extend([
        Path("C:/temp/wai_runner_debug.log"),
        Path.cwd() / "runner_debug.log",
        Path(os.environ.get('TEMP', '.')) / "wai_runner_debug.log"
    ])
    
    handlers = [logging.StreamHandler(sys.stdout)]
    
    # Try to create file handlers for all possible locations
    for log_file in log_files:
        try:
            log_file.parent.mkdir(parents=True, exist_ok=True)
            file_handler = logging.FileHandler(log_file, mode='w')
            file_handler.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(message)s'))
            handlers.append(file_handler)
            print(f"Logging to: {log_file}")
            break  # Use first successful log file
        except Exception as e:
            print(f"Failed to create log file {log_file}: {e}")
    
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s [%(levelname)s] %(message)s',
        handlers=handlers
    )
    
    # Log the debug environment information at startup
    if debug_info:
        logging.info("=== STARTUP ENVIRONMENT DEBUG ===")
        logging.info(f"Command line: {' '.join(sys.argv)}")
        logging.info(f"PID: {debug_info['process_info']['pid']}")
        logging.info(f"PPID: {debug_info['process_info']['ppid']}")
        logging.info(f"CWD: {debug_info['process_info']['cwd']}")
        logging.info(f"Python executable: {debug_info['python_info']['executable']}")
        logging.info(f"Frozen (PyInstaller): {debug_info['python_info']['frozen']}")
        logging.info(f"MEIPASS: {debug_info['python_info']['meipass']}")
        logging.info(f"TEMP directory: {debug_info['environment']['TEMP']}")
        logging.info(f"USERNAME: {debug_info['environment']['USERNAME']}")
        logging.info(f"Startup errors: {len(debug_info['startup_errors'])}")
        for error in debug_info['startup_errors']:
            logging.error(f"Startup error: {error}")
        logging.info("================================")
    
    logging.info("Enhanced WildlifeAI Runner starting")
    logging.info(f"GPU enabled: {args.gpu}")
    logging.info(f"Max workers: {args.max_workers}")
    
    # Process photo paths first (needed for both sync and async modes)
    photo_paths = []
    
    if args.photos:
        # Use positional arguments (direct photo paths)
        logging.info(f"Using {len(args.photos)} photos from command line arguments")
        photo_paths = args.photos
    elif args.photo_list:
        # Use photo list file
        logging.info(f"Reading photos from file: {args.photo_list}")
        try:
            with open(args.photo_list, 'r', encoding='utf-8-sig') as f:
                if args.photo_list.endswith('.csv'):
                    # Handle CSV format
                    reader = csv.DictReader(f)
                    for row in reader:
                        if 'filename' in row:
                            # Resolve paths properly for executable
                            csv_path_obj = Path(args.photo_list).resolve()
                            csv_dir = csv_path_obj.parent
                            
                            # Try original/ subdirectory first
                            photo_path = csv_dir / "original" / row['filename']
                            if not photo_path.exists():
                                # Fallback to same directory as CSV
                                photo_path = csv_dir / row['filename']
                            
                            logging.debug(f"Looking for photo: {photo_path}")
                            photo_paths.append(str(photo_path))
                else:
                    # Handle plain text format - resolve relative paths
                    for line in f:
                        line = line.strip()
                        if line:
                            # Resolve relative paths properly
                            if not Path(line).is_absolute():
                                base_dir = Path(args.photo_list).resolve().parent
                                line = str(base_dir / line)
                            photo_paths.append(line)
        except Exception as exc:
            logging.error(f"Failed to read photo list: {exc}")
            return 1
    else:
        logging.error("Either photo paths or --photo-list is required")
        return 1
    
    if not photo_paths:
        logging.error("No photos found to process")
        return 1
        
    logging.info(f"Processing {len(photo_paths)} photos")
    
    # Setup output directory before async mode
    output_dir = Path(args.output_dir) if args.output_dir else Path("output")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Handle async mode for immediate handback
    if args.async_mode:
        # Return immediately and let background thread handle model loading and processing
        import threading
        
        def async_processing():
            """Run processing in background thread with model loading"""
            status = None
            status_path = None
            try:
                # Create status file to indicate processing started
                status_path = output_dir / "status.json"
                status = {
                    "status": "initializing",
                    "start_time": time.strftime("%Y-%m-%d %H:%M:%S"),
                    "total_photos": len(photo_paths),
                    "processed": 0,
                    "current_photo": "",
                    "results": []
                }
                
                with open(status_path, 'w') as f:
                    json.dump(status, f, indent=2)
                
                logging.info("Background processing started - loading models")
                
                # Initialize runner in background
                runner = EnhancedModelRunner(use_gpu=args.gpu, max_workers=args.max_workers)
                
                # Update status to processing
                status["status"] = "processing"
                with open(status_path, 'w') as f:
                    json.dump(status, f, indent=2)
                
                logging.info("Models loaded, starting photo processing")
                
                # Process photos with status updates
                def progress_callback(current, total, filename):
                    status["processed"] = current
                    status["current_photo"] = filename
                    status["progress_percent"] = (current / total) * 100
                    with open(status_path, 'w') as f:
                        json.dump(status, f, indent=2)
                    logging.info(f"Progress: {current}/{total} ({status['progress_percent']:.1f}%) - {filename}")
                
                start_time = time.time()
                results = runner.process_batch(photo_paths, output_dir, args.generate_crops, progress_callback)
                processing_time = time.time() - start_time
                
                # Update final status
                status["status"] = "completed"
                status["end_time"] = time.strftime("%Y-%m-%d %H:%M:%S")
                status["processing_time"] = processing_time
                status["results"] = results
                status["processed"] = len(results)
                status["progress_percent"] = 100
                
                with open(status_path, 'w') as f:
                    json.dump(status, f, indent=2)
                
                # Save results
                results_path = output_dir / "results.json"
                with open(results_path, 'w') as f:
                    json.dump(results, f, indent=2, default=str)
                
                logging.info(f"Background processing complete: {len(results)} photos in {processing_time:.1f}s")
                logging.info(f"Results saved to: {results_path}")
                
            except Exception as e:
                # Update status with error
                logging.error(f"Background processing failed: {e}")
                if status is not None and status_path is not None:
                    try:
                        status["status"] = "error"
                        status["error"] = str(e)
                        status["end_time"] = time.strftime("%Y-%m-%d %H:%M:%S")
                        with open(status_path, 'w') as f:
                            json.dump(status, f, indent=2)
                    except Exception as e2:
                        logging.error(f"Failed to write error status: {e2}")
        
        # Start processing in background thread
        thread = threading.Thread(target=async_processing, daemon=False)
        thread.start()
        
        # Return immediately with success code for Lightroom
        logging.info("Async processing initiated - returning control to Lightroom immediately")
        return 0
    
    # Initialize runner for synchronous mode
    runner = EnhancedModelRunner(use_gpu=args.gpu, max_workers=args.max_workers)
    
    # Check if we have working models
    if not runner.species_classifier and not runner.quality_classifier:
        logging.error("No models loaded successfully. Check model files and dependencies.")
        return 1
    
    # Check for critical missing components
    critical_missing = []
    if not runner.mask_rcnn or runner.mask_rcnn.model is None:
        critical_missing.append("Mask R-CNN (PyTorch/torchvision)")
    if not runner.quality_classifier:
        critical_missing.append("Quality Classifier (TensorFlow)")
    
    if critical_missing:
        logging.error(f"Critical models missing: {', '.join(critical_missing)}")
        logging.error("Processing will continue with limited functionality")
        # Don't return 1 here since we can still do species classification
    
    if args.regression_test:
        if not args.photo_list or not args.output_dir:
            logging.error("Regression test requires --photo-list and --output-dir")
            return 1
            
        output_dir = Path(args.output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        report = runner.run_regression_test(args.photo_list, output_dir)
        
        if "error" in report:
            logging.error(f"Regression test failed: {report['error']}")
            return 1
            
        # Return exit code based on pass rate
        return 0 if report.get('pass_rate', 0) == 100 else 1
    
    # Photo paths already processed above for async mode
    
    # Synchronous mode: process normally
    def progress_callback(current, total, filename):
        logging.info(f"Progress: {current}/{total} - {filename}")
        
    start_time = time.time()
    results = runner.process_batch(photo_paths, output_dir, args.generate_crops, progress_callback)
    processing_time = time.time() - start_time
    
    logging.info(f"Processing complete: {len(results)} photos in {processing_time:.1f}s")
    
    # Save results
    results_path = output_dir / "results.json"
    with open(results_path, 'w') as f:
        json.dump(results, f, indent=2, default=str)
        
    logging.info(f"Results saved to: {results_path}")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
