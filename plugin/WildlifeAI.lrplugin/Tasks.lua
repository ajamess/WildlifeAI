local LrFunctionContext=import'LrFunctionContext'
local LrTasks=import'LrTasks'
local LrDialogs=import'LrDialogs'
local LrProgressScope=import'LrProgressScope'
local LrApplication=import'LrApplication'
local LrLogger=import'LrLogger'
local LrPrefs=import'LrPrefs'
local json=require'utils/dkjson'
local Bridge=require'KestrelBridge'
local KeywordHelper=require'KeywordHelper'
local logger=LrLogger('WildlifeAI');logger:enable('print')
local function writeMeta(photo,d)
  photo:setPropertyForPlugin(_PLUGIN,'wai_detectedSpecies',d.detected_species or '')
  photo:setPropertyForPlugin(_PLUGIN,'wai_speciesConfidence',tostring(d.species_confidence or 0))
  photo:setPropertyForPlugin(_PLUGIN,'wai_quality',tostring(d.quality or 0))
  photo:setPropertyForPlugin(_PLUGIN,'wai_rating',tostring(d.rating or 0))
  photo:setPropertyForPlugin(_PLUGIN,'wai_sceneCount',tostring(d.scene_count or 0))
  photo:setPropertyForPlugin(_PLUGIN,'wai_featureSimilarity',tostring(d.feature_similarity or 0))
  photo:setPropertyForPlugin(_PLUGIN,'wai_colorSimilarity',tostring(d.color_similarity or 0))
  photo:setPropertyForPlugin(_PLUGIN,'wai_colorConfidence',tostring(d.color_confidence or 0))
  photo:setPropertyForPlugin(_PLUGIN,'wai_jsonPath',d.json_path or '')
  local prefs=LrPrefs.prefsForPlugin()
  KeywordHelper.applyKeywords(photo,prefs.keywordRoot or 'WildlifeAI',{
    detected_species=d.detected_species or '',
    quality=tonumber(d.quality or 0) or 0,
    species_confidence=tonumber(d.species_confidence or 0) or 0,
  })
end
local function analyze()
  LrFunctionContext.callWithContext('WildlifeAI_Analyze',function(ctx)
    local catalog=LrApplication.activeCatalog()
    local photos=catalog:getTargetPhotos()
    if #photos==0 then LrDialogs.message('WildlifeAI','No photos selected.');return end
    local prog=LrProgressScope{title='WildlifeAI Analysis',functionContext=ctx};prog:setCancelable(true)
    LrTasks.startAsyncTask(function()
      local results=Bridge.runKestrel(photos)
      catalog:withWriteAccessDo('WildlifeAI Metadata',function()
        for i,p in ipairs(photos) do
          if prog:isCanceled() then break end
          local data=results[p:getRawMetadata('path')] or {}
          writeMeta(p,data)
          prog:setPortionComplete(i,#photos);prog:setCaption(string.format('Wrote %d/%d',i,#photos))
        end
      end)
      if LrPrefs.prefsForPlugin().enableStacking then require('QualityStack').stackByScene(photos) end
      prog:done();LrDialogs.message('WildlifeAI','Analysis complete!')
    end)
  end)
end
local cmd=_PLUGIN.command
if cmd=='Analyze Selected Photos with WildlifeAI' or cmd=='Re-run Analysis on Missing Results' then analyze() end
