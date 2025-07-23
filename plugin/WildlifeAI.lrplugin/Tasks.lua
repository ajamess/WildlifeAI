local LrFunctionContext = import 'LrFunctionContext'
local LrTasks           = import 'LrTasks'
local LrDialogs         = import 'LrDialogs'
local LrProgressScope   = import 'LrProgressScope'
local LrApplication     = import 'LrApplication'
local LrLogger          = import 'LrLogger'
local LrPrefs           = import 'LrPrefs'

local json              = require 'utils.dkjson'
local Bridge            = require 'KestrelBridge'
local KeywordHelper     = require 'KeywordHelper'

local logger = LrLogger('WildlifeAI'); logger:enable('print')

local function writeMetadata(photo, data)
  photo:setPropertyForPlugin(_PLUGIN, 'wai_detectedSpecies',   data.detected_species or '')
  photo:setPropertyForPlugin(_PLUGIN, 'wai_speciesConfidence', tostring(data.species_confidence or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_quality',           tostring(data.quality or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_rating',            tostring(data.rating or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_sceneCount',        tostring(data.scene_count or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_featureSimilarity', tostring(data.feature_similarity or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_colorSimilarity',   tostring(data.color_similarity or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_colorConfidence',   tostring(data.color_confidence or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_jsonPath',          data.json_path or '')

  local prefs = LrPrefs.prefsForPlugin()
  KeywordHelper.applyKeywords(photo, prefs.keywordRoot or 'WildlifeAI', {
    detected_species = data.detected_species or '',
    quality = tonumber(data.quality or 0) or 0,
    species_confidence = tonumber(data.species_confidence or 0) or 0,
  })
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
        for i,photo in ipairs(photos) do
          if progress:isCanceled() then break end
          local pth = photo:getRawMetadata('path')
          writeMetadata(photo, results[pth] or {})
          progress:setPortionComplete(i, #photos)
          progress:setCaption(string.format('Wrote %d/%d', i, #photos))
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

local cmd = _PLUGIN.command
if cmd == 'Analyze Selected Photos with WildlifeAI' or cmd == 'Re-run Analysis on Missing Results' then
  analyzeSelectedPhotos()
end
