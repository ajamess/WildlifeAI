# 🤝 Contributing to WildlifeAI

Thank you for your interest in contributing to WildlifeAI! This project aims to revolutionize wildlife photography workflows through AI-powered automation.

## 🌟 How You Can Contribute

### 🐛 **Bug Reports**
- **Search existing issues** before creating new ones
- **Use the bug report template** with detailed steps to reproduce
- **Include system information**: OS, Lightroom version, plugin version
- **Attach log files** from WildlifeAI debug output

### 💡 **Feature Requests**
- **Check the roadmap** to see if it's already planned
- **Describe the use case** and how it benefits wildlife photographers
- **Consider implementation complexity** and maintenance burden

### 🔧 **Code Contributions**
- **Fork the repository** and create a feature branch
- **Follow coding standards** outlined below
- **Add tests** for new functionality
- **Update documentation** for user-facing changes

### 📚 **Documentation**
- **Improve README.md** with better examples or clarity
- **Add code comments** for complex algorithms
- **Create tutorials** for advanced workflows
- **Translate** documentation to other languages

### 🧪 **Testing & QA**
- **Test on different hardware** configurations
- **Validate AI model accuracy** with your bird photos
- **Report performance issues** with specific details
- **Beta test** new features before release

## 🛠️ Development Setup

### **Prerequisites**
```bash
# Required software
- Python 3.8+ with pip
- Adobe Lightroom Classic
- Git with LFS support
- Visual Studio Code (recommended)
```

### **Clone & Setup**
```bash
# Clone the repository
git clone https://github.com/your-repo/wildlife-ai.git
cd wildlife-ai

# Set up Python virtual environment
python -m venv .venv
source .venv/bin/activate  # Linux/Mac
# or
.venv\Scripts\activate     # Windows

# Install dependencies
pip install -r python/runner/requirements.txt
pip install -r requirements-dev.txt

# Install Git LFS for model files
git lfs install
git lfs pull
```

### **Development Workflow**
```bash
# Create feature branch
git checkout -b feature/my-awesome-feature

# Make changes and test
python scripts/test_all_scenarios.py

# Run linting
black python/
flake8 python/

# Commit with descriptive message
git commit -m "feat: add awesome new feature"

# Push and create pull request
git push origin feature/my-awesome-feature
```

## 📋 Coding Standards

### **Python Code (AI Runner)**
```python
# Use Black formatter with 88-character line length
# Follow PEP 8 naming conventions
# Add type hints for all functions
# Include comprehensive docstrings

def process_photo(photo_path: str, config: Dict[str, Any]) -> Dict[str, float]:
    """
    Process a single photo through the AI pipeline.
    
    Args:
        photo_path: Absolute path to the photo file
        config: Processing configuration dictionary
        
    Returns:
        Dictionary containing species, confidence, and quality scores
        
    Raises:
        FileNotFoundError: If photo_path does not exist
        ProcessingError: If AI model fails to process the image
    """
    pass
```

### **Lua Code (Lightroom Plugin)**
```lua
-- Use descriptive variable names
-- Add comments for complex logic
-- Handle errors gracefully with pcall
-- Log important operations

local function processPhotoBatch(photos, callback)
  local clk = Log.enter('processPhotoBatch')
  
  for i, photo in ipairs(photos) do
    local success, err = pcall(function()
      -- Processing logic here
      if callback then callback(i, #photos, photo) end
    end)
    
    if not success then
      Log.error('Failed to process photo: ' .. tostring(err))
    end
  end
  
  Log.leave(clk, 'processPhotoBatch')
end
```

### **Commit Message Format**
```
type(scope): brief description

Longer description explaining the motivation for the change
and what was changed.

Closes #123
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
**Scopes**: `ai`, `ui`, `metadata`, `keywords`, `analytics`, `build`

## 🧪 Testing Guidelines

### **Unit Tests**
```python
# Test files: tests/test_*.py
# Use pytest framework
# Mock external dependencies
# Test edge cases and error conditions

def test_species_classification_confidence():
    """Test that species classification returns valid confidence scores."""
    classifier = SpeciesClassifier("models/test_model.onnx")
    result = classifier.classify_bird(test_image)
    
    assert 0.0 <= result.confidence <= 1.0
    assert result.species in VALID_SPECIES_LIST
```

### **Integration Tests**
```python
# Test complete workflows
# Use real (but small) test datasets
# Validate end-to-end functionality

def test_full_analysis_workflow():
    """Test complete photo analysis from input to metadata."""
    runner = EnhancedModelRunner()
    results = runner.process_batch(TEST_PHOTOS, temp_output_dir)
    
    assert len(results) == len(TEST_PHOTOS)
    for result in results:
        assert result['species'] is not None
        assert 0 <= result['quality'] <= 100
```

### **Manual Testing Checklist**
- [ ] Install plugin in clean Lightroom environment
- [ ] Test with various image formats (RAW, JPEG, TIFF)
- [ ] Verify metadata appears in Lightroom panels
- [ ] Test batch processing with 100+ photos
- [ ] Validate keyword generation and hierarchy
- [ ] Check IPTC metadata export
- [ ] Test error handling with corrupted images
- [ ] Verify GPU/CPU processing modes

## 🚀 Release Process

### **Version Numbering**
- **Major.Minor.Patch** (e.g., 1.2.3)
- **Major**: Breaking changes, new AI models
- **Minor**: New features, significant improvements
- **Patch**: Bug fixes, minor enhancements

### **Release Checklist**
- [ ] Update version in `plugin/WildlifeAI.lrplugin/Info.lua`
- [ ] Update `docs/CHANGELOG.md`
- [ ] Run full test suite
- [ ] Build executables for Windows and macOS
- [ ] Create release notes with feature highlights
- [ ] Tag release in Git
- [ ] Upload binaries to GitHub Releases
- [ ] Update documentation links

## 🌍 Community Guidelines

### **Code of Conduct**
- **Be respectful** of all contributors regardless of experience level
- **Focus on wildlife conservation** and photographer empowerment
- **Provide constructive feedback** in code reviews
- **Help newcomers** get started with development

### **Communication Channels**
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and community chat
- **Discord**: Real-time development chat
- **Email**: security@wildlife-ai.com for security issues

### **Recognition**
Contributors will be recognized in:
- **README.md acknowledgments** for significant contributions
- **Release notes** for features and fixes
- **Contributors file** for all participants
- **Special badges** for long-term maintainers

## 🔬 AI Model Development

### **Species Model Contributions**
```python
# Guidelines for improving species identification
- Use ethically sourced training data
- Validate with expert ornithologists
- Test across geographic regions
- Document training procedures
- Share model performance metrics
```

### **Quality Model Improvements**
```python
# Guidelines for quality assessment models
- Train on photographer-rated datasets
- Consider multiple quality factors
- Validate against professional standards
- Document bias and limitations
- Test with diverse photography styles
```

### **Data Contributions**
- **Species datasets**: Coordinate with Project Kestrel
- **Quality ratings**: Submit photographer evaluations
- **Regional data**: Help expand geographic coverage
- **Edge cases**: Contribute challenging examples

## 📈 Performance Optimization

### **Profiling Guidelines**
```python
# Use cProfile for Python performance analysis
python -m cProfile -o profile_output.prof scripts/test_performance.py

# Use memory_profiler for memory analysis
@profile
def memory_intensive_function():
    pass
```

### **Optimization Targets**
- **Processing speed**: Photos per minute on standard hardware
- **Memory usage**: Peak RAM during batch processing
- **Model accuracy**: Species identification precision/recall
- **User experience**: Time to first result, progress feedback

## 🔐 Security Considerations

### **Responsible Disclosure**
- **Report security issues** privately to security@wildlife-ai.com
- **Allow 90 days** for fixes before public disclosure
- **Coordinate** with maintainers on disclosure timeline

### **Privacy Guidelines**
- **No telemetry** collection without explicit user consent
- **Local processing** - photos never leave user's computer
- **EXIF data protection** - handle location data carefully
- **User configuration** - don't log sensitive paths or settings

---

## 🎯 Getting Started

Ready to contribute? Here's how to get started:

1. **🍴 Fork the repository** on GitHub
2. **📥 Clone your fork** locally
3. **🔧 Set up development environment** following the guide above
4. **🐛 Pick an issue** from our [Good First Issues](https://github.com/your-repo/wildlife-ai/labels/good%20first%20issue) label
5. **💬 Join our Discord** for development discussions
6. **🚀 Submit your first pull request**!

**Every contribution matters** - from fixing typos to implementing new AI models. Thank you for helping make wildlife photography more accessible and enjoyable! 🦅📸

---

<div align="center">

**Questions? Reach out on [Discord](https://discord.gg/wildlife-ai) or [create an issue](https://github.com/your-repo/wildlife-ai/issues/new)!**

</div>
