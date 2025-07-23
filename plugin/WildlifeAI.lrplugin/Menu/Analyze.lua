local LrFunctionContext = import 'LrFunctionContext'
local LrTasks           = import 'LrTasks'
local LrDialogs         = import 'LrDialogs'
local LrProgressScope   = import 'LrProgressScope'
local LrApplication     = import 'LrApplication'
local LrPrefs           = import 'LrPrefs'
local LrPathUtils       = import 'LrPathUtils'

local Log    = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local Bridge = dofile( LrPathUtils.child(_PLUGIN.path, 'KestrelBridge.lua') )
local KW     = dofile( LrPathUtils.child(_PLUGIN.path, 'KeywordHelper.lua') )

local function writeOne(photo, data, prefs)
  photo:setPropertyForPlugin(_PLUGIN, 'wai_detectedSpecies',   data.detected_species or '')
  photo:setPropertyForPlugin(_PLUGIN, 'wai_speciesConfidence', tostring(data.species_confidence or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_quality',           tostring(data.quality or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_rating',            tostring(data.rating or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_sceneCount',        tostring(data.scene_count or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_featureSimilarity', tostring(data.feature_similarity or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_colorSimilarity',   tostring(data.color_similarity or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_colorConfidence',   tostring(data.color_confidence or 0))
  photo:setPropertyForPlugin(_PLUGIN, 'wai_jsonPath',          data.json_path or '')
  if prefs.enableKeywords then
    KW.apply(photo, prefs.keywordRoot or 'WildlifeAI', {
      detected_species = data.detected_species or '',
      quality = tonumber(data.quality or 0) or 0,
      species_confidence = tonumber(data.species_confidence or 0) or 0,
    })
  end
end

return function()
  LrFunctionContext.callWithContext('WildlifeAI_Analyze', function(context)
    LrTasks.startAsyncTask(function()
      local catalog = LrApplication.activeCatalog()
      local photos = catalog:getTargetPhotos()
      if #photos == 0 then
        LrDialogs.message('WildlifeAI', 'No photos selected.')
        return
      end

      local progress = LrProgressScope{ title = 'WildlifeAI Analysis', functionContext = context }
      progress:setCancelable(true)

      Log.info('Analysis start: '..#photos)
      local results = Bridge.run(photos)
      local prefs = LrPrefs.prefsForPlugin()

      catalog:withWriteAccessDo('WildlifeAI write', function()
        for i,photo in ipairs(photos) do
          writeOne(photo, results[photo:getRawMetadata('path')] or {}, prefs)
        end
      end, { timeout = 240 })

      progress:done()
      Log.info('Analysis complete')
      LrDialogs.message('WildlifeAI', 'Analysis complete!')
    end)
  end)
end
