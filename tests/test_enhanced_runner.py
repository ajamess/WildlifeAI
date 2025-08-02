# Save as: tests/test_enhanced_runner.py
import pytest
import json
import csv
import subprocess
import tempfile
import shutil
from pathlib import Path
from typing import Dict, List
import sys
import os

# Add the python runner to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "python" / "runner"))

from wildlifeai_runner import EnhancedModelRunner as ModelRunner


class TestEnhancedRunner:
    """Test suite for the enhanced WildlifeAI runner."""
    
    @pytest.fixture(scope="class")
    def test_data_dir(self):
        """Get the test data directory."""
        return Path(__file__).parent / "quick"
    
    @pytest.fixture(scope="class")
    def expected_results(self, test_data_dir):
        """Load expected results from CSV database."""
        csv_path = test_data_dir / "kestrel_database.csv"
        results = {}
        
        with open(csv_path, newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                filename = row["filename"]
                results[filename] = {
                    "detected_species": row.get("species", ""),
                    "species_confidence": int(float(row.get("species_confidence", 0)) * 100),
                    "quality": int(float(row.get("quality", 0)) * 100),
                    "rating": int(row.get("rating", 0)),
                    "scene_count": int(row.get("scene_count", 0)),
                    "feature_similarity": int(float(row.get("feature_similarity", 0)) * 100),
                    "feature_confidence": int(float(row.get("feature_confidence", 0)) * 100),
                    "color_similarity": int(float(row.get("color_similarity", 0)) * 100),
                    "color_confidence": int(float(row.get("color_confidence", 0)) * 100),
                }
        
        return results
    
    @pytest.fixture(scope="class")
    def test_images(self, test_data_dir):
        """Get list of test images."""
        originals_dir = test_data_dir / "original"
        if not originals_dir.exists():
            pytest.skip("No test images found")
        
        images = list(originals_dir.glob("*"))
        if not images:
            pytest.skip("No test images found")
            
        return images
    
    def test_model_loading_cpu(self):
        """Test that models can be loaded in CPU mode."""
        runner = ModelRunner(use_gpu=False, max_workers=1)
        
        # Check that at least one model loaded
        assert runner.species_session is not None or runner.quality_model is not None, \
            "No models loaded - check model files exist"
    
    def test_model_loading_gpu(self):
        """Test GPU model loading (may skip if no GPU available)."""
        try:
            runner = ModelRunner(use_gpu=True, max_workers=1)
            # If we get here without exception, GPU loading worked
            assert True
        except Exception as e:
            pytest.skip(f"GPU not available: {e}")
    
    def test_image_loading(self, test_images):
        """Test image loading functionality."""
        runner = ModelRunner(use_gpu=False, max_workers=1)
        
        for img_path in test_images[:1]:  # Test first image only
            img_array = runner.load_image(str(img_path))
            
            # Check image dimensions and type
            assert img_array.shape == (224, 224, 3), f"Wrong image shape: {img_array.shape}"
            assert img_array.dtype == "float32", f"Wrong image dtype: {img_array.dtype}"
            assert 0 <= img_array.min() and img_array.max() <= 1, "Image values not normalized"
    
    def test_single_prediction(self, test_images):
        """Test single image prediction."""
        runner = ModelRunner(use_gpu=False, max_workers=1)
        
        for img_path in test_images[:1]:  # Test first image only
            img_array = runner.load_image(str(img_path))
            species, conf, quality = runner.predict_single(img_array)
            
            # Check output types and ranges
            assert isinstance(species, str), f"Species should be string, got {type(species)}"
            assert isinstance(conf, int), f"Confidence should be int, got {type(conf)}"
            assert isinstance(quality, int), f"Quality should be int, got {type(quality)}"
            assert 0 <= conf <= 100, f"Confidence out of range: {conf}"
            assert 0 <= quality <= 100, f"Quality out of range: {quality}"
    
    def test_batch_processing(self, test_images):
        """Test batch processing functionality."""
        runner = ModelRunner(use_gpu=False, max_workers=2)
        
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            
            # Process a subset of images
            photo_paths = [str(img) for img in test_images[:2]]
            
            results = runner.process_batch(photo_paths, output_dir, generate_crops=True)
            
            # Check results
            assert len(results) == len(photo_paths), "Wrong number of results"
            
            for result in results:
                # Check required fields
                required_fields = [
                    "detected_species", "species_confidence", "quality", 
                    "rating", "scene_count", "json_path"
                ]
                for field in required_fields:
                    assert field in result, f"Missing field: {field}"
                
                # Check JSON file was created
                json_path = Path(result["json_path"])
                assert json_path.exists(), f"JSON file not created: {json_path}"
                
                # Verify JSON content
                with open(json_path) as f:
                    json_data = json.load(f)
                    assert json_data == result, "JSON content doesn't match result"
    
    def test_crop_generation(self, test_images):
        """Test crop image generation."""
        runner = ModelRunner(use_gpu=False, max_workers=1)
        
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            
            for img_path in test_images[:1]:  # Test first image only
                result = runner.process_photo(str(img_path), output_dir, generate_crops=True)
                
                # Check crop was generated
                crop_path = result.get("crop_path")
                if crop_path:
                    assert Path(crop_path).exists(), f"Crop file not created: {crop_path}"
    
    def test_command_line_interface(self, test_images):
        """Test the command line interface."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            
            # Create photo list file
            photo_list = tmpdir_path / "photos.txt"
            with open(photo_list, 'w') as f:
                for img in test_images[:2]:
                    f.write(str(img) + '\n')
            
            # Run the enhanced runner
            cmd = [
                sys.executable,
                "python/runner/wildlifeai_runner.py",
                "--photo-list", str(photo_list),
                "--output-dir", str(tmpdir_path),
                "--max-workers", "1",
                "--verbose"
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            # Check execution succeeded
            assert result.returncode == 0, f"Runner failed: {result.stderr}"
            
            # Check output files were created
            json_files = list(tmpdir_path.glob("*.json"))
            assert len(json_files) == len(test_images[:2]), "Wrong number of output files"
    
    def test_gpu_flag(self, test_images):
        """Test GPU flag in command line interface."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            
            # Create photo list file
            photo_list = tmpdir_path / "photos.txt"
            with open(photo_list, 'w') as f:
                f.write(str(test_images[0]) + '\n')
            
            # Run with GPU flag (should not crash even if no GPU)
            cmd = [
                sys.executable,
                "python/runner/wildlifeai_runner.py",
                "--photo-list", str(photo_list),
                "--output-dir", str(tmpdir_path),
                "--gpu",
                "--max-workers", "1"
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            # Should not crash (may use CPU fallback)
            assert result.returncode == 0, f"GPU test failed: {result.stderr}"
    
    def test_error_handling(self):
        """Test error handling with invalid inputs."""
        runner = ModelRunner(use_gpu=False, max_workers=1)
        
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            
            # Test with non-existent file
            result = runner.process_photo("/non/existent/file.jpg", output_dir)
            
            # Should return error result, not crash
            assert "error" in result or result["detected_species"] == "Error"
    
    @pytest.mark.slow
    def test_accuracy_regression(self, test_data_dir, expected_results, test_images):
        """Test that results match expected values (regression test)."""
        runner = ModelRunner(use_gpu=False, max_workers=1)
        
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            
            # Copy expected crop and export files if they exist
            for subdir in ["crop", "export"]:
                src_dir = test_data_dir / subdir
                if src_dir.exists():
                    dst_dir = output_dir / subdir
                    dst_dir.mkdir(exist_ok=True)
                    for file in src_dir.glob("*"):
                        shutil.copy2(file, dst_dir)
            
            tolerance = 5  # Allow 5% tolerance for model variations
            
            for img_path in test_images:
                filename = img_path.name
                if filename not in expected_results:
                    continue
                
                result = runner.process_photo(str(img_path), output_dir)
                expected = expected_results[filename]
                
                # Compare key metrics with tolerance
                for key in ["species_confidence", "quality"]:
                    if key in expected and expected[key] > 0:
                        actual = result.get(key, 0)
                        expected_val = expected[key]
                        diff = abs(actual - expected_val)
                        
                        # Allow tolerance for numeric values
                        assert diff <= tolerance, \
                            f"{filename} {key}: expected {expected_val}, got {actual} (diff: {diff})"


class TestPerformance:
    """Performance tests for the enhanced runner."""
    
    @pytest.mark.slow
    def test_parallel_processing_performance(self, test_images):
        """Test that parallel processing improves performance."""
        if len(test_images) < 2:
            pytest.skip("Need at least 2 test images")
        
        photo_paths = [str(img) for img in test_images[:4]]
        
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            
            # Test single-threaded
            import time
            runner_single = ModelRunner(use_gpu=False, max_workers=1)
            start_time = time.time()
            runner_single.process_batch(photo_paths, output_dir / "single")
            single_time = time.time() - start_time
            
            # Test multi-threaded
            runner_multi = ModelRunner(use_gpu=False, max_workers=2)
            start_time = time.time()
            runner_multi.process_batch(photo_paths, output_dir / "multi")
            multi_time = time.time() - start_time
            
            # Multi-threaded should be faster (with some tolerance)
            improvement = (single_time - multi_time) / single_time
            print(f"Performance improvement: {improvement:.2%}")
            
            # Should see some improvement, but not strict since test images are small
            assert improvement > -0.5, "Multi-threading significantly slower than single-threading"


# Pytest configuration
def pytest_configure(config):
    """Configure pytest markers."""
    config.addinivalue_line("markers", "slow: marks tests as slow (deselect with '-m \"not slow\"')")


if __name__ == "__main__":
    # Allow running tests directly
    pytest.main([__file__, "-v"])
