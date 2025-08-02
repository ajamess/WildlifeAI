# Save this as: scripts/test_enhanced_runner.py
#!/usr/bin/env python3
"""
Test script to validate the enhanced runner before building
"""
import sys
import subprocess
import tempfile
from pathlib import Path

def test_runner():
    """Test the enhanced runner functionality."""
    root = Path(__file__).parent.parent
    runner_path = root / "python" / "runner" / "wildlifeai_runner.py"
    
    if not runner_path.exists():
        print(f"ERROR: Enhanced runner not found at {runner_path}")
        return False
    
    print("Testing enhanced runner...")
    
    # Test 1: Check help command
    try:
        result = subprocess.run([
            sys.executable, str(runner_path), "--help"
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode != 0:
            print(f"ERROR: Help command failed: {result.stderr}")
            return False
        print("✓ Help command works")
    except Exception as e:
        print(f"ERROR: Failed to run help command: {e}")
        return False
    
    # Test 2: Test self-test mode
    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            result = subprocess.run([
                sys.executable, str(runner_path),
                "--self-test",
                "--photo-list", "dummy.txt",  # Not used in self-test
                "--output-dir", tmpdir,
                "--verbose"
            ], capture_output=True, text=True, timeout=60)
            
            if result.returncode != 0:
                print(f"ERROR: Self-test failed: {result.stderr}")
                return False
            
            # Check if output file was created
            output_files = list(Path(tmpdir).glob("*.json"))
            if not output_files:
                print("ERROR: Self-test didn't create output files")
                return False
                
        print("✓ Self-test mode works")
    except Exception as e:
        print(f"ERROR: Self-test failed: {e}")
        return False
    
    print("Enhanced runner validation: PASSED")
    return True

def check_dependencies():
    """Check if required dependencies are available."""
    print("Checking dependencies...")
    
    required = ['numpy', 'PIL', 'json', 'pathlib']
    optional = ['cv2', 'onnxruntime', 'tensorflow', 'rawpy']
    
    missing_required = []
    missing_optional = []
    
    for dep in required:
        try:
            __import__(dep)
            print(f"✓ {dep}")
        except ImportError:
            missing_required.append(dep)
            print(f"✗ {dep} (REQUIRED)")
    
    for dep in optional:
        try:
            __import__(dep)
            print(f"✓ {dep}")
        except ImportError:
            missing_optional.append(dep)
            print(f"- {dep} (optional)")
    
    if missing_required:
        print(f"ERROR: Missing required dependencies: {missing_required}")
        return False
    
    if missing_optional:
        print(f"INFO: Missing optional dependencies: {missing_optional}")
        print("The runner will work but with limited functionality")
    
    return True

def main():
    """Main test function."""
    print("=== Enhanced Runner Validation ===")
    
    if not check_dependencies():
        return 1
    
    if not test_runner():
        return 1
    
    print("\n=== All Tests Passed ===")
    print("The enhanced runner is ready for building!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
