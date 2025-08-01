local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )

local M = {}

-- Helper function to get or create keyword hierarchy without yielding
local function getOrCreateKeywordHierarchy(catalog, keywordPath)
  if not keywordPath or keywordPath == '' then
    Log.warning('Empty keyword path provided')
    return nil
  end
  
  Log.info('Creating keyword hierarchy for: ' .. keywordPath)
  
  -- Split path by '>' separator
  local parts = {}
  for part in string.gmatch(keywordPath, '([^>]+)') do
    local trimmed = string.match(part, '^%s*(.-)%s*$') -- trim whitespace
    if trimmed and trimmed ~= '' then
      table.insert(parts, trimmed)
    end
  end
  
  if #parts == 0 then
    Log.warning('No valid parts found in keyword path: ' .. keywordPath)
    return nil
  end
  
  Log.info('Keyword path parts: ' .. table.concat(parts, ' > '))
  
  -- Build keyword hierarchy
  local parent = nil
  for i, name in ipairs(parts) do
    Log.info('Creating keyword part ' .. i .. ': ' .. name .. (parent and (' under ' .. parent:getName()) or ' as root'))
    
    -- First try to find existing keyword
    local existingKeywords = catalog:getKeywords(name)
    local keyword = nil
    
    -- Look for exact match under the correct parent
    for _, existingKeyword in ipairs(existingKeywords) do
      local existingParent = existingKeyword:getParent()
      if (parent == nil and existingParent == nil) or (parent and existingParent and existingParent == parent) then
        keyword = existingKeyword
        Log.info('Found existing keyword: ' .. name)
        break
      end
    end
    
    -- Create if not found
    if not keyword then
      local success, err = pcall(function()
        keyword = catalog:createKeyword(name, {}, true, parent, false) -- Don't allow duplicates
        Log.info('Created new keyword: ' .. name)
      end)
      
      if not success then
        Log.error('Failed to create keyword "' .. name .. '": ' .. tostring(err))
        return nil
      end
    end
    
    parent = keyword
  end
  
  Log.info('Successfully created/found keyword hierarchy: ' .. keywordPath)
  return parent
end

-- Helper function to bucket numeric values into ranges
local function bucketValue(value, bucketSize)
  local n = tonumber(value) or 0
  local start = math.floor(n / bucketSize) * bucketSize
  return start .. '-' .. (start + bucketSize - 1)
end

-- Enhanced keyword application that avoids yielding issues
function M.applyKeywords(photo, data, prefs, catalog)
  local clk = Log.enter('KeywordHelper.applyKeywords')
  
  if not prefs.enableKeywording then
    Log.info('Keywording is disabled in preferences')
    Log.leave(clk, 'KeywordHelper.applyKeywords')
    return true
  end
  
  if not photo or not data or not catalog then
    Log.error('Invalid parameters for keyword application')
    Log.leave(clk, 'KeywordHelper.applyKeywords')
    return false
  end
  
  local keywords = {}
  local keywordRoot = prefs.keywordRoot or 'WildlifeAI'
  
  -- Build keyword list based on preferences
  if prefs.keywordQuality and data.quality and data.quality >= 0 then
    local qualityBucket = bucketValue(data.quality, 10) -- 0-9, 10-19, etc.
    table.insert(keywords, keywordRoot .. '>Quality>' .. qualityBucket)
    Log.info('Added quality keyword: ' .. qualityBucket)
  end
  
  if prefs.keywordRating and data.rating and data.rating > 0 then
    table.insert(keywords, keywordRoot .. '>Rating>' .. data.rating .. ' Star' .. (data.rating == 1 and '' or 's'))
    Log.info('Added rating keyword: ' .. data.rating .. ' stars')
  end
  
  if prefs.keywordSpeciesConfidence and data.species_confidence and data.species_confidence >= 0 then
    local confidenceBucket = bucketValue(data.species_confidence, 10)
    table.insert(keywords, keywordRoot .. '>Confidence>' .. confidenceBucket)
    Log.info('Added confidence keyword: ' .. confidenceBucket)
  end
  
  if prefs.keywordSceneCount and data.scene_count and data.scene_count > 0 then
    local sceneKeyword
    if data.scene_count >= 3 then
      sceneKeyword = '3+ Scenes'
    else
      sceneKeyword = data.scene_count .. ' Scene' .. (data.scene_count == 1 and '' or 's')
    end
    table.insert(keywords, keywordRoot .. '>Scenes>' .. sceneKeyword)
    Log.info('Added scene count keyword: ' .. sceneKeyword)
  end
  
  if prefs.keywordDetectedSpecies and data.detected_species and data.detected_species ~= 'Unknown' and data.detected_species ~= '' then
    -- Add species under main keyword root
    table.insert(keywords, keywordRoot .. '>Species>' .. data.detected_species)
    Log.info('Added species keyword under WildlifeAI: ' .. data.detected_species)
    
    -- Optionally add under separate species root
    if prefs.keywordSpeciesUnderSpeciesRoot and prefs.speciesKeywordRoot and prefs.speciesKeywordRoot ~= '' then
      table.insert(keywords, prefs.speciesKeywordRoot .. '>' .. data.detected_species)
      Log.info('Added species keyword under species root: ' .. prefs.speciesKeywordRoot .. '>' .. data.detected_species)
    end
  end
  
  if #keywords == 0 then
    Log.info('No keywords to apply based on current data and preferences')
    Log.leave(clk, 'KeywordHelper.applyKeywords')
    return true
  end
  
  -- Apply keywords to photo - THIS MUST BE CALLED FROM WITHIN A CATALOG WRITE ACCESS BLOCK
  -- The caller (SmartBridge) is responsible for the withWriteAccessDo wrapper
  local success, err = pcall(function()
    local keywordObjects = {}
    
    -- Create all keyword hierarchies first
    for _, keywordPath in ipairs(keywords) do
      local keyword = getOrCreateKeywordHierarchy(catalog, keywordPath)
      if keyword then
        table.insert(keywordObjects, keyword)
        Log.info('Created/found keyword: ' .. keywordPath)
      else
        Log.warning('Failed to create keyword: ' .. keywordPath)
      end
    end
    
    -- Apply all keywords to the photo at once
    if #keywordObjects > 0 then
      photo:addKeywords(keywordObjects)
      Log.info('Applied ' .. #keywordObjects .. ' keywords to photo')
    end
  end)
  
  if not success then
    Log.error('Failed to apply keywords: ' .. tostring(err))
    Log.leave(clk, 'KeywordHelper.applyKeywords')
    return false
  end
  
  Log.info('Successfully applied keywords to photo')
  Log.leave(clk, 'KeywordHelper.applyKeywords')
  return true
end

-- New function for queue-based keyword processing - designed specifically for background processing
function M.applyKeywordsOnly(photo, data, prefs, catalog)
  local clk = Log.enter('KeywordHelper.applyKeywordsOnly')
  
  if not prefs.enableKeywording then
    Log.info('Keywording is disabled in preferences')
    Log.leave(clk, 'KeywordHelper.applyKeywordsOnly')
    return true
  end
  
  if not photo or not data or not catalog then
    Log.error('Invalid parameters for keyword-only application')
    Log.leave(clk, 'KeywordHelper.applyKeywordsOnly')
    return false
  end
  
  -- Use the same keyword building logic but in a dedicated function
  local success = M.applyKeywords(photo, data, prefs, catalog)
  
  if success then
    Log.info('Keywords applied successfully via queue processor')
  else
    Log.warning('Keyword application failed via queue processor')
  end
  
  Log.leave(clk, 'KeywordHelper.applyKeywordsOnly')
  return success
end

-- Function to generate keyword queue item for deferred processing
function M.createKeywordQueueItem(photo, data, timestamp)
  if not photo or not data then
    Log.error('Invalid parameters for keyword queue item creation')
    return nil
  end
  
  return {
    photo = photo,
    data = data,
    timestamp = timestamp or os.time(),
    photoPath = photo:getRawMetadata('path'),
    filename = LrPathUtils.leafName(photo:getRawMetadata('path'))
  }
end

-- Legacy function for backwards compatibility
function M.applyKeywords_noWrite(photo, root, data)
  Log.enter('KeywordHelper.applyKeywords_noWrite (legacy)')
  
  -- This legacy function is kept for backwards compatibility but doesn't do anything
  -- The new keywording system is integrated into SmartBridge with proper preferences
  Log.info('Legacy keyword function called - use new integrated keywording system instead')
  
  Log.leave('KeywordHelper.applyKeywords_noWrite (legacy)')
  return true
end

-- Alias for backwards compatibility
M.apply = M.applyKeywords_noWrite

return M
