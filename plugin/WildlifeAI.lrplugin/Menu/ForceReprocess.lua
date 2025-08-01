local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrProgressScope = import 'LrProgressScope'
local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local Bridge = dofile(LrPathUtils.child(_PLUGIN.path, 'SmartBridge.lua'))
local KW = dofile( LrPathUtils.child(_PLUGIN.path, 'KeywordHelper.lua') )

LrTasks.startAsyncTask(function()
  local clk = Log.enter('ForceReprocessMenu')
  LrFunctionContext.callWithContext('WAI_ForceReprocess', function(context)
    local catalog = LrApplication.activeCatalog()
    local photos = catalog:getTargetPhotos()
    if #photos==0 then LrDialogs.message('WildlifeAI','No photos selected'); Log.leave(clk,'ForceReprocessMenu'); return end
    
    local result = LrDialogs.confirm('Force Reprocess', 
      'This will force reprocessing of ' .. #photos .. ' selected photos, even if they have been processed before.\n\nThis will overwrite any existing results files.\n\nAre you sure?',
      'Reprocess', 'Cancel')
    
    if result ~= 'ok' then
      Log.leave(clk,'ForceReprocessMenu')
      return
    end
    
    local progress = LrProgressScope{ title='WildlifeAI Force Reprocessing', functionContext=context }
    progress:setCancelable(true)
    
    -- Force reprocess by passing true flag
    local results = Bridge.run(photos, nil, true)
    local prefs = LrPrefs.prefsForPlugin()
    
    catalog:withWriteAccessDo('WAI write reprocessed', function()
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
        set('wai_processed', 'true')
        
        -- Temporarily disable all keyword functionality to avoid yielding errors
        Log.info('Keyword functionality disabled to prevent yielding errors')
        
        -- Apply automatic rating, flagging, and color labeling based on preferences
        local ratingValue = d.rating or 0
        
        -- Set star rating (0-5 stars)
        if prefs.enableRating and photo.setRawMetadata then
          local success, err = pcall(function()
            photo:setRawMetadata('rating', ratingValue)
          end)
          if not success then
            Log.error('Failed to set rating: ' .. tostring(err))
          else
            Log.info('Set rating: ' .. ratingValue .. ' stars for ' .. (photo:getFormattedMetadata('fileName') or 'unknown'))
          end
        end
        
        -- Set rejection flag for low quality photos
        if prefs.enableRejection and photo.setRawMetadata then
          local shouldReject = ratingValue <= (prefs.rejectionThreshold or 2)
          local success, err = pcall(function()
            photo:setRawMetadata('pickStatus', shouldReject and -1 or 0)
          end)
          if not success then
            Log.error('Failed to set rejection flag: ' .. tostring(err))
          elseif shouldReject then
            Log.info('Marked as rejected: ' .. (photo:getFormattedMetadata('fileName') or 'unknown') .. ' (rating ' .. ratingValue .. ' <= ' .. (prefs.rejectionThreshold or 2) .. ')')
          end
        end
        
        -- Set pick flag for high quality photos
        if prefs.enablePicks and photo.setRawMetadata then
          local shouldPick = ratingValue >= (prefs.picksThreshold or 4)
          local success, err = pcall(function()
            photo:setRawMetadata('pickStatus', shouldPick and 1 or 0)
          end)
          if not success then
            Log.error('Failed to set pick flag: ' .. tostring(err))
          elseif shouldPick then
            Log.info('Marked as pick: ' .. (photo:getFormattedMetadata('fileName') or 'unknown') .. ' (rating ' .. ratingValue .. ' >= ' .. (prefs.picksThreshold or 4) .. ')')
          end
        end
        
        -- Set color label based on rating
        if prefs.enableColorLabels and photo.setRawMetadata then
          local colorLabel = nil
          if ratingValue == 0 then colorLabel = prefs.colorLabel0
          elseif ratingValue == 1 then colorLabel = prefs.colorLabel1
          elseif ratingValue == 2 then colorLabel = prefs.colorLabel2
          elseif ratingValue == 3 then colorLabel = prefs.colorLabel3
          elseif ratingValue == 4 then colorLabel = prefs.colorLabel4
          elseif ratingValue == 5 then colorLabel = prefs.colorLabel5
          end
          
          if colorLabel and colorLabel ~= 'none' then
            local success, err = pcall(function()
              photo:setRawMetadata('colorNameForLabel', colorLabel)
            end)
            if not success then
              Log.error('Failed to set color label: ' .. tostring(err))
            else
              Log.info('Set color label: ' .. colorLabel .. ' for ' .. (photo:getFormattedMetadata('fileName') or 'unknown') .. ' (rating ' .. ratingValue .. ')')
            end
          end
        end
        
        if prefs.mirrorJobId then
          local jid = string.format('Q:%s R:%s C:%s', d.quality or '', d.rating or '', d.scene_count or '')
          photo:setRawMetadata('jobIdentifier', jid)
        end
        if prefs.writeXMP then photo:saveMetadata() end
        progress:setPortionComplete(i,#photos)
      end
    end,{timeout=300})
    
    if prefs.enableStacking then
      catalog:withWriteAccessDo('WAI Stack', function() require('QualityStack') end,{timeout=120})
    end
    
    progress:done()
    LrDialogs.message('WildlifeAI','Force reprocessing complete')
    Log.leave(clk,'ForceReprocessMenu')
  end)
end)
