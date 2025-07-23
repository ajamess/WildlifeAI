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
LrTasks.startAsyncTask(function()
  local clk = Log.enter('AnalyzeMenu')
  LrFunctionContext.callWithContext('WildlifeAI_Analyze', function(context)
    Log.debug('Analyze context created')
    local catalog = LrApplication.activeCatalog()
    local photos = catalog:getTargetPhotos()
    if #photos == 0 then
      LrDialogs.message('WildlifeAI', 'No photos selected.')
      Log.info('No photos selected for analysis')
      Log.leave(clk, 'AnalyzeMenu')
      return
    end
    local progress = LrProgressScope{ title = 'WildlifeAI Analysis', functionContext = context }
    progress:setCancelable(true)
    Log.info('Calling Bridge.run with '..#photos..' photos')
    local results = Bridge.run(photos)
    catalog:withWriteAccessDo('WildlifeAI write', function()
      Log.debug('withWriteAccessDo begin')
      for _,photo in ipairs(photos) do
        local data = results[photo:getRawMetadata('path')] or {}
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
      Log.debug('withWriteAccessDo end')
    end, { timeout = 300 })
    local prefs = LrPrefs.prefsForPlugin()
    if prefs.enableKeywords then
      catalog:withWriteAccessDo('WildlifeAI keywords', function()
        for _,photo in ipairs(photos) do
          KW.apply(photo, prefs.keywordRoot or 'WildlifeAI', {
            detected_species = photo:getPropertyForPlugin(_PLUGIN, 'wai_detectedSpecies') or '',
            quality = tonumber(photo:getPropertyForPlugin(_PLUGIN,'wai_quality') or '0') or 0,
            species_confidence = tonumber(photo:getPropertyForPlugin(_PLUGIN,'wai_speciesConfidence') or '0') or 0,
          })
        end
      end, { timeout = 300 })
    end
    progress:done()
    LrDialogs.message('WildlifeAI', 'Analysis complete!')
    Log.info('Analysis complete')
  end)
  Log.leave(clk, 'AnalyzeMenu')
end)
