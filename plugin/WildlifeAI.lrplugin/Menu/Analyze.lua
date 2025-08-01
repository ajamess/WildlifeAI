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
    
    -- POST-PROCESSING METADATA CALLBACK (WITH ASYNC WRITE ACCESS)
    local function metadataCallback(resultsMap, photosMap)
      Log.info('POST-PROCESSING: Starting metadata application in async task with write access')
      local prefs = LrPrefs.prefsForPlugin()
      
      local success, err = pcall(function()
        catalog:withWriteAccessDo('WAI Async Post-Processing', function()
          local processedCount = 0
          local totalCount = 0
          for _ in pairs(resultsMap) do totalCount = totalCount + 1 end
          
          Log.info('POST-PROCESSING: Processing ' .. totalCount .. ' photos with async write access')
        
        for photoPath, resultData in pairs(resultsMap) do
          local photo = photosMap[photoPath]
          if photo then
            processedCount = processedCount + 1
            Log.info('POST-PROCESSING: Applying metadata DIRECTLY for: ' .. LrPathUtils.leafName(photoPath) .. ' (' .. processedCount .. '/' .. totalCount .. ')')
            
            -- Helper function for safe property setting
            local function set(id, v) 
              local value = tostring(v or '')
              if photo and photo.setPropertyForPlugin then
                photo:setPropertyForPlugin(_PLUGIN, id, value)
              else
                Log.error('Invalid photo object for property setting: ' .. tostring(photo))
              end
            end
            
            -- Helper function for formatting with 2 decimal precision
            local function formatPrecision(value, is0to100Scale)
              if not value or value < 0 then return 'N/A' end
              if is0to100Scale and value >= 0 and value <= 100 then
                return string.format('%.2f', value)
              else
                return tostring(value)
              end
            end
            
            -- Extract data
            local species = resultData.detected_species or 'Unknown'
            local speciesConf = resultData.species_confidence or 0
            local quality = resultData.quality or -1
            local rating = resultData.rating or 0
            local sceneCount = resultData.scene_count or 1
            
            -- Set plugin properties
            set('wai_detectedSpecies', species ~= 'Unknown' and species or 'No Bird Detected')
            set('wai_speciesConfidence', formatPrecision(speciesConf, true))
            set('wai_quality', formatPrecision(quality, true))
            set('wai_rating', rating > 0 and tostring(rating) or 'Not Rated')
            set('wai_sceneCount', tostring(sceneCount))
            set('wai_featureSimilarity', formatPrecision(resultData.feature_similarity, true))
            set('wai_featureConfidence', formatPrecision(resultData.feature_confidence, true))
            set('wai_colorSimilarity', formatPrecision(resultData.color_similarity, true))
            set('wai_colorConfidence', formatPrecision(resultData.color_confidence, true))
            set('wai_jsonPath', resultData.json_path or '')
            set('wai_processed', 'true')
            
            -- Apply visual metadata (ratings, flags, colors, IPTC, XMP)
            local ratingValue = rating
            local qualityValue = quality >= 0 and quality or 0
            
            -- Set star rating
            if prefs.enableRating and photo.setRawMetadata then
              local success, err = pcall(function()
                photo:setRawMetadata('rating', ratingValue)
              end)
              if success then
                Log.info('POST-PROCESSING: Set rating: ' .. ratingValue .. ' stars for ' .. LrPathUtils.leafName(photoPath))
              else
                Log.error('POST-PROCESSING: Failed to set rating: ' .. tostring(err))
              end
            end
            
            -- Apply flags
            local qualityMode = prefs.qualityMode or 'rating'
            
            if prefs.enableRejection and photo.setRawMetadata then
              local shouldReject = false
              if qualityMode == 'quality' then
                local threshold = prefs.rejectionQualityThreshold or 20
                shouldReject = qualityValue <= threshold
              else
                local threshold = prefs.rejectionThreshold or 2
                shouldReject = ratingValue <= threshold
              end
              
              local success, err = pcall(function()
                photo:setRawMetadata('pickStatus', shouldReject and -1 or 0)
              end)
              if success and shouldReject then
                Log.info('POST-PROCESSING: Marked as rejected: ' .. LrPathUtils.leafName(photoPath))
              elseif not success then
                Log.error('POST-PROCESSING: Failed to set rejection flag: ' .. tostring(err))
              end
            end
            
            if prefs.enablePicks and photo.setRawMetadata then
              local shouldPick = false
              if qualityMode == 'quality' then
                local threshold = prefs.picksQualityThreshold or 80
                shouldPick = qualityValue >= threshold
              else
                local threshold = prefs.picksThreshold or 4
                shouldPick = ratingValue >= threshold
              end
              
              local success, err = pcall(function()
                photo:setRawMetadata('pickStatus', shouldPick and 1 or 0)
              end)
              if success and shouldPick then
                Log.info('POST-PROCESSING: Marked as pick: ' .. LrPathUtils.leafName(photoPath))
              elseif not success then
                Log.error('POST-PROCESSING: Failed to set pick flag: ' .. tostring(err))
              end
            end
            
            -- Apply color labels
            if prefs.enableColorLabels and photo.setRawMetadata then
              local colorLabel = nil
              local colorLabelMode = prefs.colorLabelMode or 'rating'
              
              if colorLabelMode == 'quality' then
                -- Quality range-based color mapping
                local ranges = {}
                if prefs.colorRangeRedEnabled then
                  table.insert(ranges, { color = 'red', min = tonumber(prefs.colorRangeRedMin) or 0, max = tonumber(prefs.colorRangeRedMax) or 20 })
                end
                if prefs.colorRangeYellowEnabled then
                  table.insert(ranges, { color = 'yellow', min = tonumber(prefs.colorRangeYellowMin) or 21, max = tonumber(prefs.colorRangeYellowMax) or 40 })
                end
                if prefs.colorRangeGreenEnabled then
                  table.insert(ranges, { color = 'green', min = tonumber(prefs.colorRangeGreenMin) or 41, max = tonumber(prefs.colorRangeGreenMax) or 60 })
                end
                if prefs.colorRangeBlueEnabled then
                  table.insert(ranges, { color = 'blue', min = tonumber(prefs.colorRangeBlueMin) or 61, max = tonumber(prefs.colorRangeBlueMax) or 80 })
                end
                if prefs.colorRangePurpleEnabled then
                  table.insert(ranges, { color = 'purple', min = tonumber(prefs.colorRangePurpleMin) or 81, max = tonumber(prefs.colorRangePurpleMax) or 100 })
                end
                
                for _, colorRange in ipairs(ranges) do
                  if qualityValue >= colorRange.min and qualityValue <= colorRange.max then
                    colorLabel = colorRange.color
                    break
                  end
                end
              else
                -- Rating-based color mapping
                if ratingValue == 0 then colorLabel = prefs.colorLabel0
                elseif ratingValue == 1 then colorLabel = prefs.colorLabel1
                elseif ratingValue == 2 then colorLabel = prefs.colorLabel2
                elseif ratingValue == 3 then colorLabel = prefs.colorLabel3
                elseif ratingValue == 4 then colorLabel = prefs.colorLabel4
                elseif ratingValue == 5 then colorLabel = prefs.colorLabel5
                end
              end
              
              if colorLabel and colorLabel ~= 'none' then
                local success, err = pcall(function()
                  photo:setRawMetadata('colorNameForLabel', colorLabel)
                end)
                if success then
                  Log.info('POST-PROCESSING: Set color label: ' .. colorLabel .. ' for ' .. LrPathUtils.leafName(photoPath))
                else
                  Log.error('POST-PROCESSING: Failed to set color label: ' .. tostring(err))
                end
              end
            end
            
            -- Apply IPTC metadata
            if prefs.enableIptcMirror and prefs.iptcField and prefs.iptcField ~= 'none' and photo.setRawMetadata then
              local elements = {}
              
              if prefs.includeQuality and quality >= 0 then
                table.insert(elements, 'Qu:' .. formatPrecision(quality, true))
              end
              if prefs.includeRating and rating > 0 then
                table.insert(elements, 'Ra:' .. tostring(rating))
              end
              if prefs.includeSpeciesConfidence and speciesConf >= 0 then
                table.insert(elements, 'Co:' .. formatPrecision(speciesConf, true))
              end
              if prefs.includeDetectedSpecies and species and species ~= 'Unknown' and species ~= '' then
                table.insert(elements, 'Sp:' .. species)
              end
              if prefs.includeSceneCount and sceneCount > 0 then
                table.insert(elements, 'Sc:' .. tostring(sceneCount))
              end
              
              if #elements > 0 then
                local iptcValue = 'WAI ' .. table.concat(elements, ' ')
                local success, err = pcall(function()
                  photo:setRawMetadata(prefs.iptcField, iptcValue)
                end)
                if success then
                  Log.info('POST-PROCESSING: Set IPTC ' .. prefs.iptcField .. ': ' .. iptcValue .. ' for ' .. LrPathUtils.leafName(photoPath))
                else
                  Log.error('POST-PROCESSING: Failed to set IPTC field: ' .. tostring(err))
                end
              end
            end
            
            -- Apply keywords
            if prefs.enableKeywording then
              local keywordSuccess = KW.applyKeywords(photo, resultData, prefs, catalog)
              if keywordSuccess then
                Log.info('POST-PROCESSING: Applied keywords for: ' .. LrPathUtils.leafName(photoPath))
              else
                Log.warning('POST-PROCESSING: Failed to apply keywords for: ' .. LrPathUtils.leafName(photoPath))
              end
            end
            
            -- Save XMP if enabled
            if prefs.writeXMP then
              local success, err = pcall(function()
                if photo.saveMetadata then
                  photo:saveMetadata()
                end
              end)
              if success then
                Log.info('POST-PROCESSING: Saved XMP metadata for: ' .. LrPathUtils.leafName(photoPath))
              else
                Log.error('POST-PROCESSING: Failed to save XMP metadata: ' .. tostring(err))
              end
            end
            
              Log.info('POST-PROCESSING: Completed ALL metadata for: ' .. LrPathUtils.leafName(photoPath))
            end
          end
          
        Log.info('POST-PROCESSING: Completed processing ' .. processedCount .. ' photos')
        end, {timeout=120})
      end)
      
      if not success then
        Log.error('POST-PROCESSING: Metadata application failed: ' .. tostring(err))
      else
        Log.info('POST-PROCESSING: Metadata application completed successfully for all photos')
      end
    end
    
    -- Call SmartBridge WITHOUT metadata callback to avoid yielding context issues
    local results = Bridge.run(photos, progressCallback, false, nil)
    local prefs = LrPrefs.prefsForPlugin()
    
    -- APPLY METADATA IN COMPLETELY SEPARATE ASYNC TASK (proper yielding context)
    if next(results) then
      Log.info('DEFERRED METADATA: Scheduling metadata application in separate async task')
      
      -- Create photosMap from the photos array
      local photosMapForCallback = {}
      for _, photo in ipairs(photos) do
        local photoPath = photo:getRawMetadata('path')
        photosMapForCallback[photoPath] = photo
      end
      
      -- Run metadata callback in completely separate async task to ensure proper yielding context
      LrTasks.startAsyncTask(function()
        Log.info('ASYNC METADATA: Starting metadata application in separate async task')
        metadataCallback(results, photosMapForCallback)
      end)
    else
      Log.info('DEFERRED METADATA: No results to process')
    end
    if prefs.enableStacking then
      catalog:withWriteAccessDo('WAI Stack', function() require('QualityStack') end,{timeout=120})
    end
    progress:done()
    Log.info('Analysis completed successfully')
    Log.leave(clk,'AnalyzeMenu')
  end)
end)
