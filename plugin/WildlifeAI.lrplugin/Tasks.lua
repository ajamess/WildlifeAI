local LrFunctionContext = import 'LrFunctionContext'
local LrTasks           = import 'LrTasks'
local LrDialogs         = import 'LrDialogs'
local LrProgressScope   = import 'LrProgressScope'
local LrApplication     = import 'LrApplication'
local LrLogger          = import 'LrLogger'
local LrPrefs           = import 'LrPrefs'

local json              = require 'utils/dkjson'
local Bridge            = require 'KestrelBridge'
local KeywordHelper     = require 'KeywordHelper'

local logger = LrLogger('WildlifeAI')
logger:enable('print')

local function mirrorToIptc(photo, fieldName, value)
  -- Example: push to Job Identifier so it can sort
  -- WARNING: requires write-access & may dirty original metadata
  -- Implementation is left minimal; extend via photo:setRawMetadata if allowed
end

local function writeMetadata(photo, data)
  photo:setPropertyForPlugin(_PLUGIN, 'wai_detectedSpecies',   data.detected_species or '')
  photo:setPropertyForPlugin(_PLUGIN, 'wai_speciesConfidence', data.species_confidence or 0)
  photo:setPropertyForPlugin(_PLUGIN, 'wai_quality',           data.quality or 0)
  photo:setPropertyForPlugin(_PLUGIN, 'wai_rating',            data.rating or 0)
  photo:setPropertyForPlugin(_PLUGIN, 'wai_sceneCount',        data.scene_count or 0)
  photo:setPropertyForPlugin(_PLUGIN, 'wai_featureSimilarity', data.feature_similarity or 0)
  photo:setPropertyForPlugin(_PLUGIN, 'wai_colorSimilarity',   data.color_similarity or 0)
  photo:setPropertyForPlugin(_PLUGIN, 'wai_colorConfidence',   data.color_confidence or 0)
  photo:setPropertyForPlugin(_PLUGIN, 'wai_jsonPath',          data.json_path or '')

  local prefs = LrPrefs.prefsForPlugin()
  -- Keywords
  local root = prefs.keywordRoot or 'WildlifeAI'
  KeywordHelper.applyKeywords(photo, root, data)

  if prefs.mirrorToIptc then
    mirrorToIptc(photo, 'wai_quality', data.quality or 0)
  end
end

local function analyzeSelectedPhotos()
  LrFunctionContext.callWithContext('WildlifeAI_Analyze', function(context)
    local catalog = LrApplication.activeCatalog()
    local photos = catalog:getTargetPhotos()
    if #photos == 0 then
      LrDialogs.message('WildlifeAI', 'No photos selected.')
      return
    end

    local progress = LrProgressScope{ title = 'WildlifeAI Analysis', functionContext = context }
    progress:setCancelable(true)

    LrTasks.startAsyncTask(function()
      local results = Bridge.runKestrel(photos)

      catalog:withWriteAccessDo('WildlifeAI Metadata Write', function()
        local i = 0
        for _,photo in ipairs(photos) do
          if progress:isCanceled() then break end
          local pth = photo:getRawMetadata('path')
          local data = results[pth] or {}
          writeMetadata(photo, data)
          i = i + 1
          progress:setPortionComplete(i, #photos)
          progress:setCaption(string.format('Wrote metadata %d/%d', i, #photos))
        end
      end)

      local prefs = LrPrefs.prefsForPlugin()
      if prefs.enableStacking then
        require('QualityStack').stackByScene(photos)
      end

      progress:done()
      LrDialogs.message('WildlifeAI', 'Analysis complete!')
    end)
  end)
end

local function dispatch()
  local cmd = _PLUGIN.command
  if cmd == 'Analyze Selected Photos with WildlifeAI' or cmd == 'Re-run Analysis on Missing Results' then
    analyzeSelectedPhotos()
  end
end

dispatch()