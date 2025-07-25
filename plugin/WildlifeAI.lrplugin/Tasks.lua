local LrFunctionContext = import 'LrFunctionContext'
local LrTasks           = import 'LrTasks'
local LrDialogs         = import 'LrDialogs'
local LrProgressScope   = import 'LrProgressScope'
local LrApplication     = import 'LrApplication'
local LrPrefs           = import 'LrPrefs'
local LrPathUtils       = import 'LrPathUtils'

local json = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/dkjson.lua' ) )
local Log  = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/Log.lua' ) )
local Bridge = dofile( LrPathUtils.child( _PLUGIN.path, 'KestrelBridge.lua' ) )
local KW = dofile( LrPathUtils.child( _PLUGIN.path, 'KeywordHelper.lua' ) )

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
      Log.info('Analysis start for '..#photos)
      local results = Bridge.runKestrel(photos)

      catalog:withWriteAccessDo('WildlifeAI Metadata+Keywords', function()
        for i,photo in ipairs(photos) do
          if progress:isCanceled() then break end
          local pth = photo:getRawMetadata('path')
          local data = results[pth] or {}
          writeMetadata(photo, data)
          -- apply keywords (no internal write)
          local prefs = LrPrefs.prefsForPlugin()
          KW.applyKeywords_noWrite(photo, prefs.keywordRoot or 'WildlifeAI', {
            detected_species = data.detected_species or '',
            quality = tonumber(data.quality or 0) or 0,
            species_confidence = tonumber(data.species_confidence or 0) or 0,
          })
          progress:setPortionComplete(i, #photos)
          progress:setCaption(string.format('Wrote %d/%d', i, #photos))
        end
      end, { timeout = 60 })

      local prefs = LrPrefs.prefsForPlugin()
      if prefs.enableStacking then
        catalog:withWriteAccessDo('WildlifeAI Stack', function()
          require('QualityStack')
        end, { timeout = 60 })
      end

      progress:done()
      Log.info('Analysis complete')
      LrDialogs.message('WildlifeAI', 'Analysis complete!')
    end)
  end)
end

analyzeSelectedPhotos()
