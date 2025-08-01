-- WildlifeAI Read from IPTC Menu Item
local LrTasks = import 'LrTasks'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrProgressScope = import 'LrProgressScope'
local LrPrefs = import 'LrPrefs'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrPathUtils = import 'LrPathUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local SmartBridge = dofile( LrPathUtils.child(_PLUGIN.path, 'SmartBridge.lua') )

-- Function to parse WAI metadata from IPTC string
local function parseWaiMetadata(iptcValue)
  if not iptcValue or not string.match(iptcValue, '^WAI ') then
    return nil
  end
  
  -- Remove "WAI " prefix and parse elements
  local content = string.sub(iptcValue, 5)
  local metadata = {}
  
  -- Parse each element with 2-character qualifiers
  for element in string.gmatch(content, '(%S+)') do
    local qualifier, value = string.match(element, '^([A-Za-z][A-Za-z]):(.+)$')
    if qualifier and value then
      qualifier = string.upper(qualifier)
      
      -- Map qualifiers to metadata fields
      if qualifier == 'QU' then
        metadata.quality = tonumber(value) or -1
      elseif qualifier == 'RA' then
        metadata.rating = tonumber(value) or 0
      elseif qualifier == 'CO' then
        metadata.species_confidence = tonumber(value) or 0
      elseif qualifier == 'SP' then
        metadata.detected_species = value
      elseif qualifier == 'SC' then
        metadata.scene_count = tonumber(value) or 1
      elseif qualifier == 'FS' then
        metadata.feature_similarity = tonumber(value) or -1
      elseif qualifier == 'FC' then
        metadata.feature_confidence = tonumber(value) or -1
      elseif qualifier == 'CS' then
        metadata.color_similarity = tonumber(value) or -1
      elseif qualifier == 'CC' then
        metadata.color_confidence = tonumber(value) or -1
      elseif qualifier == 'PT' then
        metadata.processing_time = tonumber(value) or 0
      end
    end
  end
  
  return metadata
end

-- Function to create IPTC field selection dialog
local function showIptcFieldDialog()
  local f = LrView.osFactory()
  local prefs = LrPrefs.prefsForPlugin()
  
  -- Use current read field or default
  local currentField = prefs.iptcReadField or 'jobIdentifier'
  
  local props = LrBinding.makePropertyTable()
  props.selectedField = currentField
  
  local iptcFieldItems = {
    { title = 'Job Identifier', value = 'jobIdentifier' },
    { title = 'Instructions', value = 'instructions' },
    { title = 'Caption/Description', value = 'caption' },
    { title = 'Keywords', value = 'keywords' },
    { title = 'Title', value = 'title' },
    { title = 'Headline', value = 'headline' },
    { title = 'Creator', value = 'creator' },
    { title = 'Copyright', value = 'copyright' },
    { title = 'Source', value = 'source' },
    { title = 'Category', value = 'intellectualGenre' },
    { title = 'Supplemental Categories', value = 'scene' }
  }
  
  local c = f:column {
    bind_to_object = props,
    spacing = f:control_spacing(),
    
    f:static_text {
      title = 'Read WildlifeAI Metadata from IPTC Tags',
      font = '<system/bold>',
      fill_horizontal = 1
    },
    
    f:spacer { height = 10 },
    
    f:static_text {
      title = 'Select the IPTC field to read WildlifeAI metadata from:',
      font = '<system>'
    },
    
    f:spacer { height = 5 },
    
    f:row {
      f:static_text {
        title = 'IPTC Field:',
        width = 100,
        alignment = 'right'
      },
      f:popup_menu {
        value = LrView.bind('selectedField'),
        items = iptcFieldItems,
        immediate = true,
        width = 200
      }
    },
    
    f:spacer { height = 10 },
    
    f:static_text {
      title = 'This will read structured metadata (WAI Qu:85.23 Ra:4 Co:92.15 Sp:Robin...)',
      font = '<system/small>'
    },
    
    f:static_text {
      title = 'from the selected field and populate WildlifeAI plugin metadata.',
      font = '<system/small>'
    },
    
    f:spacer { height = 5 },
    
    f:static_text {
      title = 'Current configuration will be applied for labeling, flagging, and rating.',
      font = '<system/small>'
    }
  }
  
  local result = LrDialogs.presentModalDialog {
    title = 'Read from IPTC',
    contents = c,
    actionVerb = 'Read Metadata',
    cancelVerb = 'Cancel'
  }
  
  if result == 'ok' then
    -- Save the selected field for future use
    prefs.iptcReadField = props.selectedField
    return props.selectedField
  end
  
  return nil
end

-- Main function to read metadata from IPTC
local function readFromIptc()
  local clk = Log.enter('ReadFromIptc.readFromIptc')
  
  local catalog = LrApplication.activeCatalog()
  local targetPhotos = catalog:getTargetPhotos()
  
  if #targetPhotos == 0 then
    LrDialogs.message('WildlifeAI', 'Please select at least one photo to read metadata from.', 'info')
    Log.leave(clk, 'ReadFromIptc.readFromIptc')
    return
  end
  
  -- Show field selection dialog
  local iptcField = showIptcFieldDialog()
  if not iptcField then
    Log.info('User cancelled IPTC field selection')
    Log.leave(clk, 'ReadFromIptc.readFromIptc')
    return
  end
  
  Log.info('Reading WildlifeAI metadata from IPTC field: ' .. iptcField)
  Log.info('Processing ' .. #targetPhotos .. ' selected photos')
  
  LrTasks.startAsyncTask(function()
    local progressScope = LrProgressScope {
      title = 'Reading WildlifeAI Metadata from IPTC'
    }
    
    local successCount = 0
    local errorCount = 0
    local results = {}
    local prefs = LrPrefs.prefsForPlugin()
    
    for i, photo in ipairs(targetPhotos) do
      local photoPath = photo:getRawMetadata('path')
      local filename = LrPathUtils.leafName(photoPath)
      
      progressScope:setPortionComplete(i - 1, #targetPhotos)
      progressScope:setCaption('Reading: ' .. filename)
      
      if progressScope:isCanceled() then
        Log.info('User cancelled IPTC reading operation')
        break
      end
      
      local success, err = pcall(function()
        -- Read the IPTC field
        local iptcValue = photo:getRawMetadata(iptcField)
        
        if iptcValue and string.match(iptcValue, '^WAI ') then
          -- Parse the metadata
          local metadata = parseWaiMetadata(iptcValue)
          
          if metadata then
            Log.info('Successfully parsed WAI metadata for: ' .. filename)
            Log.info('  Content: ' .. iptcValue)
            
            -- Store in results format expected by applyMetadataToPhoto
            results[photoPath] = metadata
            
            catalog:withWriteAccessDo('WAI IPTC metadata import', function()
              -- Set plugin metadata with proper formatting
              local function set(id, v) 
                local value = tostring(v or '')
                photo:setPropertyForPlugin(_PLUGIN, id, value)
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
              
              -- Set all available metadata
              local species = metadata.detected_species or 'Unknown'
              local speciesConf = metadata.species_confidence or 0
              local quality = metadata.quality or -1
              local rating = metadata.rating or 0
              local sceneCount = metadata.scene_count or 1
              
              set('wai_detectedSpecies', species ~= 'Unknown' and species or 'No Bird Detected')
              set('wai_speciesConfidence', formatPrecision(speciesConf, true))
              set('wai_quality', formatPrecision(quality, true))
              set('wai_rating', rating > 0 and tostring(rating) or 'Not Rated')
              set('wai_sceneCount', tostring(sceneCount))
              set('wai_featureSimilarity', formatPrecision(metadata.feature_similarity, true))
              set('wai_featureConfidence', formatPrecision(metadata.feature_confidence, true))
              set('wai_colorSimilarity', formatPrecision(metadata.color_similarity, true))
              set('wai_colorConfidence', formatPrecision(metadata.color_confidence, true))
              set('wai_processed', 'true')
              
              -- Apply current configuration settings for rating, flagging, color labeling
              local ratingValue = rating
              local qualityValue = quality >= 0 and quality or 0
              
              -- Set star rating if enabled
              if prefs.enableRating and photo.setRawMetadata then
                photo:setRawMetadata('rating', ratingValue)
              end
              
              -- Apply rejection/picks logic
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
                photo:setRawMetadata('pickStatus', shouldReject and -1 or 0)
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
                photo:setRawMetadata('pickStatus', shouldPick and 1 or 0)
              end
              
              -- Apply color labeling
              if prefs.enableColorLabels and photo.setRawMetadata then
                local colorLabel = nil
                local colorLabelMode = prefs.colorLabelMode or 'rating'
                
                if colorLabelMode == 'quality' then
                  -- Quality range-based color mapping
                  local function parseRange(rangeStr)
                    if not rangeStr or rangeStr == '' then return nil end
                    local min, max = string.match(rangeStr, '^(%d+)%-(%d+)$')
                    if min and max then
                      min, max = tonumber(min), tonumber(max)
                      if min and max and min >= 0 and max <= 100 and min <= max then
                        return { min = min, max = max }
                      end
                    end
                    return nil
                  end
                  
                  local ranges = {
                    { color = 'red', range = parseRange(prefs.colorRangeRed or '') },
                    { color = 'yellow', range = parseRange(prefs.colorRangeYellow or '') },
                    { color = 'green', range = parseRange(prefs.colorRangeGreen or '') },
                    { color = 'blue', range = parseRange(prefs.colorRangeBlue or '') },
                    { color = 'purple', range = parseRange(prefs.colorRangePurple or '') },
                    { color = 'none', range = parseRange(prefs.colorRangeNone or '') }
                  }
                  
                  for _, colorRange in ipairs(ranges) do
                    if colorRange.range and qualityValue >= colorRange.range.min and qualityValue <= colorRange.range.max then
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
                  photo:setRawMetadata('colorNameForLabel', colorLabel)
                end
              end
              
            end, {timeout=30})
            
            successCount = successCount + 1
          else
            Log.warning('Failed to parse WAI metadata for: ' .. filename)
            errorCount = errorCount + 1
          end
        else
          Log.info('No WAI metadata found in ' .. iptcField .. ' for: ' .. filename)
          errorCount = errorCount + 1
        end
      end)
      
      if not success then
        Log.error('Error processing ' .. filename .. ': ' .. tostring(err))
        errorCount = errorCount + 1
      end
    end
    
    progressScope:done()
    
    -- Show summary
    local message = string.format(
      'IPTC Metadata Reading Complete:\n\n' ..
      'Successfully populated: %d photos\n' ..
      'No WAI metadata found: %d photos\n\n' ..
      'Read from IPTC field: %s\n' ..
      'Current configuration applied for labeling, flagging, and rating.',
      successCount, errorCount, iptcField
    )
    
    LrDialogs.message('WildlifeAI', message, 'info')
    
    Log.info('IPTC reading completed - Success: ' .. successCount .. ', Errors: ' .. errorCount)
    Log.leave(clk, 'ReadFromIptc.readFromIptc')
  end)
end

-- Execute the function directly
readFromIptc()
