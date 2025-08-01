-- WildlifeAI SmartBridge.lua with per-photo processing and state tracking
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local LrDialogs = import 'LrDialogs'
local LrProgressScope = import 'LrProgressScope'
local json = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/dkjson.lua') )
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local KeywordHelper = dofile( LrPathUtils.child(_PLUGIN.path, 'KeywordHelper.lua') )

local M = {}

local function isWin()
  return WIN_ENV or LrPathUtils.separator == '\\'
end

local function quote(p) 
  if isWin() then return '"'..p..'"' else return "'"..p.."'" end 
end

local function safeCreateTempFile(content, prefix)
  -- Use system temp directory but with delayed execution to avoid cleanup
  local tempDir = LrPathUtils.getStandardFilePath('temp')
  Log.info('Using system temp directory with delayed execution: ' .. tempDir)
  
  local timestamp = os.time()
  local attempts = 0
  local maxAttempts = 5
  
  while attempts < maxAttempts do
    local filename = prefix .. '_' .. timestamp .. '_' .. attempts .. '.txt'
    local filepath = LrPathUtils.child(tempDir, filename)
    
    Log.info('Attempting to create temp file: ' .. filepath)
    
    -- Use io.open with proper UTF-8 handling
    local success, f = pcall(io.open, filepath, 'w')
    if success and f then
      local writeSuccess, err = pcall(function()
        -- Ensure content is plain ASCII/UTF-8 (no BOM)
        f:write(content)
        f:close()
      end)
      
      if writeSuccess then
        Log.info('Successfully created temp file: ' .. filepath)
        
        -- Verify the file was created and is readable
        if LrFileUtils.exists(filepath) then
          local verifyContent = LrFileUtils.readFile(filepath)
          if verifyContent and #verifyContent > 0 then
            Log.info('Temp file verification successful: ' .. #verifyContent .. ' chars')
            return filepath
          else
            Log.error('Temp file verification failed - empty or unreadable')
          end
        else
          Log.error('Temp file does not exist after creation')
        end
      else
        Log.error('Failed to write to temp file: ' .. tostring(err))
      end
    else
      Log.error('Failed to create temp file: ' .. tostring(f))
    end
    
    attempts = attempts + 1
    -- Brief delay before retry (platform-independent)
    local startTime = os.clock()
    while os.clock() - startTime < 0.1 do
      -- Small delay
    end
  end
  
  error('Failed to create temp file after ' .. maxAttempts .. ' attempts')
end

local function getPhotoOutputDir(photoPath)
  local photoDir = LrPathUtils.parent(photoPath)
  return LrPathUtils.child(photoDir, '.wildlifeai')
end

local function isPhotoProcessed(photo)
  -- Check if photo has been processed by looking for plugin property
  local processed = photo:getPropertyForPlugin(_PLUGIN, 'wai_processed')
  return processed == 'true'
end

local function markPhotoAsProcessed(photo, processed)
  photo:setPropertyForPlugin(_PLUGIN, 'wai_processed', processed and 'true' or 'false')
end

local function getExistingResults(photoPath)
  local outputDir = getPhotoOutputDir(photoPath)
  local filename = LrPathUtils.leafName(photoPath)
  local resultFile = LrPathUtils.child(outputDir, filename .. '.json')
  
  if LrFileUtils.exists(resultFile) then
    local content = LrFileUtils.readFile(resultFile)
    if content then
      local ok, data = pcall(json.decode, content)
      if ok then
        Log.info('Found existing results for: ' .. filename)
        return data
      end
    end
  end
  
  return nil
end

local function savePhotoResults(photoPath, results)
  local outputDir = getPhotoOutputDir(photoPath)
  
  -- Validate inputs
  if not photoPath or photoPath == '' then
    Log.error('savePhotoResults: Invalid photoPath')
    return false
  end
  
  if not results then
    Log.error('savePhotoResults: No results to save')
    return false
  end
  
  -- Ensure output directory exists
  local dirOk = pcall(LrFileUtils.createAllDirectories, outputDir)
  if not dirOk then
    Log.error('Failed to create output directory: ' .. tostring(outputDir))
    return false
  end
  
  local filename = LrPathUtils.leafName(photoPath)
  local resultFile = LrPathUtils.child(outputDir, filename .. '.json')
  
  -- Encode JSON with error handling
  local ok, jsonData = pcall(json.encode, results)
  if not ok then
    Log.error('Failed to encode JSON for: ' .. filename .. ', error: ' .. tostring(jsonData))
    return false
  end
  
  if not jsonData or jsonData == '' then
    Log.error('JSON encoding produced empty data for: ' .. filename)
    return false
  end
  
  -- Try LrFileUtils.writeFile first, then fallback to standard Lua I/O
  local success = false
  
  if LrFileUtils and LrFileUtils.writeFile then
    local writeOk, writeErr = pcall(function()
      return LrFileUtils.writeFile(resultFile, jsonData)
    end)
    
    if writeOk and writeErr then
      Log.info('Saved results using LrFileUtils for: ' .. filename .. ' to ' .. resultFile)
      success = true
    else
      Log.warning('LrFileUtils.writeFile failed for: ' .. filename .. ', error: ' .. tostring(writeErr) .. ', trying fallback...')
    end
  else
    Log.warning('LrFileUtils.writeFile is not available, using fallback I/O for: ' .. filename)
  end
  
  -- Fallback: try using standard Lua file I/O
  if not success then
    local fallbackOk, fallbackErr = pcall(function()
      local file = io.open(resultFile, 'w')
      if file then
        file:write(jsonData)
        file:close()
        return true
      else
        return false, 'Could not open file for writing'
      end
    end)
    
    if fallbackOk and fallbackErr then
      Log.info('Saved results using fallback Lua I/O for: ' .. filename)
      success = true
    else
      Log.error('Both LrFileUtils and fallback I/O failed for: ' .. filename .. ', fallback error: ' .. tostring(fallbackErr))
    end
  end
  
  return success
end

local function findBestRunner()
  local prefs = LrPrefs.prefsForPlugin()
  local binDir = LrPathUtils.child(_PLUGIN.path, isWin() and 'bin/win' or 'bin/mac')
  
  -- Priority order for runner selection
  local candidates = {}
  
  if isWin() then
    -- Use debug wrapper for comprehensive logging
    local debugWrapper = LrPathUtils.child(binDir, 'debug_wrapper.bat')
    if LrFileUtils.exists(debugWrapper) then
      table.insert(candidates, debugWrapper)
      Log.info('Debug wrapper found, will use for debugging')
    end
    
    -- Original runners as fallback
    if prefs.useGPU then
      table.insert(candidates, LrPathUtils.child(binDir, 'wildlifeai_runner_gpu.exe'))
    end
    table.insert(candidates, LrPathUtils.child(binDir, 'wildlifeai_runner_cpu.exe'))
    table.insert(candidates, LrPathUtils.child(binDir, 'kestrel_runner.exe'))  -- fallback
  else
    -- macOS: single universal binary
    table.insert(candidates, LrPathUtils.child(binDir, 'wildlifeai_runner'))
    table.insert(candidates, LrPathUtils.child(binDir, 'kestrel_runner'))  -- fallback
  end
  
  -- Find first existing runner
  for _, runner in ipairs(candidates) do
    if LrFileUtils.exists(runner) then
      Log.info('Selected runner: ' .. runner)
      return runner
    end
  end
  
  -- No bundled runner found, try system Python approach
  Log.warning('No bundled runner found, falling back to system Python')
  return nil
end

function M.findSystemPythonRunner()
  -- This is a fallback for development or custom installations
  local prefs = LrPrefs.prefsForPlugin()
  local scriptPath = LrPathUtils.child(_PLUGIN.path, '../python/runner/wildlifeai_runner.py')
  
  if not LrFileUtils.exists(scriptPath) then
    return nil, nil
  end
  
  -- Try configured Python binary first
  local pythonBinary = isWin() and (prefs.pythonBinaryWin or 'python.exe') 
                                or (prefs.pythonBinaryMac or 'python3')
  
  return pythonBinary, scriptPath
end

function M.clearProcessingState(photos)
  -- Function to clear processing state for reprocessing
  local clk = Log.enter('SmartBridge.clearProcessingState')
  
  for _, photo in ipairs(photos) do
    markPhotoAsProcessed(photo, false)
    Log.info('Cleared processing state for: ' .. LrPathUtils.leafName(photo:getRawMetadata('path')))
  end
  
  Log.leave(clk, 'SmartBridge.clearProcessingState')
end

-- Simplified function to apply ONLY safe, non-yielding metadata operations (for real-time updates)
local function applySimpleNonYieldingMetadata(photo, data, prefs)
  local photoPath = photo:getRawMetadata('path')
  
  -- Safe property setting with nil checks
  local function set(id, v) 
    local value = tostring(v or '')
    if photo and photo.setPropertyForPlugin then
      photo:setPropertyForPlugin(_PLUGIN, id, value)
    else
      Log.error('Invalid photo object for property setting: ' .. tostring(photo))
    end
  end
  
  -- Set all properties with meaningful defaults and enhanced precision
  local species = data.detected_species or 'Unknown'
  local speciesConf = data.species_confidence or 0
  local quality = data.quality or -1
  local rating = data.rating or 0
  local sceneCount = data.scene_count or 1
  
  -- Helper function for formatting with 2 decimal precision for 0-100 scale values
  local function formatPrecision(value, is0to100Scale)
    if not value or value < 0 then return 'N/A' end
    if is0to100Scale and value >= 0 and value <= 100 then
      return string.format('%.2f', value)
    else
      return tostring(value)
    end
  end
  
  -- Set plugin metadata with enhanced precision (SAFE - no yielding)
  set('wai_detectedSpecies', species ~= 'Unknown' and species or 'No Bird Detected')
  set('wai_speciesConfidence', formatPrecision(speciesConf, true)) -- 0-100 scale
  set('wai_quality', formatPrecision(quality, true)) -- 0-100 scale  
  set('wai_rating', rating > 0 and tostring(rating) or 'Not Rated')
  set('wai_sceneCount', tostring(sceneCount))
  set('wai_featureSimilarity', formatPrecision(data.feature_similarity, true)) -- 0-100 scale
  set('wai_featureConfidence', formatPrecision(data.feature_confidence, true)) -- 0-100 scale
  set('wai_colorSimilarity', formatPrecision(data.color_similarity, true)) -- 0-100 scale
  set('wai_colorConfidence', formatPrecision(data.color_confidence, true)) -- 0-100 scale
  set('wai_jsonPath', data.json_path or '')
  set('wai_processed', 'true')
  
  Log.info('Set plugin metadata for ' .. LrPathUtils.leafName(photoPath) .. ': Species=' .. 
           (species ~= 'Unknown' and species or 'No Bird Detected') .. 
           ', Quality=' .. (quality >= 0 and tostring(quality) or 'N/A') ..
           ', Rating=' .. rating)
  
  -- Apply automatic rating, flagging, and color labeling based on preferences (SAFE - no yielding)
  local ratingValue = rating
  local qualityValue = quality >= 0 and quality or 0
  
  -- Set star rating (0-5 stars) - SAFE operation
  if prefs.enableRating and photo.setRawMetadata then
    local success, err = pcall(function()
      photo:setRawMetadata('rating', ratingValue)
    end)
    if not success then
      Log.error('Failed to set rating: ' .. tostring(err))
    else
      Log.info('Set rating: ' .. ratingValue .. ' stars for ' .. LrPathUtils.leafName(photoPath))
    end
  end
  
  -- Enhanced rejection/picks logic with quality mode support
  local qualityMode = prefs.qualityMode or 'rating'
  
  -- Set rejection flag for low quality photos - SAFE operation
  if prefs.enableRejection and photo.setRawMetadata then
    local shouldReject = false
    local thresholdDesc = ''
    
    if qualityMode == 'quality' then
      local threshold = prefs.rejectionQualityThreshold or 20
      shouldReject = qualityValue <= threshold
      thresholdDesc = 'quality ' .. qualityValue .. ' <= ' .. threshold
    else
      local threshold = prefs.rejectionThreshold or 2
      shouldReject = ratingValue <= threshold
      thresholdDesc = 'rating ' .. ratingValue .. ' <= ' .. threshold
    end
    
    local success, err = pcall(function()
      photo:setRawMetadata('pickStatus', shouldReject and -1 or 0)
    end)
    if not success then
      Log.error('Failed to set rejection flag: ' .. tostring(err))
    elseif shouldReject then
      Log.info('Marked as rejected: ' .. LrPathUtils.leafName(photoPath) .. ' (' .. thresholdDesc .. ')')
    end
  end
  
  -- Set pick flag for high quality photos - SAFE operation
  if prefs.enablePicks and photo.setRawMetadata then
    local shouldPick = false
    local thresholdDesc = ''
    
    if qualityMode == 'quality' then
      local threshold = prefs.picksQualityThreshold or 80
      shouldPick = qualityValue >= threshold
      thresholdDesc = 'quality ' .. qualityValue .. ' >= ' .. threshold
    else
      local threshold = prefs.picksThreshold or 4
      shouldPick = ratingValue >= threshold
      thresholdDesc = 'rating ' .. ratingValue .. ' >= ' .. threshold
    end
    
    local success, err = pcall(function()
      photo:setRawMetadata('pickStatus', shouldPick and 1 or 0)
    end)
    if not success then
      Log.error('Failed to set pick flag: ' .. tostring(err))
    elseif shouldPick then
      Log.info('Marked as pick: ' .. LrPathUtils.leafName(photoPath) .. ' (' .. thresholdDesc .. ')')
    end
  end
  
  -- Enhanced color label logic with quality range support - SAFE operation
  if prefs.enableColorLabels and photo.setRawMetadata then
    local colorLabel = nil
    local colorLabelMode = prefs.colorLabelMode or 'rating'
    
    if colorLabelMode == 'quality' then
      -- Check each color range using separate min/max preferences with enable flags
      local ranges = {}
      
      -- Only add enabled ranges
      if prefs.colorRangeRedEnabled then
        table.insert(ranges, { 
          color = 'red', 
          min = tonumber(prefs.colorRangeRedMin) or 0, 
          max = tonumber(prefs.colorRangeRedMax) or 20 
        })
      end
      
      if prefs.colorRangeYellowEnabled then
        table.insert(ranges, { 
          color = 'yellow', 
          min = tonumber(prefs.colorRangeYellowMin) or 21, 
          max = tonumber(prefs.colorRangeYellowMax) or 40 
        })
      end
      
      if prefs.colorRangeGreenEnabled then
        table.insert(ranges, { 
          color = 'green', 
          min = tonumber(prefs.colorRangeGreenMin) or 41, 
          max = tonumber(prefs.colorRangeGreenMax) or 60 
        })
      end
      
      if prefs.colorRangeBlueEnabled then
        table.insert(ranges, { 
          color = 'blue', 
          min = tonumber(prefs.colorRangeBlueMin) or 61, 
          max = tonumber(prefs.colorRangeBlueMax) or 80 
        })
      end
      
      if prefs.colorRangePurpleEnabled then
        table.insert(ranges, { 
          color = 'purple', 
          min = tonumber(prefs.colorRangePurpleMin) or 81, 
          max = tonumber(prefs.colorRangePurpleMax) or 100 
        })
      end
      
      -- Add "none" range if enabled
      if prefs.colorRangeNoneEnabled then
        table.insert(ranges, { 
          color = 'none', 
          min = tonumber(prefs.colorRangeNoneMin) or 0, 
          max = tonumber(prefs.colorRangeNoneMax) or 0 
        })
      end
      
      for _, colorRange in ipairs(ranges) do
        if qualityValue >= colorRange.min and qualityValue <= colorRange.max then
          colorLabel = colorRange.color
          Log.info('Quality ' .. qualityValue .. ' matches ' .. colorRange.color .. ' range ' .. colorRange.min .. '-' .. colorRange.max)
          break
        end
      end
    else
      -- Rating-based color mapping (0-5)
      if ratingValue == 0 then colorLabel = prefs.colorLabel0
      elseif ratingValue == 1 then colorLabel = prefs.colorLabel1
      elseif ratingValue == 2 then colorLabel = prefs.colorLabel2
      elseif ratingValue == 3 then colorLabel = prefs.colorLabel3
      elseif ratingValue == 4 then colorLabel = prefs.colorLabel4
      elseif ratingValue == 5 then colorLabel = prefs.colorLabel5
      end
    end
    
    if colorLabel and colorLabel ~= 'none' then
      local success, err = pcall(function()
        photo:setRawMetadata('colorNameForLabel', colorLabel)
      end)
      if not success then
        Log.error('Failed to set color label: ' .. tostring(err))
      else
        local basis = colorLabelMode == 'quality' and ('quality ' .. qualityValue) or ('rating ' .. ratingValue)
        Log.info('Set color label: ' .. colorLabel .. ' for ' .. LrPathUtils.leafName(photoPath) .. ' (' .. basis .. ')')
      end
    end
  end
  
  -- NOTE: IPTC mirroring, job identifier, and XMP writing are NOT included here
  -- These operations will be handled in the batch processing phase to avoid yielding issues
  
  Log.info('Simple non-yielding metadata applied for: ' .. LrPathUtils.leafName(photoPath))
end

-- Helper function to apply only non-yielding metadata (for real-time updates)
local function applyNonYieldingMetadata(photo, data, catalog, prefs)
  local photoPath = photo:getRawMetadata('path')
  
  -- Safe property setting with nil checks
  local function set(id, v) 
    local value = tostring(v or '')
    if photo and photo.setPropertyForPlugin then
      photo:setPropertyForPlugin(_PLUGIN, id, value)
    else
      Log.error('Invalid photo object for property setting: ' .. tostring(photo))
    end
  end
  
  -- Set all properties with meaningful defaults and enhanced precision
  local species = data.detected_species or 'Unknown'
  local speciesConf = data.species_confidence or 0
  local quality = data.quality or -1
  local rating = data.rating or 0
  local sceneCount = data.scene_count or 1
  
  -- Helper function for formatting with 2 decimal precision for 0-100 scale values
  local function formatPrecision(value, is0to100Scale)
    if not value or value < 0 then return 'N/A' end
    if is0to100Scale and value >= 0 and value <= 100 then
      return string.format('%.2f', value)
    else
      return tostring(value)
    end
  end
  
  -- Set plugin metadata with enhanced precision
  set('wai_detectedSpecies', species ~= 'Unknown' and species or 'No Bird Detected')
  set('wai_speciesConfidence', formatPrecision(speciesConf, true)) -- 0-100 scale
  set('wai_quality', formatPrecision(quality, true)) -- 0-100 scale  
  set('wai_rating', rating > 0 and tostring(rating) or 'Not Rated')
  set('wai_sceneCount', tostring(sceneCount))
  set('wai_featureSimilarity', formatPrecision(data.feature_similarity, true)) -- 0-100 scale
  set('wai_featureConfidence', formatPrecision(data.feature_confidence, true)) -- 0-100 scale
  set('wai_colorSimilarity', formatPrecision(data.color_similarity, true)) -- 0-100 scale
  set('wai_colorConfidence', formatPrecision(data.color_confidence, true)) -- 0-100 scale
  set('wai_jsonPath', data.json_path or '')
  set('wai_processed', 'true')
  
  Log.info('Set metadata for ' .. LrPathUtils.leafName(photoPath) .. ': Species=' .. 
           (species ~= 'Unknown' and species or 'No Bird Detected') .. 
           ', Quality=' .. (quality >= 0 and tostring(quality) or 'N/A') ..
           ', Rating=' .. rating)
  
  -- Apply automatic rating, flagging, and color labeling based on preferences
  local ratingValue = rating
  local qualityValue = quality >= 0 and quality or 0
  
  -- Set star rating (0-5 stars)
  if prefs.enableRating and photo.setRawMetadata then
    local success, err = pcall(function()
      photo:setRawMetadata('rating', ratingValue)
    end)
    if not success then
      Log.error('Failed to set rating: ' .. tostring(err))
    else
      Log.info('Set rating: ' .. ratingValue .. ' stars for ' .. LrPathUtils.leafName(photoPath))
    end
  end
  
  -- Enhanced rejection/picks logic with quality mode support
  local qualityMode = prefs.qualityMode or 'rating'
  
  -- Set rejection flag for low quality photos
  if prefs.enableRejection and photo.setRawMetadata then
    local shouldReject = false
    local thresholdDesc = ''
    
    if qualityMode == 'quality' then
      local threshold = prefs.rejectionQualityThreshold or 20
      shouldReject = qualityValue <= threshold
      thresholdDesc = 'quality ' .. qualityValue .. ' <= ' .. threshold
    else
      local threshold = prefs.rejectionThreshold or 2
      shouldReject = ratingValue <= threshold
      thresholdDesc = 'rating ' .. ratingValue .. ' <= ' .. threshold
    end
    
    local success, err = pcall(function()
      photo:setRawMetadata('pickStatus', shouldReject and -1 or 0)
    end)
    if not success then
      Log.error('Failed to set rejection flag: ' .. tostring(err))
    elseif shouldReject then
      Log.info('Marked as rejected: ' .. LrPathUtils.leafName(photoPath) .. ' (' .. thresholdDesc .. ')')
    end
  end
  
  -- Set pick flag for high quality photos
  if prefs.enablePicks and photo.setRawMetadata then
    local shouldPick = false
    local thresholdDesc = ''
    
    if qualityMode == 'quality' then
      local threshold = prefs.picksQualityThreshold or 80
      shouldPick = qualityValue >= threshold
      thresholdDesc = 'quality ' .. qualityValue .. ' >= ' .. threshold
    else
      local threshold = prefs.picksThreshold or 4
      shouldPick = ratingValue >= threshold
      thresholdDesc = 'rating ' .. ratingValue .. ' >= ' .. threshold
    end
    
    local success, err = pcall(function()
      photo:setRawMetadata('pickStatus', shouldPick and 1 or 0)
    end)
    if not success then
      Log.error('Failed to set pick flag: ' .. tostring(err))
    elseif shouldPick then
      Log.info('Marked as pick: ' .. LrPathUtils.leafName(photoPath) .. ' (' .. thresholdDesc .. ')')
    end
  end
  
  -- Enhanced color label logic with quality range support
  if prefs.enableColorLabels and photo.setRawMetadata then
    local colorLabel = nil
    local colorLabelMode = prefs.colorLabelMode or 'rating'
    
    if colorLabelMode == 'quality' then
      -- Quality range-based color mapping
      local function parseRange(rangeStr)
        if not rangeStr or rangeStr == '' then return nil end
        local min, max = string.match(rangeStr, '^(%d+)%-(%d+)$')
        if min and max then
          min, max = tonumber(min), tonumber(max)
          if min and max and min >= 0 and max <= 100 and min <= max then
            return { min = min, max = max }
          end
        end
        return nil
      end
      
      -- Check each color range using separate min/max preferences with enable flags
      local ranges = {}
      
      -- Only add enabled ranges
      if prefs.colorRangeRedEnabled then
        table.insert(ranges, { 
          color = 'red', 
          min = tonumber(prefs.colorRangeRedMin) or 0, 
          max = tonumber(prefs.colorRangeRedMax) or 20 
        })
      end
      
      if prefs.colorRangeYellowEnabled then
        table.insert(ranges, { 
          color = 'yellow', 
          min = tonumber(prefs.colorRangeYellowMin) or 21, 
          max = tonumber(prefs.colorRangeYellowMax) or 40 
        })
      end
      
      if prefs.colorRangeGreenEnabled then
        table.insert(ranges, { 
          color = 'green', 
          min = tonumber(prefs.colorRangeGreenMin) or 41, 
          max = tonumber(prefs.colorRangeGreenMax) or 60 
        })
      end
      
      if prefs.colorRangeBlueEnabled then
        table.insert(ranges, { 
          color = 'blue', 
          min = tonumber(prefs.colorRangeBlueMin) or 61, 
          max = tonumber(prefs.colorRangeBlueMax) or 80 
        })
      end
      
      if prefs.colorRangePurpleEnabled then
        table.insert(ranges, { 
          color = 'purple', 
          min = tonumber(prefs.colorRangePurpleMin) or 81, 
          max = tonumber(prefs.colorRangePurpleMax) or 100 
        })
      end
      
      -- Add "none" range if enabled
      if prefs.colorRangeNoneEnabled then
        table.insert(ranges, { 
          color = 'none', 
          min = tonumber(prefs.colorRangeNoneMin) or 0, 
          max = tonumber(prefs.colorRangeNoneMax) or 0 
        })
      end
      
      for _, colorRange in ipairs(ranges) do
        if qualityValue >= colorRange.min and qualityValue <= colorRange.max then
          colorLabel = colorRange.color
          Log.info('Quality ' .. qualityValue .. ' matches ' .. colorRange.color .. ' range ' .. colorRange.min .. '-' .. colorRange.max)
          break
        end
      end
    else
      -- Rating-based color mapping (0-5)
      if ratingValue == 0 then colorLabel = prefs.colorLabel0
      elseif ratingValue == 1 then colorLabel = prefs.colorLabel1
      elseif ratingValue == 2 then colorLabel = prefs.colorLabel2
      elseif ratingValue == 3 then colorLabel = prefs.colorLabel3
      elseif ratingValue == 4 then colorLabel = prefs.colorLabel4
      elseif ratingValue == 5 then colorLabel = prefs.colorLabel5
      end
    end
    
    if colorLabel and colorLabel ~= 'none' then
      local success, err = pcall(function()
        photo:setRawMetadata('colorNameForLabel', colorLabel)
      end)
      if not success then
        Log.error('Failed to set color label: ' .. tostring(err))
      else
        local basis = colorLabelMode == 'quality' and ('quality ' .. qualityValue) or ('rating ' .. ratingValue)
        Log.info('Set color label: ' .. colorLabel .. ' for ' .. LrPathUtils.leafName(photoPath) .. ' (' .. basis .. ')')
      end
    end
  end
  
  -- Enhanced IPTC mirroring with configurable fields and elements
  if prefs.enableIptcMirror and prefs.iptcField and prefs.iptcField ~= 'none' and photo.setRawMetadata then
    local elements = {}
    
    Log.info('IPTC Debug - enableIptcMirror: ' .. tostring(prefs.enableIptcMirror))
    Log.info('IPTC Debug - iptcField: ' .. tostring(prefs.iptcField))
    Log.info('IPTC Debug - includeQuality: ' .. tostring(prefs.includeQuality) .. ', quality: ' .. tostring(quality))
    Log.info('IPTC Debug - includeRating: ' .. tostring(prefs.includeRating) .. ', rating: ' .. tostring(rating))
    Log.info('IPTC Debug - includeSpeciesConfidence: ' .. tostring(prefs.includeSpeciesConfidence) .. ', speciesConf: ' .. tostring(speciesConf))
    Log.info('IPTC Debug - includeDetectedSpecies: ' .. tostring(prefs.includeDetectedSpecies) .. ', species: ' .. tostring(species))
    Log.info('IPTC Debug - includeSceneCount: ' .. tostring(prefs.includeSceneCount) .. ', sceneCount: ' .. tostring(sceneCount))
    Log.info('IPTC Debug - includeFeatureSimilarity: ' .. tostring(prefs.includeFeatureSimilarity) .. ', feature_similarity: ' .. tostring(data.feature_similarity))
    Log.info('IPTC Debug - includeFeatureConfidence: ' .. tostring(prefs.includeFeatureConfidence) .. ', feature_confidence: ' .. tostring(data.feature_confidence))
    Log.info('IPTC Debug - includeColorSimilarity: ' .. tostring(prefs.includeColorSimilarity) .. ', color_similarity: ' .. tostring(data.color_similarity))
    Log.info('IPTC Debug - includeColorConfidence: ' .. tostring(prefs.includeColorConfidence) .. ', color_confidence: ' .. tostring(data.color_confidence))
    Log.info('IPTC Debug - includeProcessingTime: ' .. tostring(prefs.includeProcessingTime) .. ', processing_time: ' .. tostring(data.processing_time))
    
    -- Build structured metadata string based on user preferences with 2-char qualifiers
    if prefs.includeQuality and quality >= 0 then
      local element = 'Qu:' .. formatPrecision(quality, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added quality element: ' .. element)
    end
    
    if prefs.includeRating and rating > 0 then
      local element = 'Ra:' .. tostring(rating)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added rating element: ' .. element)
    end
    
    if prefs.includeSpeciesConfidence and speciesConf >= 0 then
      local element = 'Co:' .. formatPrecision(speciesConf, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added species confidence element: ' .. element)
    end
    
    if prefs.includeDetectedSpecies and species and species ~= 'Unknown' and species ~= '' then
      -- Don't truncate species names - use full name for IPTC
      local element = 'Sp:' .. species
      table.insert(elements, element)
      Log.info('IPTC Debug - Added species element: ' .. element)
    end
    
    if prefs.includeSceneCount and sceneCount > 0 then
      local element = 'Sc:' .. tostring(sceneCount)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added scene count element: ' .. element)
    end
    
    if prefs.includeFeatureSimilarity and data.feature_similarity and data.feature_similarity >= 0 then
      local element = 'Fs:' .. formatPrecision(data.feature_similarity, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added feature similarity element: ' .. element)
    end
    
    if prefs.includeFeatureConfidence and data.feature_confidence and data.feature_confidence >= 0 then
      local element = 'Fc:' .. formatPrecision(data.feature_confidence, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added feature confidence element: ' .. element)
    end
    
    if prefs.includeColorSimilarity and data.color_similarity and data.color_similarity >= 0 then
      local element = 'Cs:' .. formatPrecision(data.color_similarity, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added color similarity element: ' .. element)
    end
    
    if prefs.includeColorConfidence and data.color_confidence and data.color_confidence >= 0 then
      local element = 'Cc:' .. formatPrecision(data.color_confidence, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added color confidence element: ' .. element)
    end
    
    if prefs.includeProcessingTime and data.processing_time and data.processing_time > 0 then
      local element = 'Pt:' .. string.format('%.2f', data.processing_time)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added processing time element: ' .. element)
    end
    
    Log.info('IPTC Debug - Total elements to include: ' .. #elements)
    if #elements > 0 then
      local iptcValue = 'WAI ' .. table.concat(elements, ' ')
      Log.info('IPTC Debug - Final IPTC value: ' .. iptcValue)
      local success, err = pcall(function()
        photo:setRawMetadata(prefs.iptcField, iptcValue)
      end)
      if not success then
        Log.error('Failed to set IPTC field ' .. prefs.iptcField .. ': ' .. tostring(err))
      else
        Log.info('Set IPTC ' .. prefs.iptcField .. ': ' .. iptcValue .. ' for ' .. LrPathUtils.leafName(photoPath))
      end
    else
      Log.warning('IPTC Debug - No elements to include in IPTC metadata')
    end
  else
    Log.info('IPTC Debug - IPTC mirroring not enabled or missing requirements')
  end
  
  -- Legacy job identifier support (for backward compatibility) - only if IPTC is not using jobIdentifier
  if prefs.mirrorJobId and photo.setRawMetadata and (not prefs.enableIptcMirror or prefs.iptcField ~= 'jobIdentifier') then
    local jid = string.format('Q:%s R:%s C:%s', formatPrecision(quality, true), rating, sceneCount)
    local success, err = pcall(function()
      photo:setRawMetadata('jobIdentifier', jid)
    end)
    if not success then
      Log.error('Failed to set job identifier: ' .. tostring(err))
    else
      Log.info('Set job identifier: ' .. jid .. ' for ' .. LrPathUtils.leafName(photoPath))
    end
  end
  
  -- Enhanced XMP writing with proper error handling and retry logic
  if prefs.writeXMP then
    local success, err = pcall(function()
      -- Force metadata to be written to XMP sidecar files
      if photo.saveMetadata then
        photo:saveMetadata()
        Log.info('Saved XMP metadata for: ' .. LrPathUtils.leafName(photoPath))
      else
        Log.warning('saveMetadata not available for photo: ' .. LrPathUtils.leafName(photoPath))
      end
    end)
    if not success then
      Log.error('Failed to save XMP metadata: ' .. tostring(err))
      
      -- Retry with alternative approach
      local retrySuccess, retryErr = pcall(function()
        -- Alternative: use catalog's saveMetadata if available
        if catalog and catalog.saveMetadata then
          catalog:saveMetadata(photo)
          Log.info('Saved XMP metadata via catalog for: ' .. LrPathUtils.leafName(photoPath))
        end
      end)
      if not retrySuccess then
        Log.error('XMP retry also failed: ' .. tostring(retryErr))
      end
    end
  end
  
  Log.info('Non-yielding metadata applied for: ' .. LrPathUtils.leafName(photoPath))
end

-- Helper function to apply metadata to a single photo (LEGACY - now includes keywords)
local function applyMetadataToPhoto(photo, results, catalog, prefs)
  local photoPath = photo:getRawMetadata('path')
  local d = results[photoPath] or {}
  
  -- Safe property setting with nil checks
  local function set(id, v) 
    local value = tostring(v or '')
    if photo and photo.setPropertyForPlugin then
      photo:setPropertyForPlugin(_PLUGIN, id, value)
    else
      Log.error('Invalid photo object for property setting: ' .. tostring(photo))
    end
  end
  
  -- Set all properties with meaningful defaults and enhanced precision
  local species = d.detected_species or 'Unknown'
  local speciesConf = d.species_confidence or 0
  local quality = d.quality or -1
  local rating = d.rating or 0
  local sceneCount = d.scene_count or 1
  
  -- Helper function for formatting with 2 decimal precision for 0-100 scale values
  local function formatPrecision(value, is0to100Scale)
    if not value or value < 0 then return 'N/A' end
    if is0to100Scale and value >= 0 and value <= 100 then
      return string.format('%.2f', value)
    else
      return tostring(value)
    end
  end
  
  -- Set plugin metadata with enhanced precision
  set('wai_detectedSpecies', species ~= 'Unknown' and species or 'No Bird Detected')
  set('wai_speciesConfidence', formatPrecision(speciesConf, true)) -- 0-100 scale
  set('wai_quality', formatPrecision(quality, true)) -- 0-100 scale  
  set('wai_rating', rating > 0 and tostring(rating) or 'Not Rated')
  set('wai_sceneCount', tostring(sceneCount))
  set('wai_featureSimilarity', formatPrecision(d.feature_similarity, true)) -- 0-100 scale
  set('wai_featureConfidence', formatPrecision(d.feature_confidence, true)) -- 0-100 scale
  set('wai_colorSimilarity', formatPrecision(d.color_similarity, true)) -- 0-100 scale
  set('wai_colorConfidence', formatPrecision(d.color_confidence, true)) -- 0-100 scale
  set('wai_jsonPath', d.json_path or '')
  set('wai_processed', 'true')
  
  Log.info('Set metadata for ' .. LrPathUtils.leafName(photoPath) .. ': Species=' .. 
           (species ~= 'Unknown' and species or 'No Bird Detected') .. 
           ', Quality=' .. (quality >= 0 and tostring(quality) or 'N/A') ..
           ', Rating=' .. rating)
  
  -- Apply automatic rating, flagging, and color labeling based on preferences
  local ratingValue = rating
  local qualityValue = quality >= 0 and quality or 0
  
  -- Set star rating (0-5 stars)
  if prefs.enableRating and photo.setRawMetadata then
    local success, err = pcall(function()
      photo:setRawMetadata('rating', ratingValue)
    end)
    if not success then
      Log.error('Failed to set rating: ' .. tostring(err))
    else
      Log.info('Set rating: ' .. ratingValue .. ' stars for ' .. LrPathUtils.leafName(photoPath))
    end
  end
  
  -- Enhanced rejection/picks logic with quality mode support
  local qualityMode = prefs.qualityMode or 'rating'
  
  -- Set rejection flag for low quality photos
  if prefs.enableRejection and photo.setRawMetadata then
    local shouldReject = false
    local thresholdDesc = ''
    
    if qualityMode == 'quality' then
      local threshold = prefs.rejectionQualityThreshold or 20
      shouldReject = qualityValue <= threshold
      thresholdDesc = 'quality ' .. qualityValue .. ' <= ' .. threshold
    else
      local threshold = prefs.rejectionThreshold or 2
      shouldReject = ratingValue <= threshold
      thresholdDesc = 'rating ' .. ratingValue .. ' <= ' .. threshold
    end
    
    local success, err = pcall(function()
      photo:setRawMetadata('pickStatus', shouldReject and -1 or 0)
    end)
    if not success then
      Log.error('Failed to set rejection flag: ' .. tostring(err))
    elseif shouldReject then
      Log.info('Marked as rejected: ' .. LrPathUtils.leafName(photoPath) .. ' (' .. thresholdDesc .. ')')
    end
  end
  
  -- Set pick flag for high quality photos
  if prefs.enablePicks and photo.setRawMetadata then
    local shouldPick = false
    local thresholdDesc = ''
    
    if qualityMode == 'quality' then
      local threshold = prefs.picksQualityThreshold or 80
      shouldPick = qualityValue >= threshold
      thresholdDesc = 'quality ' .. qualityValue .. ' >= ' .. threshold
    else
      local threshold = prefs.picksThreshold or 4
      shouldPick = ratingValue >= threshold
      thresholdDesc = 'rating ' .. ratingValue .. ' >= ' .. threshold
    end
    
    local success, err = pcall(function()
      photo:setRawMetadata('pickStatus', shouldPick and 1 or 0)
    end)
    if not success then
      Log.error('Failed to set pick flag: ' .. tostring(err))
    elseif shouldPick then
      Log.info('Marked as pick: ' .. LrPathUtils.leafName(photoPath) .. ' (' .. thresholdDesc .. ')')
    end
  end
  
  -- Enhanced color label logic with quality range support
  if prefs.enableColorLabels and photo.setRawMetadata then
    local colorLabel = nil
    local colorLabelMode = prefs.colorLabelMode or 'rating'
    
    if colorLabelMode == 'quality' then
      -- Quality range-based color mapping
      local function parseRange(rangeStr)
        if not rangeStr or rangeStr == '' then return nil end
        local min, max = string.match(rangeStr, '^(%d+)%-(%d+)$')
        if min and max then
          min, max = tonumber(min), tonumber(max)
          if min and max and min >= 0 and max <= 100 and min <= max then
            return { min = min, max = max }
          end
        end
        return nil
      end
      
      -- Check each color range using separate min/max preferences with enable flags
      local ranges = {}
      
      -- Only add enabled ranges
      if prefs.colorRangeRedEnabled then
        table.insert(ranges, { 
          color = 'red', 
          min = tonumber(prefs.colorRangeRedMin) or 0, 
          max = tonumber(prefs.colorRangeRedMax) or 20 
        })
      end
      
      if prefs.colorRangeYellowEnabled then
        table.insert(ranges, { 
          color = 'yellow', 
          min = tonumber(prefs.colorRangeYellowMin) or 21, 
          max = tonumber(prefs.colorRangeYellowMax) or 40 
        })
      end
      
      if prefs.colorRangeGreenEnabled then
        table.insert(ranges, { 
          color = 'green', 
          min = tonumber(prefs.colorRangeGreenMin) or 41, 
          max = tonumber(prefs.colorRangeGreenMax) or 60 
        })
      end
      
      if prefs.colorRangeBlueEnabled then
        table.insert(ranges, { 
          color = 'blue', 
          min = tonumber(prefs.colorRangeBlueMin) or 61, 
          max = tonumber(prefs.colorRangeBlueMax) or 80 
        })
      end
      
      if prefs.colorRangePurpleEnabled then
        table.insert(ranges, { 
          color = 'purple', 
          min = tonumber(prefs.colorRangePurpleMin) or 81, 
          max = tonumber(prefs.colorRangePurpleMax) or 100 
        })
      end
      
      -- Add "none" range if enabled
      if prefs.colorRangeNoneEnabled then
        table.insert(ranges, { 
          color = 'none', 
          min = tonumber(prefs.colorRangeNoneMin) or 0, 
          max = tonumber(prefs.colorRangeNoneMax) or 0 
        })
      end
      
      for _, colorRange in ipairs(ranges) do
        if qualityValue >= colorRange.min and qualityValue <= colorRange.max then
          colorLabel = colorRange.color
          Log.info('Quality ' .. qualityValue .. ' matches ' .. colorRange.color .. ' range ' .. colorRange.min .. '-' .. colorRange.max)
          break
        end
      end
    else
      -- Rating-based color mapping (0-5)
      if ratingValue == 0 then colorLabel = prefs.colorLabel0
      elseif ratingValue == 1 then colorLabel = prefs.colorLabel1
      elseif ratingValue == 2 then colorLabel = prefs.colorLabel2
      elseif ratingValue == 3 then colorLabel = prefs.colorLabel3
      elseif ratingValue == 4 then colorLabel = prefs.colorLabel4
      elseif ratingValue == 5 then colorLabel = prefs.colorLabel5
      end
    end
    
    if colorLabel and colorLabel ~= 'none' then
      local success, err = pcall(function()
        photo:setRawMetadata('colorNameForLabel', colorLabel)
      end)
      if not success then
        Log.error('Failed to set color label: ' .. tostring(err))
      else
        local basis = colorLabelMode == 'quality' and ('quality ' .. qualityValue) or ('rating ' .. ratingValue)
        Log.info('Set color label: ' .. colorLabel .. ' for ' .. LrPathUtils.leafName(photoPath) .. ' (' .. basis .. ')')
      end
    end
  end
  
  -- Enhanced IPTC mirroring with configurable fields and elements
  if prefs.enableIptcMirror and prefs.iptcField and prefs.iptcField ~= 'none' and photo.setRawMetadata then
    local elements = {}
    
    Log.info('IPTC Debug - enableIptcMirror: ' .. tostring(prefs.enableIptcMirror))
    Log.info('IPTC Debug - iptcField: ' .. tostring(prefs.iptcField))
    Log.info('IPTC Debug - includeQuality: ' .. tostring(prefs.includeQuality) .. ', quality: ' .. tostring(quality))
    Log.info('IPTC Debug - includeRating: ' .. tostring(prefs.includeRating) .. ', rating: ' .. tostring(rating))
    Log.info('IPTC Debug - includeSpeciesConfidence: ' .. tostring(prefs.includeSpeciesConfidence) .. ', speciesConf: ' .. tostring(speciesConf))
    Log.info('IPTC Debug - includeDetectedSpecies: ' .. tostring(prefs.includeDetectedSpecies) .. ', species: ' .. tostring(species))
    Log.info('IPTC Debug - includeSceneCount: ' .. tostring(prefs.includeSceneCount) .. ', sceneCount: ' .. tostring(sceneCount))
    Log.info('IPTC Debug - includeFeatureSimilarity: ' .. tostring(prefs.includeFeatureSimilarity) .. ', feature_similarity: ' .. tostring(d.feature_similarity))
    Log.info('IPTC Debug - includeFeatureConfidence: ' .. tostring(prefs.includeFeatureConfidence) .. ', feature_confidence: ' .. tostring(d.feature_confidence))
    Log.info('IPTC Debug - includeColorSimilarity: ' .. tostring(prefs.includeColorSimilarity) .. ', color_similarity: ' .. tostring(d.color_similarity))
    Log.info('IPTC Debug - includeColorConfidence: ' .. tostring(prefs.includeColorConfidence) .. ', color_confidence: ' .. tostring(d.color_confidence))
    Log.info('IPTC Debug - includeProcessingTime: ' .. tostring(prefs.includeProcessingTime) .. ', processing_time: ' .. tostring(d.processing_time))
    
    -- Build structured metadata string based on user preferences with 2-char qualifiers
    if prefs.includeQuality and quality >= 0 then
      local element = 'Qu:' .. formatPrecision(quality, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added quality element: ' .. element)
    end
    
    if prefs.includeRating and rating > 0 then
      local element = 'Ra:' .. tostring(rating)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added rating element: ' .. element)
    end
    
    if prefs.includeSpeciesConfidence and speciesConf >= 0 then
      local element = 'Co:' .. formatPrecision(speciesConf, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added species confidence element: ' .. element)
    end
    
    if prefs.includeDetectedSpecies and species and species ~= 'Unknown' and species ~= '' then
      -- Don't truncate species names - use full name for IPTC
      local element = 'Sp:' .. species
      table.insert(elements, element)
      Log.info('IPTC Debug - Added species element: ' .. element)
    end
    
    if prefs.includeSceneCount and sceneCount > 0 then
      local element = 'Sc:' .. tostring(sceneCount)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added scene count element: ' .. element)
    end
    
    if prefs.includeFeatureSimilarity and d.feature_similarity and d.feature_similarity >= 0 then
      local element = 'Fs:' .. formatPrecision(d.feature_similarity, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added feature similarity element: ' .. element)
    end
    
    if prefs.includeFeatureConfidence and d.feature_confidence and d.feature_confidence >= 0 then
      local element = 'Fc:' .. formatPrecision(d.feature_confidence, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added feature confidence element: ' .. element)
    end
    
    if prefs.includeColorSimilarity and d.color_similarity and d.color_similarity >= 0 then
      local element = 'Cs:' .. formatPrecision(d.color_similarity, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added color similarity element: ' .. element)
    end
    
    if prefs.includeColorConfidence and d.color_confidence and d.color_confidence >= 0 then
      local element = 'Cc:' .. formatPrecision(d.color_confidence, true)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added color confidence element: ' .. element)
    end
    
    if prefs.includeProcessingTime and d.processing_time and d.processing_time > 0 then
      local element = 'Pt:' .. string.format('%.2f', d.processing_time)
      table.insert(elements, element)
      Log.info('IPTC Debug - Added processing time element: ' .. element)
    end
    
    Log.info('IPTC Debug - Total elements to include: ' .. #elements)
    if #elements > 0 then
      local iptcValue = 'WAI ' .. table.concat(elements, ' ')
      Log.info('IPTC Debug - Final IPTC value: ' .. iptcValue)
      local success, err = pcall(function()
        photo:setRawMetadata(prefs.iptcField, iptcValue)
      end)
      if not success then
        Log.error('Failed to set IPTC field ' .. prefs.iptcField .. ': ' .. tostring(err))
      else
        Log.info('Set IPTC ' .. prefs.iptcField .. ': ' .. iptcValue .. ' for ' .. LrPathUtils.leafName(photoPath))
      end
    else
      Log.warning('IPTC Debug - No elements to include in IPTC metadata')
    end
  else
    Log.info('IPTC Debug - IPTC mirroring not enabled or missing requirements')
  end
  
  -- Legacy job identifier support (for backward compatibility) - only if IPTC is not using jobIdentifier
  if prefs.mirrorJobId and photo.setRawMetadata and (not prefs.enableIptcMirror or prefs.iptcField ~= 'jobIdentifier') then
    local jid = string.format('Q:%s R:%s C:%s', formatPrecision(quality, true), rating, sceneCount)
    local success, err = pcall(function()
      photo:setRawMetadata('jobIdentifier', jid)
    end)
    if not success then
      Log.error('Failed to set job identifier: ' .. tostring(err))
    else
      Log.info('Set job identifier: ' .. jid .. ' for ' .. LrPathUtils.leafName(photoPath))
    end
  end
  
  -- Apply keywords based on preferences (done within catalog write access, no yielding)
  if prefs.enableKeywording then
    local keywordSuccess = KeywordHelper.applyKeywords(photo, d, prefs, catalog)
    if keywordSuccess then
      Log.info('Applied keywords for: ' .. LrPathUtils.leafName(photoPath))
    else
      Log.warning('Failed to apply keywords for: ' .. LrPathUtils.leafName(photoPath))
    end
  end
  
  -- Enhanced XMP writing with proper error handling and retry logic
  if prefs.writeXMP then
    local success, err = pcall(function()
      -- Force metadata to be written to XMP sidecar files
      if photo.saveMetadata then
        photo:saveMetadata()
        Log.info('Saved XMP metadata for: ' .. LrPathUtils.leafName(photoPath))
      else
        Log.warning('saveMetadata not available for photo: ' .. LrPathUtils.leafName(photoPath))
      end
    end)
    if not success then
      Log.error('Failed to save XMP metadata: ' .. tostring(err))
      
      -- Retry with alternative approach
      local retrySuccess, retryErr = pcall(function()
        -- Alternative: use catalog's saveMetadata if available
        if catalog and catalog.saveMetadata then
          catalog:saveMetadata(photo)
          Log.info('Saved XMP metadata via catalog for: ' .. LrPathUtils.leafName(photoPath))
        end
      end)
      if not retrySuccess then
        Log.error('XMP retry also failed: ' .. tostring(retryErr))
      end
    end
  end
end

function M.run(photos, progressCallback, forceReprocess, metadataCallback)
  local clk = Log.enter('SmartBridge.run')
  
  -- Filter photos based on processing state
  local photosToProcess = {}
  local results = {}
  local photosMap = {} -- Map photo paths to photo objects for metadata updates
  
  for _, photo in ipairs(photos) do
    local photoPath = photo:getRawMetadata('path')
    photosMap[photoPath] = photo
    
    -- Use Lightroom metadata as source of truth - if wai_processed is not 'true', we need to process
    local processed = photo:getPropertyForPlugin(_PLUGIN, 'wai_processed')
    if forceReprocess or processed ~= 'true' then
      -- Force processing - ignore existing result files if Lightroom says not processed
      if processed ~= 'true' then
        Log.info('Lightroom metadata indicates not processed, forcing fresh analysis for: ' .. LrPathUtils.leafName(photoPath))
      end
      table.insert(photosToProcess, photo)
    else
      -- Photo is marked as processed in Lightroom, try to load existing results
      local existingResults = getExistingResults(photoPath)
      if existingResults then
        Log.info('Photo already processed, using cached results: ' .. LrPathUtils.leafName(photoPath))
        results[photoPath] = existingResults
      else
        -- Photo marked as processed but no results file - reprocess
        Log.warning('Photo marked processed but no results found, reprocessing: ' .. LrPathUtils.leafName(photoPath))
        table.insert(photosToProcess, photo)
      end
    end
  end
  
  if #photosToProcess == 0 then
    Log.info('All photos already processed, no runner execution needed')
    Log.leave(clk, 'SmartBridge.run')
    return results
  end
  
  Log.info('Processing ' .. #photosToProcess .. ' photos (of ' .. #photos .. ' selected)')
  
  -- Create photo paths list for processing
  local photoList = {}
  for _, photo in ipairs(photosToProcess) do
    table.insert(photoList, photo:getRawMetadata('path'))
  end
  
  Log.info('Photo paths to process:')
  for i, path in ipairs(photoList) do
    Log.info('  ' .. i .. ': ' .. path)
  end
  
  -- Try alternative approach: save photos as direct arguments (for small sets)
  -- or temp file for larger sets to avoid command line length limits
  local tmp = nil
  local useDirectArgs = #photoList <= 3  -- Use direct args for fewer photos to avoid command line parsing issues
  
  if useDirectArgs then
    Log.info('Using direct command line arguments for ' .. #photoList .. ' photos')
  else
    Log.info('Using temp file for ' .. #photoList .. ' photos (too many for direct args)')
    local tempContent = table.concat(photoList, '\n') .. '\n'
    Log.info('Temp file content length: ' .. #tempContent .. ' chars')
    tmp = safeCreateTempFile(tempContent, 'wai_paths')
    Log.info('Temp file created: ' .. tmp)
    
    -- Verify temp file was written correctly
    if LrFileUtils.exists(tmp) then
      local verifyContent = LrFileUtils.readFile(tmp)
      if verifyContent then
        Log.info('Temp file verification: ' .. #verifyContent .. ' chars read back')
        local lines = {}
        for line in verifyContent:gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end
        Log.info('Temp file contains ' .. #lines .. ' lines')
        for i, line in ipairs(lines) do
          Log.info('  Line ' .. i .. ': "' .. line .. '"')
        end
      else
        Log.error('Failed to read back temp file content')
      end
    else
      Log.error('Temp file does not exist after creation')
    end
  end
  
  -- Group photos by directory for output management
  local dirGroups = {}
  for _, photo in ipairs(photosToProcess) do
    local photoPath = photo:getRawMetadata('path')
    local photoDir = LrPathUtils.parent(photoPath)
    if not dirGroups[photoDir] then
      dirGroups[photoDir] = {}
    end
    table.insert(dirGroups[photoDir], photo)
  end
  
  local dirCount = 0
  for _ in pairs(dirGroups) do
    dirCount = dirCount + 1
  end
  Log.info('Photos span ' .. dirCount .. ' directories')
  
  -- Create a consolidated output directory for runner
  local tempOutputDir = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_output_' .. os.time())
  LrFileUtils.createAllDirectories(tempOutputDir)
  
  -- Find the best available runner
  local runner = findBestRunner()
  local pythonBinary, scriptPath = nil, nil
  
  if not runner then
    pythonBinary, scriptPath = M.findSystemPythonRunner()
    if not pythonBinary or not scriptPath then
      Log.error('No runner available')
      LrDialogs.message('WildlifeAI', 
        'No runner found. Please reinstall the plugin or configure Python in settings.', 'error')
      Log.leave(clk, 'SmartBridge.run')
      return results
    end
  end
  
  -- Build command
  local prefs = LrPrefs.prefsForPlugin()
  local cmd
  
  if runner then
    -- Bundled executable (WildlifeAI runner)
    if useDirectArgs then
      -- Direct arguments approach
      cmd = string.format('%s --output-dir %s --max-workers %d',
        quote(runner), quote(tempOutputDir), prefs.maxWorkers or 4)
      for _, path in ipairs(photoList) do
        cmd = cmd .. ' ' .. quote(path)
      end
    else
      -- Temp file approach  
      cmd = string.format('%s --photo-list %s --output-dir %s --max-workers %d',
        quote(runner), quote(tmp), quote(tempOutputDir), prefs.maxWorkers or 4)
    end
  else
    -- Python script (WildlifeAI runner)
    if useDirectArgs then
      -- Direct arguments approach
      cmd = string.format('%s %s --output-dir %s --max-workers %d',
        quote(pythonBinary), quote(scriptPath), quote(tempOutputDir), prefs.maxWorkers or 4)
      for _, path in ipairs(photoList) do
        cmd = cmd .. ' ' .. quote(path)
      end
    else
      -- Temp file approach
      cmd = string.format('%s %s --photo-list %s --output-dir %s --max-workers %d',
        quote(pythonBinary), quote(scriptPath), quote(tmp), quote(tempOutputDir), 
        prefs.maxWorkers or 4)
    end
  end
  
  -- Add flags for enhanced runner
  if prefs.useGPU then cmd = cmd .. ' --gpu' end
  if prefs.generateCrops ~= false then cmd = cmd .. ' --generate-crops' end
  if prefs.enableLogging or prefs.verboseRunner or prefs.debugMode then cmd = cmd .. ' --verbose' end
  
  -- Temporarily disable async mode to test if that's causing exit code 1
  -- cmd = cmd .. ' --async-mode'
  
  Log.info('Executing: ' .. cmd)
  
  -- Use Lightroom command line fix from Adobe forums
  -- Wrap entire command in double quotes to fix LrTasks.execute() issues
  local wrappedCmd = '"' .. cmd .. '"'
  Log.info('Wrapped command: ' .. wrappedCmd)
  
  -- Execute with proper error handling
  Log.info('Using wrapped execution to work around LrTasks.execute() command line issues')
  
  -- Start the command and monitor progress
  local success, errorMsg = LrTasks.pcall(function()
    -- Monitor progress while processing
    local resultsJsonPath = LrPathUtils.child(tempOutputDir, 'results.json')
    local statusJsonPath = LrPathUtils.child(tempOutputDir, 'status.json')
    local startTime = os.time()
    local maxWaitTime = 300 -- 5 minutes max
    
    -- Start the command in background using async task
    local commandComplete = false
    local commandResult = nil
    
    LrTasks.startAsyncTask(function()
      Log.info('Starting background command execution...')
      commandResult = LrTasks.execute(wrappedCmd)
      commandComplete = true
      Log.info('Background command completed with result: ' .. tostring(commandResult))
    end)
    
    -- Start monitoring immediately while command runs
    Log.info('Starting immediate progress monitoring...')
    
    -- Enhanced monitoring with direct non-yielding metadata application
    local isComplete = false
    local lastProcessedCount = 0
    local loopCount = 0
    local processedPhotos = {} -- Track which photos have been updated with metadata
    local keywordResults = {} -- Store results for batch keyword application later
    
    Log.info('Starting progress monitoring loop')
    Log.info('Monitoring status file: ' .. statusJsonPath)
    Log.info('Monitoring results file: ' .. resultsJsonPath)
    Log.info('Expected photos to process: ' .. #photosToProcess)
    
    while not isComplete and (os.time() - startTime) < maxWaitTime do
      loopCount = loopCount + 1
      local currentTime = os.time() - startTime
      
      -- Check for new individual results and apply metadata immediately
      if LrFileUtils.exists(resultsJsonPath) then
        local txt = LrFileUtils.readFile(resultsJsonPath)
        if txt then
          local ok, data = pcall(json.decode, txt)
          if ok and type(data) == 'table' then
            -- Process any new results that have appeared
            for _, result in ipairs(data) do
              local filename = result.filename
              if filename and not processedPhotos[filename] then
                -- Find the photo object for this result
                for _, photo in ipairs(photosToProcess) do
                  local photoPath = photo:getRawMetadata('path')
                  local photoFilename = LrPathUtils.leafName(photoPath)
                  if result.filename == photoFilename then
                    -- Map enhanced runner fields to expected field names with proper numeric precision
                    local function parseNumeric(value)
                      if type(value) == 'number' then
                        return value
                      elseif type(value) == 'string' then
                        local num = tonumber(value)
                        return num or 0
                      else
                        return 0
                      end
                    end
                    
                    local mappedResult = {
                      detected_species = result.species,
                      species_confidence = parseNumeric(result.species_confidence),
                      quality = parseNumeric(result.quality),
                      rating = parseNumeric(result.rating),
                      scene_count = parseNumeric(result.scene_count),
                      feature_similarity = parseNumeric(result.feature_similarity),
                      feature_confidence = parseNumeric(result.feature_confidence),
                      color_similarity = parseNumeric(result.color_similarity),
                      color_confidence = parseNumeric(result.color_confidence),
                      processing_time = parseNumeric(result.processing_time),
                      json_path = '', -- Will be set when saved
                      photo_path = photoPath,
                      export_path = result.export_path or '',
                      crop_path = result.crop_path or ''
                    }
                    
                    results[photoPath] = mappedResult
                    
                    -- Save results to photo directory
                    savePhotoResults(photoPath, mappedResult)
                    
                    -- Store result for batch keyword processing later
                    keywordResults[photoPath] = mappedResult
                    
                    -- Apply non-yielding metadata directly (synchronously in monitoring loop)
                    local success, err = pcall(function()
                      -- Apply ONLY safe, non-yielding metadata operations
                      applySimpleNonYieldingMetadata(photo, mappedResult, prefs)
                    end)
                    
                    if success then
                      Log.info('Real-time metadata applied for: ' .. filename)
                    else
                      Log.error('Real-time metadata application failed for ' .. filename .. ': ' .. tostring(err))
                    end
                    
                    processedPhotos[filename] = true
                    Log.info('Real-time processing completed for: ' .. filename)
                    break
                  end
                end
              end
            end
          end
        end
      end
      
      -- Check for status updates
      if LrFileUtils.exists(statusJsonPath) then
        Log.info('Status file exists, reading contents... (loop ' .. loopCount .. ')')
        local statusContent = LrFileUtils.readFile(statusJsonPath)
        if statusContent and statusContent ~= '' then
          Log.info('Status file content length: ' .. #statusContent .. ' chars')
          local ok, statusData = pcall(json.decode, statusContent)
          if ok and statusData then
            local processed = statusData.processed or 0
            local total = statusData.total_photos or #photosToProcess
            local currentPhoto = statusData.current_photo or ''
            local status = statusData.status or 'processing'
            local progressPercent = statusData.progress_percent or 0
            
            Log.info('Status JSON parsed - Status: ' .. status .. ', Processed: ' .. processed .. '/' .. total .. ', Progress: ' .. progressPercent .. '%')
            
            -- Check if processing is complete
            if status == 'completed' or status == 'error' then
              isComplete = true
              Log.info('Processing completed with status: ' .. status)
            end
            
            -- Update progress even if count hasn't changed (for better responsiveness)
            if processed >= lastProcessedCount then
              if progressCallback then
                Log.info('Calling progress callback with: ' .. processed .. '/' .. total .. ' - "' .. currentPhoto .. '"')
                progressCallback(processed, total, currentPhoto)
              else
                Log.warning('Progress callback is nil!')
              end
              
              if processed > lastProcessedCount then
                lastProcessedCount = processed
                Log.info('Progress updated: ' .. processed .. '/' .. total .. ' - ' .. currentPhoto)
              end
            end
          else
            Log.error('Failed to parse status JSON: ' .. tostring(statusData))
          end
        else
          Log.warning('Status file exists but is empty or unreadable')
        end
      else
        Log.info('Status file does not exist yet (loop ' .. loopCount .. '), checking results.json...')
        
        -- If no status file exists yet, check if results.json exists (for non-status runners)
        if LrFileUtils.exists(resultsJsonPath) then
          Log.info('Results file exists, checking content...')
          local txt = LrFileUtils.readFile(resultsJsonPath)
          if txt then
            local ok, data = pcall(json.decode, txt)
            if ok and type(data) == 'table' then
              Log.info('Results file has ' .. #data .. ' results (expecting ' .. #photosToProcess .. ')')
              if #data >= #photosToProcess then
                isComplete = true
                Log.info('Processing completed - results file has all expected results')
              else
                -- Provide fallback progress updates based on results count
                if progressCallback then
                  progressCallback(#data, #photosToProcess, 'Processing...')
                end
              end
            end
          end
        else
          Log.info('Results file also does not exist yet')
        end
      end
      
      if not isComplete then
        Log.info('Continuing monitoring loop (elapsed: ' .. currentTime .. 's)...')
        -- Use LrTasks.sleep instead of busy waiting
        LrTasks.sleep(1.0)
      end
    end
    
    Log.info('Progress monitoring loop completed after ' .. loopCount .. ' iterations')
    
    -- Verify completion
    if isComplete then
      Log.info('Processing completed successfully')
      return true
    elseif (os.time() - startTime) >= maxWaitTime then
      Log.error('Processing timed out after ' .. maxWaitTime .. ' seconds')
      return false
    else
      Log.error('Processing failed for unknown reason')
      return false
    end
  end)
  
  if not success then
    local errorMsg = 'Runner failed: ' .. tostring(errorMsg or 'Unknown error')
    Log.error(errorMsg)
    
    -- Enhanced error reporting - check if temp file still exists
    if tmp and not LrFileUtils.exists(tmp) then
      Log.error('CRITICAL: Temp file was deleted before executable could read it: ' .. tmp)
      errorMsg = errorMsg .. '\n\nCause: Temp file cleanup timing issue. The photo list file was deleted before the executable could read it.'
    elseif tmp then
      Log.info('Temp file still exists, issue is elsewhere: ' .. tmp)
    end
    
    LrDialogs.message('WildlifeAI', errorMsg, 'error')
    -- Cleanup temp files ONLY after reporting the error
    if tmp then
      LrFileUtils.delete(tmp)
    end
    if LrFileUtils.exists(tempOutputDir) then
      pcall(function()
        local files = LrFileUtils.recursiveDirectoryEntries(tempOutputDir)
        for _, file in ipairs(files or {}) do
          pcall(LrFileUtils.delete, file)
        end
        pcall(LrFileUtils.delete, tempOutputDir)
      end)
    end
    Log.leave(clk, 'SmartBridge.run')
    return results
  end
  
  Log.info('Synchronous execution completed successfully')
  
  -- Collect results from enhanced runner's results.json
  local resultsJsonPath = LrPathUtils.child(tempOutputDir, 'results.json')
  
  if LrFileUtils.exists(resultsJsonPath) then
    local txt = LrFileUtils.readFile(resultsJsonPath)
    local ok, data = pcall(json.decode, txt)
    if ok and type(data) == 'table' then
      -- Enhanced runner returns array of results, process each one
      for _, result in ipairs(data) do
        -- Find the photo with matching filename
        for _, photo in ipairs(photosToProcess) do
          local photoPath = photo:getRawMetadata('path')
          local filename = LrPathUtils.leafName(photoPath)
          if result.filename == filename then
            -- Save results to photo directory first to get proper json_path
            local photoDir = LrPathUtils.parent(photoPath)
            local outputDir = LrPathUtils.child(photoDir, '.wildlifeai')
            local filename = LrPathUtils.leafName(photoPath)
            local localJsonPath = LrPathUtils.child(outputDir, filename .. '.json')
            
            -- Map enhanced runner fields to expected field names with proper numeric precision
            local function parseNumeric(value)
              if type(value) == 'number' then
                return value
              elseif type(value) == 'string' then
                local num = tonumber(value)
                return num or 0
              else
                return 0
              end
            end
            
            local mappedResult = {
              detected_species = result.species,
              species_confidence = parseNumeric(result.species_confidence),
              quality = parseNumeric(result.quality),
              rating = parseNumeric(result.rating),
              scene_count = parseNumeric(result.scene_count),
              feature_similarity = parseNumeric(result.feature_similarity),
              feature_confidence = parseNumeric(result.feature_confidence),
              color_similarity = parseNumeric(result.color_similarity),
              color_confidence = parseNumeric(result.color_confidence),
              processing_time = parseNumeric(result.processing_time),
              json_path = localJsonPath, -- Point to local .wildlifeai directory
              photo_path = photoPath, -- Full path for future lookups
              export_path = result.export_path or '',
              crop_path = result.crop_path or ''
            }
            
            results[photoPath] = mappedResult
            
            -- Save results to photo directory
            savePhotoResults(photoPath, mappedResult)
            
            Log.info('Processed and saved results for: ' .. filename)
            break
          end
        end
      end
      Log.info('Processed ' .. #data .. ' results from enhanced runner')
    else
      Log.error('Failed to parse results.json or invalid format')
    end
  else
    Log.warning('Enhanced runner results.json not found: ' .. resultsJsonPath)
  end
  
  -- Copy any generated crop and export files to photo directories
  if prefs.generateCrops then
    for _, photo in ipairs(photosToProcess) do
      local photoPath = photo:getRawMetadata('path')
      local filename = LrPathUtils.leafName(photoPath)
      local filenameNoExt = LrPathUtils.removeExtension(filename)
      local outputDir = getPhotoOutputDir(photoPath)
      
      -- Look for crop files in temp output crop directory
      local cropDir = LrPathUtils.child(tempOutputDir, 'crop')
      local cropFile = LrPathUtils.child(cropDir, filenameNoExt .. '_crop.jpg')
      if LrFileUtils.exists(cropFile) then
        LrFileUtils.createAllDirectories(outputDir)
        local destCropFile = LrPathUtils.child(outputDir, filenameNoExt .. '_crop.jpg')
        
        local ok = pcall(LrFileUtils.copy, cropFile, destCropFile)
        if ok then
          Log.info('Copied crop file for: ' .. filename)
          
          -- Update the result with the local crop path
          if results[photoPath] then
            results[photoPath].crop_path = destCropFile
          end
        else
          Log.warning('Failed to copy crop file for: ' .. filename)
        end
      else
        Log.warning('No crop file found for: ' .. filename .. ' at ' .. cropFile)
      end
      
      -- Look for export files in temp output export directory  
      local exportDir = LrPathUtils.child(tempOutputDir, 'export')
      local exportFile = LrPathUtils.child(exportDir, filenameNoExt .. '_export.jpg')
      if LrFileUtils.exists(exportFile) then
        LrFileUtils.createAllDirectories(outputDir)
        local destExportFile = LrPathUtils.child(outputDir, filenameNoExt .. '_export.jpg')
        
        local ok = pcall(LrFileUtils.copy, exportFile, destExportFile)
        if ok then
          Log.info('Copied export file for: ' .. filename)
          
          -- Update the result with the local export path
          if results[photoPath] then
            results[photoPath].export_path = destExportFile
          end
        else
          Log.warning('Failed to copy export file for: ' .. filename)
        end
      else
        Log.warning('No export file found for: ' .. filename .. ' at ' .. exportFile)
      end
    end
  end
  
  -- Apply keywords in batch after all photos are processed (if enabled)
  if prefs.enableKeywording and next(keywordResults) then
    Log.info('Starting batch keyword application for ' .. #keywordResults .. ' photos')
    
    -- Count actual keyword results
    local keywordCount = 0
    for _ in pairs(keywordResults) do
      keywordCount = keywordCount + 1
    end
    
    Log.info('Applying keywords to ' .. keywordCount .. ' processed photos')
    
    local keywordProgress = LrProgressScope {
      title = 'Applying keywords...',
      functionContext = nil
    }
    
    local processedCount = 0
    for photoPath, result in pairs(keywordResults) do
      local photo = photosMap[photoPath]
      if photo then
        keywordProgress:setPortionComplete(processedCount, keywordCount)
        keywordProgress:setCaption('Applying keywords to ' .. LrPathUtils.leafName(photoPath))
        
        -- Apply keywords in proper catalog write context
        local catalog = photo.catalog
        local success, err = pcall(function()
          catalog:withWriteAccessDo('WAI batch keyword application', function()
            local keywordSuccess = KeywordHelper.applyKeywords(photo, result, prefs, catalog)
            if keywordSuccess then
              Log.info('Batch keywords applied for: ' .. LrPathUtils.leafName(photoPath))
            else
              Log.warning('Batch keywords failed for: ' .. LrPathUtils.leafName(photoPath))
            end
          end, {timeout=60})
        end)
        
        if not success then
          Log.error('Batch keyword application failed for ' .. LrPathUtils.leafName(photoPath) .. ': ' .. tostring(err))
        end
        
        processedCount = processedCount + 1
        
        -- Check for user cancellation
        if keywordProgress:isCanceled() then
          Log.info('User cancelled keyword application')
          break
        end
      end
    end
    
    keywordProgress:done()
    Log.info('Batch keyword application completed for ' .. processedCount .. '/' .. keywordCount .. ' photos')
  else
    Log.info('Keyword application disabled or no results to process')
  end
  
  -- Cleanup temp files AFTER ensuring execution is complete
  if tmp then
    -- Add a small delay to ensure the child process has started and read the file
    LrTasks.sleep(0.5)
    if LrFileUtils.exists(tmp) then
      LrFileUtils.delete(tmp)
      Log.info('Cleaned up temp file: ' .. tmp)
    end
  end
  if LrFileUtils.exists(tempOutputDir) then
    pcall(function()
      local files = LrFileUtils.recursiveDirectoryEntries(tempOutputDir)
      for _, file in ipairs(files or {}) do
        pcall(LrFileUtils.delete, file)
      end
      pcall(LrFileUtils.delete, tempOutputDir)
    end)
  end
  
  Log.leave(clk, 'SmartBridge.run')
  return results
end

return M
