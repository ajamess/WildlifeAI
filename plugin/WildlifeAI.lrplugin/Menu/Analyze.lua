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
  local clk = Log.enter('AnalyzeMenu')
  LrFunctionContext.callWithContext('WAI_Analyze', function(context)
    local catalog = LrApplication.activeCatalog()
    local photos = catalog:getTargetPhotos()
    if #photos==0 then LrDialogs.message('WildlifeAI','No photos selected'); Log.leave(clk,'AnalyzeMenu'); return end
    local progress = LrProgressScope{ title='WildlifeAI Analysis', functionContext=context }
    progress:setCancelable(true)
    
    -- Create progress callback to update the progress bar with error isolation
    local startTime = os.time()  -- Define startTime in the correct scope
    local function progressCallback(processed, total, currentPhoto)
      local success, err = pcall(function()
        if progress:isCanceled() then
          return -- Let the bridge handle cancellation
        end
        
        local progressPercent = processed / total
        progress:setPortionComplete(progressPercent)
        
        -- Calculate time estimates with safe arithmetic
        local currentTime = os.time()
        local elapsed = currentTime - startTime
        local rate = processed > 0 and elapsed / processed or 0
        local remaining = processed < total and (total - processed) * rate or 0
        local remainingMin = math.floor(remaining / 60)
        local remainingSec = remaining % 60
        
        local timeStr = remaining > 0 and 
          string.format(" (%dm %ds remaining)", remainingMin, remainingSec) or ""
        
        if currentPhoto and currentPhoto ~= '' then
          progress:setCaption('Processing: ' .. currentPhoto .. timeStr)
        else
          progress:setCaption('Analyzing ' .. processed .. ' of ' .. total .. ' photos...' .. timeStr)
        end
        
        Log.info('Progress callback: ' .. processed .. '/' .. total .. ' (' .. 
                 string.format("%.1f%%", progressPercent * 100) .. ') - ' .. (currentPhoto or 'unknown'))
      end)
      
      if not success then
        Log.error('Progress callback error: ' .. tostring(err))
      end
    end
    
    local results = Bridge.run(photos, progressCallback)
    local prefs = LrPrefs.prefsForPlugin()
    
    -- Metadata is now applied in real-time by SmartBridge, so we just need to handle
    -- any photos that might not have been processed in real-time (fallback)
    catalog:withWriteAccessDo('WAI final metadata check', function()
      for i, photo in ipairs(photos) do
        local photoPath = photo:getRawMetadata('path')
        if photoPath and results[photoPath] then
          -- Check if this photo was already processed with metadata
          local processed = photo:getPropertyForPlugin(_PLUGIN, 'wai_processed')
          if processed ~= 'true' then
            Log.info('Applying fallback metadata for: ' .. LrPathUtils.leafName(photoPath))
            -- Apply metadata as fallback (this should rarely be needed now)
            local d = results[photoPath] or {}
            
            local function set(id,v) 
              local value = tostring(v or '')
              if photo and photo.setPropertyForPlugin then
                photo:setPropertyForPlugin(_PLUGIN, id, value)
              end
            end
            
            local species = d.detected_species or 'Unknown'
            local speciesConf = d.species_confidence or 0
            local quality = d.quality or -1
            local rating = d.rating or 0
            local sceneCount = d.scene_count or 1
            
            set('wai_detectedSpecies', species ~= 'Unknown' and species or 'No Bird Detected')
            set('wai_speciesConfidence', speciesConf > 0 and tostring(speciesConf) or 'N/A')
            set('wai_quality', quality >= 0 and tostring(quality) or 'N/A')
            set('wai_rating', rating > 0 and tostring(rating) or 'Not Rated')
            set('wai_sceneCount', tostring(sceneCount))
            set('wai_featureSimilarity', d.feature_similarity and tostring(d.feature_similarity) or 'N/A')
            set('wai_featureConfidence', d.feature_confidence and tostring(d.feature_confidence) or 'N/A')
            set('wai_colorSimilarity', d.color_similarity and tostring(d.color_similarity) or 'N/A')
            set('wai_colorConfidence', d.color_confidence and tostring(d.color_confidence) or 'N/A')
            set('wai_jsonPath', d.json_path or '')
            set('wai_processed', 'true')
            
            Log.info('Applied fallback metadata for ' .. LrPathUtils.leafName(photoPath))
          else
            Log.info('Photo already processed with real-time metadata: ' .. LrPathUtils.leafName(photoPath))
          end
        end
        progress:setPortionComplete(i, #photos)
      end
    end, {timeout=60})
    if prefs.enableStacking then
      catalog:withWriteAccessDo('WAI Stack', function() require('QualityStack') end,{timeout=120})
    end
    progress:done()
    Log.info('Analysis completed successfully')
    Log.leave(clk,'AnalyzeMenu')
  end)
end)
