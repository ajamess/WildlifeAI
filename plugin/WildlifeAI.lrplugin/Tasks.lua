local LrFunctionContext = import 'LrFunctionContext'
local LrTasks           = import 'LrTasks'
local LrDialogs         = import 'LrDialogs'
local LrProgressScope   = import 'LrProgressScope'
local LrApplication     = import 'LrApplication'
local LrPrefs           = import 'LrPrefs'
local LrPathUtils       = import 'LrPathUtils'

local json = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/dkjson.lua' ) )
local Log  = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/Log.lua' ) )
local Bridge            = require 'KestrelBridge'
local KeywordHelper     = require 'KeywordHelper'

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
      Log.info('Analysis started for '..#photos..' photos')
      local results = Bridge.runKestrel(photos)

      catalog:withWriteAccessDo('WildlifeAI Metadata Write', function()
        for i,photo in ipairs(photos) do
          if progress:isCanceled() then break end
          local pth = photo:getRawMetadata('path')
          writeMetadata(photo, results[pth] or {})
          progress:setPortionComplete(i, #photos)
          progress:setCaption(string.format('Wrote metadata %d/%d', i, #photos))
        end
      end)

      progress:done()
      Log.info('Analysis complete')
      LrDialogs.message('WildlifeAI', 'Analysis complete!')
    end)
  end)
end

-- Execute directly when invoked
analyzeSelectedPhotos()
