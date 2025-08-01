-- Enhanced Tagset.lua with maximum compatibility and crash prevention
local function safeCall(func, ...)
  local ok, result = pcall(func, ...)
  return ok, result
end

local function safeImport(moduleName)
  local ok, result = safeCall(import, moduleName)
  return ok and result or nil
end

-- Create a minimal logging function that won't crash
local function safeLog(message)
  -- Don't use Log module here as it might not be available during tagset creation
  -- Just silently continue - tagset creation happens very early in plugin lifecycle
end

-- Try to create tagset with maximum compatibility
local function createCompatibleTagset()
  local tagsetSpec = {
    id = 'wildlifeAI_tagset',
    title = 'WildlifeAI',
    items = {
      'wai_detectedSpecies','wai_speciesConfidence','wai_quality','wai_rating','wai_sceneCount',
      'wai_featureSimilarity','wai_featureConfidence','wai_colorSimilarity','wai_colorConfidence','wai_jsonPath','wai_processed'
    }
  }

  -- Try multiple approaches in order of preference
  local approaches = {
    function()
      local Factory = safeImport('LrMetadataTagsetFactory')
      if Factory and Factory.createTagset then
        return Factory.createTagset(tagsetSpec)
      end
      return nil
    end,
    function()
      local LrMetadataTagset = safeImport('LrMetadataTagset')
      if LrMetadataTagset and LrMetadataTagset.createTagsetFromItems then
        return LrMetadataTagset.createTagsetFromItems(tagsetSpec)
      end
      return nil
    end,
    function()
      local LrMetadataTagset = safeImport('LrMetadataTagset')
      if LrMetadataTagset and LrMetadataTagset.createTagset then
        return LrMetadataTagset.createTagset(tagsetSpec)
      end
      return nil
    end,
    function()
      -- Final fallback - just return the spec itself
      return tagsetSpec
    end
  }

  for i, approach in ipairs(approaches) do
    local ok, result = safeCall(approach)
    if ok and result then
      safeLog('Tagset creation succeeded with approach ' .. i)
      return result
    end
  end

  -- This should never happen, but just in case
  safeLog('All tagset creation approaches failed, returning minimal spec')
  return tagsetSpec
end

-- Wrap everything in a safe call to prevent any crashes
local ok, result = safeCall(createCompatibleTagset)
if ok and result then
  return result
else
  -- Last resort fallback
  return {
    id = 'wildlifeAI_tagset',
    title = 'WildlifeAI',
    items = {
      'wai_detectedSpecies','wai_speciesConfidence','wai_quality','wai_rating','wai_sceneCount',
      'wai_featureSimilarity','wai_featureConfidence','wai_colorSimilarity','wai_colorConfidence','wai_jsonPath'
    }
  }
end
