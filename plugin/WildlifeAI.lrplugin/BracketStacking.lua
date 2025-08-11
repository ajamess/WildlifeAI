-- WildlifeAI Bracket Stacking Engine
-- Intelligent detection and stacking of bracketed image sequences
-- Supports both individual HDR brackets and bracketed panoramas

local LrApplication = import 'LrApplication'
local LrPrefs = import 'LrPrefs'
local LrPathUtils = import 'LrPathUtils'
local LrProgressScope = import 'LrProgressScope'
local LrTasks = import 'LrTasks'

local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )

local BracketStacking = {}

-- Constants
local EPSILON = 0.001 -- For floating point comparisons

-- Safely retrieve metadata with error handling
local function safeGetRawMetadata(photo, key)
  local ok, result = LrTasks.pcall(function()
    return photo:getRawMetadata(key)
  end)
  if ok then
    Log.debug(string.format("safeGetRawMetadata('%s') success", key))
    return result
  else
    Log.warning(string.format("safeGetRawMetadata('%s') failed: %s", key, tostring(result)))
    return nil
  end
end

-- Helper function to get photo timestamp
local function getPhotoTimestamp(meta)
  local dateTime = meta.dateTime
  if type(dateTime) == "table" and dateTime.timeInSeconds then
    return dateTime:timeInSeconds()
  elseif type(dateTime) == "number" then
    return dateTime
  end
  return 0
end

-- Helper function to get exposure value from EXIF
local function parseExposureValue(value)
  if type(value) == 'number' then
    return value
  elseif type(value) == 'string' then
    -- Handle fractional strings like "1/250"
    local num, den = value:match('^%s*([%-]?%d+)%s*/%s*([%-]?%d+)%s*$')
    if num and den then
      local n = tonumber(num)
      local d = tonumber(den)
      if n and d and d ~= 0 then
        return n / d
      end
    end
    -- Remove common prefixes like 'f/' for aperture values
    local cleaned = value:gsub('^%s*f/?', '')
    local n = tonumber(cleaned)
    if n then
      return n
    end
  end
  return nil
end

local function getExposureValue(meta)
  -- Try multiple EXIF field names for different camera formats
  local aperture = parseExposureValue(meta.aperture)
  local shutterSpeed = parseExposureValue(meta.shutterSpeed)
  local iso = parseExposureValue(meta.isoSpeedRating)

  -- Try alternative field names if primary ones fail
  if not aperture then
    aperture = parseExposureValue(meta.fNumber)
  end

  if not shutterSpeed then
    shutterSpeed = parseExposureValue(meta.exposureTime)
  end

  if not iso then
    iso = parseExposureValue(meta.iso)
      or parseExposureValue(meta.isoSpeedRatings)
      or parseExposureValue(meta.photographicSensitivity)
  end

  -- Debug logging for EXIF data extraction
  Log.debug(string.format("EXIF data - aperture: %s, shutterSpeed: %s, iso: %s",
    tostring(aperture), tostring(shutterSpeed), tostring(iso)))

  if aperture and shutterSpeed and iso and aperture > 0 and shutterSpeed > 0 and iso > 0 then
    -- Calculate EV using standard formula: EV = log2(aperture²/shutterSpeed) + log2(iso/100)
    local ev = math.log(aperture * aperture / shutterSpeed, 2) + math.log(iso / 100, 2)
    Log.debug(string.format("Calculated EV: %.2f (f/%.1f, 1/%.0fs, ISO%d)",
      ev, aperture, 1/shutterSpeed, iso))
    return ev
  else
    Log.debug("Insufficient EXIF data for EV calculation")
    return nil
  end
end

-- Helper function to get orientation
local function getOrientation(meta)
  local orientation = meta.orientation
  if orientation and (orientation == 'AB' or orientation == 'CD') then
    return 'vertical'
  end
  return 'horizontal'
end

-- NEW: Individual metadata extraction using proven working pattern from Analytics.lua
function BracketStacking.extractPhotoMetadataSafe(photos)
  Log.info("=== INDIVIDUAL METADATA EXTRACTION (PROVEN PATTERN) ===")
  Log.info(string.format("Input: %d photos to process", #photos))
  Log.info("Context: Async task - using individual photo:getRawMetadata() calls")
  Log.info("Pattern: Same as Analytics.lua and SmartBridge.lua (proven working)")
  
  local photoData = {}
  
  if #photos == 0 then
    Log.warning("No photos provided to extractPhotoMetadataSafe")
    return photoData, true -- Return success even if no photos
  end

  -- Process each photo individually using the proven working pattern
  Log.info("=== STARTING INDIVIDUAL METADATA EXTRACTION ===")
  Log.info("Using individual photo:getRawMetadata() calls (no yielding issues)")
  
  for i, photo in ipairs(photos) do
    Log.debug(string.format("Extracting metadata for photo %d/%d...", i, #photos))
    
    -- Extract metadata using individual calls (proven working pattern)
    local photoPath = safeGetRawMetadata(photo, 'path') or ''
    local uuid = safeGetRawMetadata(photo, 'uuid') or string.format("photo_%d_%d", i, os.time())
    local dateTime = safeGetRawMetadata(photo, 'dateTime')

    -- Aperture may be stored under different keys
    local aperture = safeGetRawMetadata(photo, 'aperture')
    local fNumber = safeGetRawMetadata(photo, 'fNumber')
    if not aperture then
      aperture = fNumber
    end
    if not aperture then
      aperture = safeGetRawMetadata(photo, 'apertureValue')
    end
    if not aperture then
      Log.warning(string.format("Photo %s: missing aperture metadata (aperture, fNumber, apertureValue)", photoPath))
    end

    local shutterSpeed = safeGetRawMetadata(photo, 'shutterSpeed')
    local isoSpeedRating = safeGetRawMetadata(photo, 'isoSpeedRating')
    local exposureTime = safeGetRawMetadata(photo, 'exposureTime')
    local orientation = safeGetRawMetadata(photo, 'orientation')
    local iso = safeGetRawMetadata(photo, 'iso')
    local isoSpeedRatings = safeGetRawMetadata(photo, 'isoSpeedRatings')
    local photographicSensitivity = safeGetRawMetadata(photo, 'photographicSensitivity')
    
    -- Build metadata object
    local meta = {
      uuid = uuid,
      dateTime = dateTime,
      aperture = aperture,
      shutterSpeed = shutterSpeed,
      isoSpeedRating = isoSpeedRating,
      fNumber = fNumber,
      exposureTime = exposureTime,
      orientation = orientation,
      iso = iso,
      isoSpeedRatings = isoSpeedRatings,
      photographicSensitivity = photographicSensitivity
    }
    
    -- Log metadata availability for first few photos
    if i <= 3 then
      local metaFields = {}
      for field, value in pairs(meta) do
        if value then
          table.insert(metaFields, string.format("%s=%s", field, tostring(value)))
        end
      end
      Log.debug(string.format("Photo %d metadata fields: [%s]", i, table.concat(metaFields, ', ')))
    end
    
    -- Extract and validate timestamp
    local timestamp = getPhotoTimestamp(meta)
    if not timestamp or timestamp == 0 then
      Log.warning(string.format("Photo %d: Missing or invalid timestamp, using current time", i))
      timestamp = os.time()
    end
    
    -- Extract exposure value with detailed logging
    local exposureValue = getExposureValue(meta)
    if exposureValue then
      Log.debug(string.format("Photo %d: Extracted EV = %.2f", i, exposureValue))
    else
      Log.debug(string.format("Photo %d: No exposure value available", i))
    end
    
    -- Create metadata record
    local data = {
      uuid = uuid,
      timestamp = timestamp,
      exposureValue = exposureValue,
      orientation = getOrientation(meta),
      photoIndex = i,  -- Add original index for debugging
      photoPath = photoPath  -- Store path for reference
    }
    
    table.insert(photoData, data)
    
    Log.debug(string.format("Photo %d processed: UUID=%s, timestamp=%s, EV=%s, orientation=%s",
      i, data.uuid, os.date("%H:%M:%S", data.timestamp), 
      tostring(data.exposureValue), data.orientation))
  end
  
  Log.info(string.format("✓ All %d metadata records processed successfully", #photoData))
  
  -- Sort by timestamp with logging
  Log.info("=== SORTING PHOTOS BY TIMESTAMP ===")
  table.sort(photoData, function(a, b)
    return a.timestamp < b.timestamp
  end)
  
  if #photoData > 0 then
    Log.info(string.format("✓ Photos sorted by time: %s to %s", 
      os.date("%H:%M:%S", photoData[1].timestamp),
      os.date("%H:%M:%S", photoData[#photoData].timestamp)))
      
    -- Log time gaps for first few photos
    for i = 2, math.min(4, #photoData) do
      local gap = photoData[i].timestamp - photoData[i-1].timestamp
      Log.debug(string.format("Time gap %d->%d: %.1f seconds", i-1, i, gap))
    end
  end
  
  Log.info("=== INDIVIDUAL METADATA EXTRACTION COMPLETED SUCCESSFULLY ===")
  Log.info(string.format("✓ Total records extracted: %d", #photoData))
  Log.info(string.format("✓ Success rate: 100%% (%d/%d photos)", #photoData, #photos))
  
  return photoData, true
end

-- Legacy metadata extraction function (kept for compatibility)
function BracketStacking.extractPhotoMetadata(photos)
  Log.info("=== LEGACY METADATA EXTRACTION (DEPRECATED) ===")
  Log.warning("Using deprecated extractPhotoMetadata - consider using extractPhotoMetadataSafe")
  
  local photoData, success = BracketStacking.extractPhotoMetadataSafe(photos)
  return photoData
end

-- Sort photos by timestamp (legacy function for compatibility)
local function sortPhotosByTime(photos)
  return BracketStacking.extractPhotoMetadata(photos)
end

-- Analyze exposure patterns in a group
local function analyzeExposurePattern(group, prefs)
  if not prefs.useExposureValuesForDetection then
    return { valid = false, reason = 'Exposure analysis disabled' }
  end
  
  local exposures = {}
  for _, data in ipairs(group) do
    if data.exposureValue then
      table.insert(exposures, data.exposureValue)
    end
  end
  
  if #exposures < 2 then
    return { valid = false, reason = 'Insufficient exposure data' }
  end
  
  -- Sort exposures to analyze pattern
  table.sort(exposures)
  
  local steps = {}
  for i = 2, #exposures do
    local step = math.abs(exposures[i] - exposures[i-1])
    table.insert(steps, step)
  end
  
  -- Check if steps are consistent and within acceptable range
  local minStep = tonumber(prefs.minExposureStep) or 0.5
  local maxStep = tonumber(prefs.maxExposureStep) or 3.0
  
  local validSteps = 0
  for _, step in ipairs(steps) do
    if step >= minStep and step <= maxStep then
      validSteps = validSteps + 1
    end
  end
  
  local stepConsistency = validSteps / #steps
  local exposureRange = exposures[#exposures] - exposures[1]
  
  return {
    valid = stepConsistency >= 0.6, -- At least 60% of steps should be valid
    stepConsistency = stepConsistency,
    exposureRange = exposureRange,
    stepCount = #steps,
    reason = stepConsistency < 0.6 and 'Inconsistent exposure steps' or 'Valid exposure pattern'
  }
end

-- Detect bracket patterns in time-grouped photos
local function detectBracketPatterns(photoData, prefs)
  Log.info("=== DETECTING BRACKET PATTERNS ===")
  if #photoData == 0 then 
    Log.warning("No photo data provided for bracket detection")
    return {} 
  end
  
  local brackets = {}
  local i = 1
  
  while i <= #photoData do
    local bracketGroup = { photoData[i] }
    local j = i + 1
    
    Log.debug(string.format("Starting new bracket group at photo %d (timestamp: %s)", 
      i, os.date("%H:%M:%S", photoData[i].timestamp)))
    
    -- Look for consecutive photos within bracket interval
    while j <= #photoData do
      local timeDiff = photoData[j].timestamp - photoData[j-1].timestamp
      local withinBracketInterval = tonumber(prefs.withinBracketInterval) or 3.0
      
      Log.debug(string.format("  Checking photo %d: time diff = %.2fs (limit: %.2fs)", 
        j, timeDiff, withinBracketInterval))
      
      if timeDiff <= withinBracketInterval then
        table.insert(bracketGroup, photoData[j])
        Log.debug(string.format("  Added photo %d to bracket group (group size now: %d)", 
          j, #bracketGroup))
        j = j + 1
      else
        Log.debug(string.format("  Photo %d exceeds time limit - ending bracket group", j))
        break
      end
    end
    
    -- Analyze this potential bracket group
    -- Convert bracket size preferences to numbers
    local minSize = tonumber(prefs.minBracketSize) or 3
    local maxSize = tonumber(prefs.maxBracketSize) or 9
    
    if #bracketGroup >= minSize and #bracketGroup <= maxSize then
      
      local exposureAnalysis = analyzeExposurePattern(bracketGroup, prefs)
      local confidence = 50 -- Base confidence
      
      -- Adjust confidence based on various factors
      if exposureAnalysis.valid then
        confidence = confidence + 30
      end
      
      -- Convert defaultBracketSize to number, handling 'custom' case
      local targetSize = prefs.defaultBracketSize
      if targetSize == 'custom' then
        targetSize = prefs.customBracketSize or 3
      end
      targetSize = tonumber(targetSize) or 3
      
      if #bracketGroup == targetSize then
        confidence = confidence + 10
      end
      
      -- Check orientation consistency for panorama hints
      local orientations = {}
      for _, data in ipairs(bracketGroup) do
        orientations[data.orientation] = (orientations[data.orientation] or 0) + 1
      end
      
      local orientationConsistency = 0
      for _, count in pairs(orientations) do
        orientationConsistency = math.max(orientationConsistency, count / #bracketGroup)
      end
      
      if orientationConsistency >= 0.8 then
        confidence = confidence + 10
      end
      
      table.insert(brackets, {
        photos = bracketGroup,
        startTime = bracketGroup[1].timestamp,
        endTime = bracketGroup[#bracketGroup].timestamp,
        duration = bracketGroup[#bracketGroup].timestamp - bracketGroup[1].timestamp,
        size = #bracketGroup,
        confidence = math.min(confidence, 100),
        exposureAnalysis = exposureAnalysis,
        orientationConsistency = orientationConsistency,
        predominantOrientation = nil -- Will be set later
      })
      
      -- Determine predominant orientation
      local maxCount = 0
      for orientation, count in pairs(orientations) do
        if count > maxCount then
          maxCount = count
          brackets[#brackets].predominantOrientation = orientation
        end
      end
    end
    
    i = j
  end
  
  return brackets
end

-- Classify brackets as individual or panorama sequences
local function classifyBracketSequences(brackets, prefs)
  if #brackets <= 1 then 
    for _, bracket in ipairs(brackets) do
      bracket.type = 'individual'
      bracket.sequenceId = 1
    end
    return { { type = 'individual', brackets = brackets } }
  end
  
  local sequences = {}
  local currentSequence = nil
  local sequenceId = 1
  
  for i, bracket in ipairs(brackets) do
    local isNewSequence = true
    
    if currentSequence and i > 1 then
      local prevBracket = brackets[i-1]
      local timeBetween = bracket.startTime - prevBracket.endTime
      
      -- Check if this bracket could be part of a panorama sequence
      local panoramaBracketGap = tonumber(prefs.panoramaBracketGap) or 8.0
      if timeBetween <= panoramaBracketGap then
        -- Additional checks for panorama classification
        local orientationMatch = true
        
        if prefs.useOrientationAsPanoramaHint then
          local expectedOrientation = prefs.panoramaOrientation
          if expectedOrientation ~= 'both' then
            orientationMatch = bracket.predominantOrientation == expectedOrientation
          end
        end
        
        if orientationMatch then
          isNewSequence = false
        end
      end
    end
    
    if isNewSequence then
      -- Start new sequence
      currentSequence = {
        type = 'individual', -- Will be updated if it becomes a panorama
        brackets = { bracket },
        startTime = bracket.startTime,
        endTime = bracket.endTime,
        sequenceId = sequenceId
      }
      table.insert(sequences, currentSequence)
      sequenceId = sequenceId + 1
    else
      -- Add to current sequence
      table.insert(currentSequence.brackets, bracket)
      currentSequence.endTime = bracket.endTime
    end
    
    bracket.sequenceId = currentSequence.sequenceId
  end
  
  -- Classify sequences as panorama if they meet criteria
  for _, sequence in ipairs(sequences) do
    local bracketCount = #sequence.brackets
    
    -- Convert panorama position preferences to numbers
    local minPositions = tonumber(prefs.minPanoramaPositions) or 3
    local maxPositions = tonumber(prefs.maxPanoramaPositions) or 20
    
    if bracketCount >= minPositions and bracketCount <= maxPositions then
      sequence.type = 'panorama'
      
      -- Mark all brackets in this sequence as panorama
      for _, bracket in ipairs(sequence.brackets) do
        bracket.type = 'panorama'
      end
    else
      -- Mark as individual brackets
      for _, bracket in ipairs(sequence.brackets) do
        bracket.type = 'individual'
      end
    end
  end
  
  return sequences
end

-- Handle incomplete brackets by merging retry attempts
local function handleIncompleteBrackets(sequences, prefs)
  if not prefs.handleIncompleteBrackets then
    return sequences
  end
  
  for _, sequence in ipairs(sequences) do
    if prefs.mergeIncompleteAttempts then
      -- Look for incomplete brackets followed by complete ones
      local i = 1
      while i < #sequence.brackets do
        local currentBracket = sequence.brackets[i]
        local nextBracket = sequence.brackets[i + 1]
        
        -- Check if current bracket might be incomplete
        -- Convert defaultBracketSize to number, handling 'custom' case
        local targetSize = prefs.defaultBracketSize
        if targetSize == 'custom' then
          targetSize = prefs.customBracketSize or 3
        end
        targetSize = tonumber(targetSize) or 3
        
        if currentBracket.size < targetSize and
           nextBracket.size >= targetSize then
          
          local timeBetween = nextBracket.startTime - currentBracket.endTime
          
          -- If they're close in time, consider merging
          local individualBracketGap = tonumber(prefs.individualBracketGap) or 30.0
          if timeBetween <= individualBracketGap * 0.5 then
            -- Merge the incomplete bracket into the complete one
            for _, photoData in ipairs(currentBracket.photos) do
              table.insert(nextBracket.photos, 1, photoData) -- Insert at beginning
            end
            
            -- Update bracket properties
            nextBracket.size = #nextBracket.photos
            nextBracket.startTime = currentBracket.startTime
            nextBracket.confidence = math.max(currentBracket.confidence, nextBracket.confidence)
            
            -- Re-sort photos by timestamp
            table.sort(nextBracket.photos, function(a, b)
              return a.timestamp < b.timestamp
            end)
            
            -- Remove the incomplete bracket
            table.remove(sequence.brackets, i)
            
            Log.debug("Merged incomplete bracket with " .. currentBracket.size .. " photos into complete bracket")
          else
            i = i + 1
          end
        else
          i = i + 1
        end
      end
    end
  end
  
  return sequences
end

-- Simple bracket detection function that works without metadata (no yielding)
function BracketStacking.detectBracketsSimple(photos, progressCallback)
  local prefs = LrPrefs.prefsForPlugin()
  
  Log.info("=== SIMPLE BRACKET DETECTION (NO METADATA) ===")
  Log.info("Context: Async task, NO metadata extraction - completely safe")
  Log.info(string.format("Input: %d photo objects", #photos))
  Log.info("Using index-based grouping to avoid all yielding issues")
  
  if not prefs.enableBracketStacking then
    Log.warning("Bracket stacking is disabled - returning empty results")
    return { sequences = {}, stats = { totalPhotos = #photos, processedPhotos = 0 } }
  end
  
  -- Get bracket size from preferences
  local bracketSize = prefs.defaultBracketSize
  if bracketSize == 'custom' then
    bracketSize = prefs.customBracketSize or 3
  end
  bracketSize = tonumber(bracketSize) or 3
  
  Log.info("Simple detection preferences:")
  Log.info("  - bracketSize: " .. tostring(bracketSize))
  Log.info("  - totalPhotos: " .. tostring(#photos))
  
  -- Safe progress callback wrapper
  local function safeProgressCallback(progress, status)
    if progressCallback then
      local success, err = pcall(progressCallback, progress, status)
      if not success then
        Log.warning("Progress callback failed: " .. tostring(err))
      end
    end
  end
  
  safeProgressCallback(0.3, "Creating simple bracket groups...")
  
  -- Create simple bracket groups based on index position
  local brackets = {}
  local photoIndex = 1
  
  while photoIndex <= #photos do
    local bracketPhotos = {}
    
    -- Group photos by bracket size
    for i = 0, bracketSize - 1 do
      if photoIndex + i <= #photos then
        -- Create minimal photo data structure
        table.insert(bracketPhotos, {
          uuid = "simple_" .. (photoIndex + i), -- Temporary UUID for grouping
          photoIndex = photoIndex + i,
          photo = photos[photoIndex + i] -- Store the actual photo object
        })
      end
    end
    
    if #bracketPhotos >= 2 then -- At least 2 photos needed for a stack
      table.insert(brackets, {
        photos = bracketPhotos,
        size = #bracketPhotos,
        confidence = 75, -- Medium confidence for simple detection
        type = 'individual'
      })
      
      Log.debug(string.format("Created simple bracket %d with %d photos (positions %d-%d)",
        #brackets, #bracketPhotos, photoIndex, photoIndex + #bracketPhotos - 1))
    end
    
    photoIndex = photoIndex + bracketSize
  end
  
  safeProgressCallback(0.6, "Organizing bracket sequences...")
  
  -- Create a single sequence containing all brackets
  local sequences = {}
  if #brackets > 0 then
    table.insert(sequences, {
      type = 'individual',
      brackets = brackets,
      sequenceId = 1
    })
  end
  
  safeProgressCallback(0.9, "Calculating statistics...")
  
  -- Calculate statistics
  local stats = {
    totalPhotos = #photos,
    processedPhotos = 0,
    totalSequences = #sequences,
    panoramaSequences = 0,
    individualSequences = #sequences,
    totalStacks = #brackets,
    unmatchedPhotos = #photos
  }
  
  for _, bracket in ipairs(brackets) do
    stats.processedPhotos = stats.processedPhotos + bracket.size
  end
  
  stats.unmatchedPhotos = stats.totalPhotos - stats.processedPhotos
  
  safeProgressCallback(1.0, "Detection complete")
  
  Log.info(string.format("Simple bracket detection complete: %d sequences, %d stacks, %d/%d photos processed", 
    stats.totalSequences, stats.totalStacks, stats.processedPhotos, stats.totalPhotos))
  
  return {
    sequences = sequences,
    stats = stats
  }
end

-- New bracket detection function that works with pre-extracted metadata
function BracketStacking.detectBracketsFromMetadata(photoData, progressCallback)
  local prefs = LrPrefs.prefsForPlugin()
  
  Log.info("=== BRACKET DETECTION FROM CACHED METADATA ===")
  Log.info("Context: Async task, using cached data only - NO metadata calls")
  Log.info(string.format("Input: %d cached metadata records", #photoData))
  Log.info("Bracket stacking enabled: " .. tostring(prefs.enableBracketStacking))
  
  -- Log data availability
  local hasTimestamps = 0
  local hasExposureData = 0
  for _, data in ipairs(photoData) do
    if data.timestamp then hasTimestamps = hasTimestamps + 1 end
    if data.exposureValue then hasExposureData = hasExposureData + 1 end
  end
  
  Log.info(string.format("Data quality: %d/%d have timestamps, %d/%d have exposure data", 
    hasTimestamps, #photoData, hasExposureData, #photoData))
  
  if not prefs.enableBracketStacking then
    Log.warning("Bracket stacking is disabled - returning empty results")
    return { sequences = {}, stats = { totalPhotos = #photoData, processedPhotos = 0 } }
  end
  
  -- Log all relevant preferences
  Log.info("Bracket detection preferences:")
  Log.info("  - minBracketSize: " .. tostring(prefs.minBracketSize))
  Log.info("  - maxBracketSize: " .. tostring(prefs.maxBracketSize))
  Log.info("  - defaultBracketSize: " .. tostring(prefs.defaultBracketSize))
  Log.info("  - customBracketSize: " .. tostring(prefs.customBracketSize))
  Log.info("  - withinBracketInterval: " .. tostring(prefs.withinBracketInterval))
  Log.info("  - individualBracketGap: " .. tostring(prefs.individualBracketGap))
  Log.info("  - panoramaBracketGap: " .. tostring(prefs.panoramaBracketGap))
  Log.info("  - useExposureValuesForDetection: " .. tostring(prefs.useExposureValuesForDetection))
  Log.info("  - minExposureStep: " .. tostring(prefs.minExposureStep))
  Log.info("  - maxExposureStep: " .. tostring(prefs.maxExposureStep))
  
  -- Safe progress callback wrapper
  local function safeProgressCallback(progress, status)
    if progressCallback then
      local success, err = pcall(progressCallback, progress, status)
      if not success then
        Log.warning("Progress callback failed: " .. tostring(err))
      end
    end
  end
  
  safeProgressCallback(0.3, "Detecting bracket patterns...")
  
  -- Step 1: Detect bracket patterns (metadata already extracted)
  local brackets = detectBracketPatterns(photoData, prefs)
  
  safeProgressCallback(0.6, "Classifying bracket sequences...")
  
  -- Step 2: Classify as individual vs panorama sequences
  local sequences = classifyBracketSequences(brackets, prefs)
  
  safeProgressCallback(0.8, "Handling incomplete brackets...")
  
  -- Step 3: Handle incomplete brackets
  sequences = handleIncompleteBrackets(sequences, prefs)
  
  safeProgressCallback(0.9, "Calculating statistics...")
  
  -- Calculate statistics
  local stats = {
    totalPhotos = #photoData,
    processedPhotos = 0,
    totalSequences = #sequences,
    panoramaSequences = 0,
    individualSequences = 0,
    totalStacks = 0,
    unmatchedPhotos = #photoData
  }
  
  for _, sequence in ipairs(sequences) do
    if sequence.type == 'panorama' then
      stats.panoramaSequences = stats.panoramaSequences + 1
      stats.totalStacks = stats.totalStacks + 1
    else
      stats.individualSequences = stats.individualSequences + #sequence.brackets
      stats.totalStacks = stats.totalStacks + #sequence.brackets
    end
    
    for _, bracket in ipairs(sequence.brackets) do
      stats.processedPhotos = stats.processedPhotos + bracket.size
    end
  end
  
  stats.unmatchedPhotos = stats.totalPhotos - stats.processedPhotos
  
  safeProgressCallback(1.0, "Detection complete")
  
  Log.info(string.format("Bracket detection complete: %d sequences, %d stacks, %d/%d photos processed", 
    stats.totalSequences, stats.totalStacks, stats.processedPhotos, stats.totalPhotos))
  
  return {
    sequences = sequences,
    stats = stats
  }
end

-- Legacy bracket detection function (for backward compatibility)
function BracketStacking.detectBrackets(photos, progressCallback)
  local prefs = LrPrefs.prefsForPlugin()
  
  Log.info("=== BRACKET DETECTION STARTED (LEGACY) ===")
  Log.info("Total photos to analyze: " .. #photos)
  Log.info("Bracket stacking enabled: " .. tostring(prefs.enableBracketStacking))
  
  if not prefs.enableBracketStacking then
    Log.warning("Bracket stacking is disabled - returning empty results")
    return { sequences = {}, stats = { totalPhotos = #photos, processedPhotos = 0 } }
  end
  
  -- CRITICAL: Extract ALL photo metadata BEFORE any progress callbacks
  -- This must be done outside of any progress callback context to avoid yielding errors
  Log.info("=== EXTRACTING PHOTO METADATA (NO PROGRESS CALLBACKS) ===")
  local photoData = sortPhotosByTime(photos)
  
  -- Now use the new metadata-based function
  return BracketStacking.detectBracketsFromMetadata(photoData, progressCallback)
end

-- Create stacks from detected brackets
function BracketStacking.createStacks(detectionResults, progressCallback)
  local prefs = LrPrefs.prefsForPlugin()
  local catalog = LrApplication.activeCatalog()

  if not detectionResults or not detectionResults.sequences then
    return false, "No detection results provided"
  end

  local sequences = detectionResults.sequences
  local stacksCreated = 0
  local totalBrackets = 0
  
  -- Count total brackets for progress
  for _, sequence in ipairs(sequences) do
    totalBrackets = totalBrackets + #sequence.brackets
  end
  
  if totalBrackets == 0 then
    return false, "No brackets detected"
  end
  
  Log.info("Creating " .. totalBrackets .. " stacks from detected brackets")
  
  local currentBracket = 0
  
  -- Safe progress callback wrapper
  local function safeProgressCallback(progress, status)
    if progressCallback then
      local success, err = pcall(progressCallback, progress, status)
      if not success then
        Log.warning("Progress callback failed during stack creation: " .. tostring(err))
      end
    end
  end
  
  catalog:withWriteAccessDo('Create Bracket Stacks', function()

    Log.info("Resolving photos by UUID within write context")
    

    for _, sequence in ipairs(sequences) do
      for _, bracket in ipairs(sequence.brackets) do
        currentBracket = currentBracket + 1

        if #bracket.photos >= 2 then
          -- Call progress callback before photo operations to avoid yielding issues
          safeProgressCallback(currentBracket / totalBrackets,
            "Creating stack " .. currentBracket .. " of " .. totalBrackets)

          -- Resolve photo objects (handle both UUID-based and simple detection)
          local resolvedPhotos = {}
          for _, photoData in ipairs(bracket.photos) do
            local photo = nil

            if photoData.photo then
              -- Simple detection: photo object already available
              photo = photoData.photo
              Log.debug(string.format("Using direct photo object for position %d",
                photoData.photoIndex or 0))

              -- Verify that the photo object supports stacking
              if type(photo.addToStack) ~= 'function'
                and photoData.uuid and photoData.uuid ~= ""
                and not photoData.uuid:match("^simple_") then
                Log.debug(string.format(
                  "Direct photo missing addToStack, retrying with UUID: %s",
                  photoData.uuid))
                photo = catalog:findPhotoByUuid(photoData.uuid)
                if photo then
                  Log.debug(string.format("Resolved photo by UUID: %s", photoData.uuid))
                end
              end
            elseif photoData.uuid and photoData.uuid ~= "" and not photoData.uuid:match("^simple_") then
              -- UUID-based detection: resolve by UUID
              photo = catalog:findPhotoByUuid(photoData.uuid)
              Log.debug(string.format("Resolved photo by UUID: %s", photoData.uuid))
            end

            if photo and type(photo.addToStack) == 'function' then
              table.insert(resolvedPhotos, {
                photo = photo,
                photoData = photoData
              })
            else
              Log.warning(string.format("Could not resolve photo for stacking (UUID: %s, hasPhoto: %s)",
                tostring(photoData.uuid), tostring(photoData.photo ~= nil)))
            end
          end

          if #resolvedPhotos < 2 then
            Log.warning(string.format("Skipping bracket %d: only %d valid photos resolved",
              currentBracket, #resolvedPhotos))
          else
            -- Remove any existing stacks first
            for _, resolved in ipairs(resolvedPhotos) do
              local ok, inStack = pcall(function()
                return resolved.photo:getRawMetadata('isInStackInFolder')
              end)
              if ok and inStack then
                local removed, err = pcall(function() resolved.photo:removeFromStack() end)
                if not removed then
                  Log.warning("Failed to remove photo from existing stack: " .. tostring(err))
                end
              end
            end

            -- Determine top photo based on preferences
            local topResolved = resolvedPhotos[1] -- Default to first

            if prefs.individualStackTopSelection == 'middle_exposure' and #resolvedPhotos >= 3 then
              local middleIndex = math.ceil(#resolvedPhotos / 2)
              topResolved = resolvedPhotos[middleIndex]
            elseif prefs.individualStackTopSelection == 'base_exposure' then
              -- Find the photo with exposure closest to 0 EV (if available)
              local bestResolved = resolvedPhotos[1]
              local bestDiff = math.huge

              for _, resolved in ipairs(resolvedPhotos) do
                if resolved.photoData.exposureValue then
                  local diff = math.abs(resolved.photoData.exposureValue)
                  if diff < bestDiff then
                    bestDiff = diff
                    bestResolved = resolved
                  end
                end
              end
              topResolved = bestResolved
            elseif prefs.individualStackTopSelection == 'last_image' then
              topResolved = resolvedPhotos[#resolvedPhotos]
            end

            local topPhoto = topResolved.photo
            Log.debug(string.format("Selected top photo for bracket %d: UUID=%s (type=%s, addToStack=%s)",
              currentBracket, topResolved.photoData.uuid, type(topPhoto), type(topPhoto.addToStack)))


            -- Create the stack using catalog method (more reliable than photo method)
            for _, resolved in ipairs(resolvedPhotos) do
              if resolved.photo ~= topPhoto then
                catalog:createPhotoStack(topPhoto, resolved.photo)
              end
            end

            -- Apply color label based on stack type
            local colorLabel = nil
            if bracket.type == 'panorama' then
              colorLabel = prefs.panoramaStackColorLabel
            else
              colorLabel = prefs.individualStackColorLabel
            end

            if colorLabel and colorLabel ~= 'none' then
              topPhoto:setRawMetadata('colorNameForLabel', colorLabel)
            end

            -- Collapse stack if it's part of a larger panorama sequence
            if sequence.type == 'panorama' and #sequence.brackets > 1 then
              topPhoto:setStackCollapsed(true)
            end

            stacksCreated = stacksCreated + 1

            Log.debug(string.format("Created %s stack with %d photos (confidence: %d%%)",
              bracket.type, #resolvedPhotos, bracket.confidence))
          end
        else
          Log.warning(string.format("Skipping bracket %d: only %d photo(s)",
            currentBracket, #bracket.photos))
        end
      end
    end
  end)
  
  Log.info("Successfully created " .. stacksCreated .. " bracket stacks")
  
  return true, "Created " .. stacksCreated .. " stacks from " .. detectionResults.stats.processedPhotos .. " photos"
end

-- Validate bracket stacking preferences
function BracketStacking.validatePreferences(prefs)
  local errors = {}
  
  -- Convert preferences to numbers for validation
  local minBracketSize = tonumber(prefs.minBracketSize)
  local maxBracketSize = tonumber(prefs.maxBracketSize)
  local withinBracketInterval = tonumber(prefs.withinBracketInterval)
  local individualBracketGap = tonumber(prefs.individualBracketGap)
  local panoramaBracketGap = tonumber(prefs.panoramaBracketGap)
  local minExposureStep = tonumber(prefs.minExposureStep)
  local maxExposureStep = tonumber(prefs.maxExposureStep)
  local minPanoramaPositions = tonumber(prefs.minPanoramaPositions)
  local maxPanoramaPositions = tonumber(prefs.maxPanoramaPositions)
  
  -- Check numeric ranges
  if minBracketSize and (minBracketSize < 2 or minBracketSize > 20) then
    table.insert(errors, "Minimum bracket size must be between 2 and 20")
  end
  
  if maxBracketSize and (maxBracketSize < 2 or maxBracketSize > 20) then
    table.insert(errors, "Maximum bracket size must be between 2 and 20")
  end
  
  if minBracketSize and maxBracketSize and minBracketSize > maxBracketSize then
    table.insert(errors, "Minimum bracket size cannot be greater than maximum bracket size")
  end
  
  -- Check time thresholds
  if withinBracketInterval and withinBracketInterval <= 0 then
    table.insert(errors, "Within-bracket interval must be positive")
  end
  
  if individualBracketGap and individualBracketGap <= 0 then
    table.insert(errors, "Individual bracket gap must be positive")
  end
  
  if panoramaBracketGap and panoramaBracketGap <= 0 then
    table.insert(errors, "Panorama bracket gap must be positive")
  end
  
  -- Check exposure settings
  if minExposureStep and maxExposureStep and minExposureStep > maxExposureStep then
    table.insert(errors, "Minimum exposure step cannot be greater than maximum exposure step")
  end
  
  -- Check panorama settings
  if minPanoramaPositions and maxPanoramaPositions and minPanoramaPositions > maxPanoramaPositions then
    table.insert(errors, "Minimum panorama positions cannot be greater than maximum panorama positions")
  end
  
  return #errors == 0, errors
end

return BracketStacking
