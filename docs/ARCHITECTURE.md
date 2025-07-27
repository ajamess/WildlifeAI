# WildlifeAI Architecture

WildlifeAI is composed of two main parts:

1. **Lightroom plug-in** written in Lua. It integrates into Lightroom Classic and
   provides menu entries, metadata fields and smart collections. The plug-in
   communicates with the Python runner and applies the returned results to the
   selected photos.
2. **Python runner** that performs machine learning inference. It loads the ONNX
   and Keras models found in the `models/` directory and outputs JSON files that
   describe the detected species, quality score and other metrics.

## Flow of Data

1. A user selects photos and chooses *Analyze Selected Photos*.
2. The plug-in creates a temporary list of file paths and calls the platform
   specific runner binary located in `bin/win/` or `bin/mac/`.
3. The runner reads each image, runs inference and writes a JSON file either next
   to the source image or inside `Pictures/.wai` when that is not possible.
4. After the runner exits, the plug-in parses the JSON results and writes the
   values into Lightroom custom metadata fields.
5. Optional keywords and smart collections can then be used for filtering and
   organisation within Lightroom.

All logging performed by the Lua side is written to `plugin/WildlifeAI.lrplugin/logs/wildlifeai.log`.
