local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrProgressScope = import 'LrProgressScope'
local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local Bridge = dofile( LrPathUtils.child(_PLUGIN.path, 'KestrelBridge.lua') )
LrTasks.startAsyncTask(function()
  local clk = Log.enter('AnalyzeMenu')
  LrFunctionContext.callWithContext('WAI_Analyze', function(context)
    local catalog = LrApplication.activeCatalog()
    local photos = catalog:getTargetPhotos()
    if #photos==0 then LrDialogs.message('WildlifeAI','No photos selected'); Log.leave(clk,'AnalyzeMenu'); return end
    local progress = LrProgressScope{ title='WildlifeAI Analysis', functionContext=context }
    progress:setCancelable(true)
    local results = Bridge.run(photos)
    catalog:withWriteAccessDo('WAI write', function()
      for i,photo in ipairs(photos) do
        local d = results[photo:getRawMetadata('path')] or {}
        local function set(id,v) photo:setPropertyForPlugin(_PLUGIN,id, tostring(v or '')) end
        set('wai_detectedSpecies', d.detected_species)
        set('wai_speciesConfidence', d.species_confidence)
        set('wai_quality', d.quality)
        set('wai_rating', d.rating)
        set('wai_sceneCount', d.scene_count)
        set('wai_featureSimilarity', d.feature_similarity)
        set('wai_featureConfidence', d.feature_confidence)
        set('wai_colorSimilarity', d.color_similarity)
        set('wai_colorConfidence', d.color_confidence)
        set('wai_jsonPath', d.json_path)
        progress:setPortionComplete(i,#photos)
      end
    end,{timeout=300})
    progress:done()
    LrDialogs.message('WildlifeAI','Analysis complete')
    Log.leave(clk,'AnalyzeMenu')
  end)
end)