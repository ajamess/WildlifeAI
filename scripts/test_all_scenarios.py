# Save this as: scripts/test_all_scenarios.py
#!/usr/bin/env python3
"""
Comprehensive test script for the enhanced WildlifeAI runner
Tests all scenarios: CPU/GPU, bundled executable, system Python, etc.
"""
import sys
import subprocess
import tempfile
import json
import csv
from pathlib import Path
import time
import os

class TestRunner:
    def __init__(self):
        self.root = Path(__file__).parent.parent
        self.results = []
        self.total_tests = 0
        self.passed_tests = 0
        
    def log(self, message, status="INFO"):
        timestamp = time.strftime("%H:%M:%S")
        print(f"[{timestamp}] {status}: {message}")
        
    def test_passed(self, test_name):
        self.passed_tests += 1
        self.total_tests += 1
        self.results.append((test_name, "PASSED"))
        self.log(f"✓ {test_name}", "PASS")
        
    def test_failed(self, test_name, error):
        self.total_tests += 1
        self.results.append((test_name, f"FAILED: {error}"))
        self.log(f"✗ {test_name}: {error}", "FAIL")
        
    def run_command(self, cmd, timeout=60, check_return=True):
        """Run a command and return result."""
        try:
            result = subprocess.run(
                cmd, 
                capture_output=True, 
                text=True, 
                timeout=timeout,
                cwd=self.root
            )
            
            if check_return and result.returncode != 0:
                raise Exception(f"Command failed with code {result.returncode}: {result.stderr}")
                
            return result
        except subprocess.TimeoutExpired:
            raise Exception(f"Command timed out after {timeout} seconds")
        except Exception as e:
            raise Exception(f"Command execution failed: {e}")

    def test_1_executable_exists(self):
        """Test 1: Check if the executable was created and is accessible."""
        test_name = "Executable Creation and Accessibility"
        
        exe_path = self.root / "plugin" / "WildlifeAI.lrplugin" / "bin" / "win" / "wildlifeai_runner_cpu.exe"
        
        if not exe_path.exists():
            self.test_failed(test_name, f"Executable not found at {exe_path}")
            return False
            
        # Check if it's actually executable
        try:
            result = self.run_command([str(exe_path), "--help"], timeout=30)
            if "usage:" not in result.stdout.lower() and "wildlifeai" not in result.stdout.lower():
                self.test_failed(test_name, "Help output doesn't look correct")
                return False
        except Exception as e:
            self.test_failed(test_name, f"Failed to run executable: {e}")
            return False
            
        self.test_passed(test_name)
        return True

    def test_2_compatibility_runner(self):
        """Test 2: Check if the compatibility runner (kestrel_runner.exe) works."""
        test_name = "Compatibility Runner (kestrel_runner.exe)"
        
        exe_path = self.root / "plugin" / "WildlifeAI.lrplugin" / "bin" / "win" / "kestrel_runner.exe"
        
        if not exe_path.exists():
            self.test_failed(test_name, f"Compatibility executable not found at {exe_path}")
            return False
            
        try:
            result = self.run_command([str(exe_path), "--help"], timeout=30)
            self.test_passed(test_name)
            return True
        except Exception as e:
            self.test_failed(test_name, f"Compatibility runner failed: {e}")
            return False

    def test_3_self_test_mode(self):
        """Test 3: Test self-test mode functionality."""
        test_name = "Self-test Mode"
        
        exe_path = self.root / "plugin" / "WildlifeAI.lrplugin" / "bin" / "win" / "wildlifeai_runner_cpu.exe"
        
        with tempfile.TemporaryDirectory() as tmpdir:
            try:
                result = self.run_command([
                    str(exe_path),
                    "--self-test",
                    "--photo-list", "dummy.txt",  # Not used in self-test
                    "--output-dir", tmpdir,
                    "--verbose"
                ], timeout=60)
                
                # Check if output files were created
                output_files = list(Path(tmpdir).glob("*.json"))
                if not output_files:
                    self.test_failed(test_name, "No output files created")
                    return False
                    
                # Validate JSON content
                for json_file in output_files:
                    with open(json_file) as f:
                        data = json.load(f)
                        
                    required_fields = ["detected_species", "species_confidence", "quality"]
                    for field in required_fields:
                        if field not in data:
                            self.test_failed(test_name, f"Missing field '{field}' in output")
                            return False
                            
                self.test_passed(test_name)
                return True
                
            except Exception as e:
                self.test_failed(test_name, f"Self-test failed: {e}")
                return False

    def test_4_csv_input_mode(self):
        """Test 4: Test CSV input compatibility mode."""
        test_name = "CSV Input Mode"
        
        exe_path = self.root / "plugin" / "WildlifeAI.lrplugin" / "bin" / "win" / "wildlifeai_runner_cpu.exe"
        
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            
            # Create test CSV
            csv_file = tmpdir_path / "test.csv"
            csv_data = [
                ["filename", "species", "species_confidence", "quality", "rating", "scene_count", 
                 "feature_similarity", "feature_confidence", "color_similarity", "color_confidence"],
                ["test1.jpg", "Robin", "0.85", "0.75", "3", "1", "0.6", "0.9", "0.4", "0.7"],
                ["test2.jpg", "Sparrow", "0.92", "0.82", "4", "2", "0.7", "0.95", "0.5", "0.8"]
            ]
            
            with open(csv_file, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerows(csv_data)
            
            try:
                result = self.run_command([
                    str(exe_path),
                    "--self-test",  # This triggers CSV mode when photo-list is CSV
                    "--photo-list", str(csv_file),
                    "--output-dir", str(tmpdir_path),
                    "--verbose"
                ], timeout=60)
                
                # Check outputs
                json_files = list(tmpdir_path.glob("*.json"))
                if len(json_files) < 2:  # Should have individual files plus summary
                    self.test_failed(test_name, f"Expected multiple JSON files, got {len(json_files)}")
                    return False
                    
                self.test_passed(test_name)
                return True
                
            except Exception as e:
                self.test_failed(test_name, f"CSV mode failed: {e}")
                return False

    def test_5_real_image_processing(self):
        """Test 5: Test with real images if available."""
        test_name = "Real Image Processing"
        
        exe_path = self.root / "plugin" / "WildlifeAI.lrplugin" / "bin" / "win" / "wildlifeai_runner_cpu.exe"
        
        # Look for test images
        test_images_dir = self.root / "tests" / "quick" / "original"
        if not test_images_dir.exists():
            self.log(f"Skipping {test_name}: No test images found at {test_images_dir}")
            return True
            
        test_images = list(test_images_dir.glob("*"))
        if not test_images:
            self.log(f"Skipping {test_name}: No images in test directory")
            return True
            
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            
            # Create photo list file
            photo_list = tmpdir_path / "photos.txt"
            with open(photo_list, 'w') as f:
                for img in test_images[:2]:  # Test with first 2 images
                    f.write(str(img) + '\n')
            
            try:
                result = self.run_command([
                    str(exe_path),
                    "--photo-list", str(photo_list),
                    "--output-dir", str(tmpdir_path),
                    "--max-workers", "1",  # Single worker for consistency
                    "--verbose"
                ], timeout=120)  # Longer timeout for real processing
                
                # Check outputs
                json_files = list(tmpdir_path.glob("*.json"))
                crop_files = list(tmpdir_path.glob("*_crop.jpg"))
                
                if len(json_files) != len(test_images[:2]):
                    self.test_failed(test_name, f"Expected {len(test_images[:2])} JSON files, got {len(json_files)}")
                    return False
                    
                # Validate JSON structure
                for json_file in json_files:
                    with open(json_file) as f:
                        data = json.load(f)
                    
                    required_fields = ["detected_species", "species_confidence", "quality", "json_path"]
                    for field in required_fields:
                        if field not in data:
                            self.test_failed(test_name, f"Missing field '{field}' in {json_file}")
                            return False
                    
                    # Check data types and ranges
                    if not isinstance(data["species_confidence"], int) or not (0 <= data["species_confidence"] <= 100):
                        self.test_failed(test_name, f"Invalid species_confidence in {json_file}")
                        return False
                        
                    if not isinstance(data["quality"], int) or not (0 <= data["quality"] <= 100):
                        self.test_failed(test_name, f"Invalid quality in {json_file}")
                        return False
                
                self.test_passed(test_name)
                return True
                
            except Exception as e:
                self.test_failed(test_name, f"Real image processing failed: {e}")
                return False

    def test_6_gpu_flag(self):
        """Test 6: Test GPU flag (should not crash even without GPU)."""
        test_name = "GPU Flag Handling"
        
        exe_path = self.root / "plugin" / "WildlifeAI.lrplugin" / "bin" / "win" / "wildlifeai_runner_cpu.exe"
        
        with tempfile.TemporaryDirectory() as tmpdir:
            try:
                result = self.run_command([
                    str(exe_path),
                    "--self-test",
                    "--photo-list", "dummy.txt",
                    "--output-dir", tmpdir,
                    "--use-gpu",  # This should not crash
                    "--max-workers", "1"
                ], timeout=60)
                
                self.test_passed(test_name)
                return True
                
            except Exception as e:
                self.test_failed(test_name, f"GPU flag test failed: {e}")
                return False

    def test_7_parameter_variations(self):
        """Test 7: Test various parameter combinations."""
        test_name = "Parameter Variations"
        
        exe_path = self.root / "plugin" / "WildlifeAI.lrplugin" / "bin" / "win" / "wildlifeai_runner_cpu.exe"
        
        test_cases = [
            ["--self-test", "--photo-list", "dummy.txt", "--output-dir", "temp", "--no-crop"],
            ["--self-test", "--photo-list", "dummy.txt", "--output-dir", "temp", "--max-workers", "2"],
            ["--self-test", "--photo-list", "dummy.txt", "--output-dir", "temp", "--verbose"],
        ]
        
        for i, test_case in enumerate(test_cases):
            with tempfile.TemporaryDirectory() as tmpdir:
                # Replace 'temp' with actual temp directory
                cmd = [str(exe_path)] + [tmpdir if arg == "temp" else arg for arg in test_case]
                
                try:
                    result = self.run_command(cmd, timeout=60)
                    self.log(f"  Parameter test {i+1}: PASSED")
                except Exception as e:
                    self.test_failed(test_name, f"Parameter test {i+1} failed: {e}")
                    return False
        
        self.test_passed(test_name)
        return True

    def test_8_model_loading(self):
        """Test 8: Test model loading behavior."""
        test_name = "Model Loading Behavior"
        
        exe_path = self.root / "plugin" / "WildlifeAI.lrplugin" / "bin" / "win" / "wildlifeai_runner_cpu.exe"
        
        with tempfile.TemporaryDirectory() as tmpdir:
            try:
                # Run with verbose logging to see model loading messages
                result = self.run_command([
                    str(exe_path),
                    "--self-test",
                    "--photo-list", "dummy.txt",
                    "--output-dir", tmpdir,
                    "--verbose"
                ], timeout=60)
                
                # Check if model loading messages appear in output
                output = result.stdout + result.stderr
                
                # Should see some indication of model loading attempt
                if "model" not in output.lower() and "loading" not in output.lower():
                    self.log(f"  Warning: No model loading messages seen in output")
                
                self.test_passed(test_name)
                return True
                
            except Exception as e:
                self.test_failed(test_name, f"Model loading test failed: {e}")
                return False

    def test_9_plugin_integration(self):
        """Test 9: Test plugin directory structure and integration."""
        test_name = "Plugin Integration"
        
        plugin_dir = self.root / "plugin" / "WildlifeAI.lrplugin"
        
        # Check plugin structure
        required_files = [
            "Info.lua",
            "PluginInit.lua",
            "bin/win/wildlifeai_runner_cpu.exe",
            "bin/win/kestrel_runner.exe"
        ]
        
        missing_files = []
        for file_path in required_files:
            if not (plugin_dir / file_path).exists():
                missing_files.append(file_path)
        
        if missing_files:
            self.test_failed(test_name, f"Missing plugin files: {missing_files}")
            return False
            
        # Check if models directory exists in plugin
        models_dir = plugin_dir / "models"
        if models_dir.exists():
            self.log(f"  Models directory found in plugin: {list(models_dir.glob('*'))}")
        else:
            self.log(f"  No models directory in plugin (will use root models/)")
            
        self.test_passed(test_name)
        return True

    def test_10_performance_basic(self):
        """Test 10: Basic performance test."""
        test_name = "Basic Performance"
        
        exe_path = self.root / "plugin" / "WildlifeAI.lrplugin" / "bin" / "win" / "wildlifeai_runner_cpu.exe"
        
        with tempfile.TemporaryDirectory() as tmpdir:
            try:
                start_time = time.time()
                
                result = self.run_command([
                    str(exe_path),
                    "--self-test",
                    "--photo-list", "dummy.txt",
                    "--output-dir", tmpdir,
                    "--max-workers", "1"
                ], timeout=60)
                
                elapsed = time.time() - start_time
                
                if elapsed > 30:  # Should complete quickly in self-test mode
                    self.test_failed(test_name, f"Self-test took too long: {elapsed:.1f}s")
                    return False
                    
                self.log(f"  Self-test completed in {elapsed:.1f}s")
                self.test_passed(test_name)
                return True
                
            except Exception as e:
                self.test_failed(test_name, f"Performance test failed: {e}")
                return False

    def run_all_tests(self):
        """Run all test scenarios."""
        self.log("=" * 60)
        self.log("STARTING COMPREHENSIVE TEST SUITE")
        self.log("=" * 60)
        
        tests = [
            self.test_1_executable_exists,
            self.test_2_compatibility_runner,
            self.test_3_self_test_mode,
            self.test_4_csv_input_mode,
            self.test_5_real_image_processing,
            self.test_6_gpu_flag,
            self.test_7_parameter_variations,
            self.test_8_model_loading,
            self.test_9_plugin_integration,
            self.test_10_performance_basic,
        ]
        
        for test in tests:
            self.log("-" * 40)
            test()
            
        self.log("=" * 60)
        self.log("TEST RESULTS SUMMARY")
        self.log("=" * 60)
        
        for test_name, result in self.results:
            status = "✓" if result == "PASSED" else "✗"
            self.log(f"{status} {test_name}: {result}")
            
        self.log("-" * 40)
        self.log(f"TOTAL: {self.passed_tests}/{self.total_tests} tests passed")
        
        if self.passed_tests == self.total_tests:
            self.log("🎉 ALL TESTS PASSED! The enhanced runner is ready for use.", "SUCCESS")
            return True
        else:
            self.log(f"❌ {self.total_tests - self.passed_tests} tests failed. Review the issues above.", "ERROR")
            return False

def main():
    """Main test function."""
    tester = TestRunner()
    success = tester.run_all_tests()
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())