local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrView = import 'LrView'
local LrFileUtils = import 'LrFileUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local Bridge = dofile(LrPathUtils.child(_PLUGIN.path, 'SmartBridge.lua'))

-- Function to delete result files for photos
local function deleteResultFiles(photos)
  for _, photo in ipairs(photos) do
    local photoPath = photo:getRawMetadata('path')
    if photoPath then
      local photoDir = LrPathUtils.parent(photoPath)
      local outputDir = LrPathUtils.child(photoDir, '.wildlifeai')
      local filename = LrPathUtils.leafName(photoPath)
      local resultFile = LrPathUtils.child(outputDir, filename .. '.json')
      
      if LrFileUtils.exists(resultFile) then
        local success = pcall(LrFileUtils.delete, resultFile)
        if success then
          Log.info('Deleted result file for: ' .. filename)
        else
          Log.warning('Failed to delete result file for: ' .. filename)
        end
      end
    end
  end
end

LrTasks.startAsyncTask(function()
  local clk = Log.enter('ClearProcessingStateMenu')
  
  LrFunctionContext.callWithContext('WAI_ClearProcessingState', function(context)
    local catalog = LrApplication.activeCatalog()
    local photos = catalog:getTargetPhotos()
    
    if #photos == 0 then 
      LrDialogs.message('WildlifeAI','No photos selected')
      Log.leave(clk,'ClearProcessingStateMenu')
      return 
    end
    
    -- Create a proper dialog with radio button selection
    local f = LrView.osFactory()
    local LrBinding = import 'LrBinding'
    local props = LrBinding.makePropertyTable(context)
    props.clearType = 'processing' -- Default selection
    
    local choice = LrDialogs.presentModalDialog({
      title = "Clear WildlifeAI Data",
      contents = f:column {
        bind_to_object = props,
        spacing = f:control_spacing(),
        
        f:static_text {
          title = "Choose what to clear for " .. #photos .. " selected photos:",
          fill_horizontal = 1,
        },
        f:spacer { height = 10 },
        
        f:radio_button {
          title = "Processing State Only",
          value = LrView.bind('clearType'),
          checked_value = 'processing',
        },
        f:static_text {
          title = "   Clears processing flags (forces reanalysis)",
          font = '<system/small>',
          fill_horizontal = 1,
        },
        f:spacer { height = 5 },
        
        f:radio_button {
          title = "Plugin Metadata Only", 
          value = LrView.bind('clearType'),
          checked_value = 'plugin',
        },
        f:static_text {
          title = "   Clears WildlifeAI data but keeps ratings/flags",
          font = '<system/small>',
          fill_horizontal = 1,
        },
        f:spacer { height = 5 },
        
        f:radio_button {
          title = "All Metadata (DESTRUCTIVE)",
          value = LrView.bind('clearType'),
          checked_value = 'all',
        },
        f:static_text {
          title = "   Removes ALL WildlifeAI data, ratings, flags, and labels",
          font = '<system/small>',
          fill_horizontal = 1,
        },
      },
      actionVerb = "Clear Selected",
      cancelVerb = "Cancel",
    })
    
    if choice == 'ok' then
      -- Check which radio button was selected
      if props.clearType == 'processing' then
        -- Clear processing state only
        catalog:withWriteAccessDo('WAI Clear Processing State', function()
          Bridge.clearProcessingState(photos)
          for _, photo in ipairs(photos) do
            photo:setPropertyForPlugin(_PLUGIN, 'wai_processed', 'false')
          end
        end)
        
        LrDialogs.message('WildlifeAI', 'Processing state cleared for ' .. #photos .. ' photos.')
        Log.info('Cleared processing state for ' .. #photos .. ' photos')
        
      elseif props.clearType == 'plugin' then
        -- Clear plugin metadata only (keep Lightroom ratings/flags)
        local confirmPlugin = LrDialogs.confirm('Clear Plugin Metadata Only', 
          'This will clear WildlifeAI plugin data from ' .. #photos .. ' photos including:\n\n• Species detection results\n• Quality scores\n• Scene counts\n• Processing flags\n• Result files\n\nThis will NOT clear star ratings, pick/reject flags, or color labels.\n\nContinue?',
          'Clear Plugin Data', 'Cancel')
        
        if confirmPlugin == 'ok' then
          catalog:withWriteAccessDo('WAI Clear Plugin Metadata', function()
            for _, photo in ipairs(photos) do
              -- Clear only plugin metadata properties
              local function clear(id) 
                photo:setPropertyForPlugin(_PLUGIN, id, '')
              end
              
              clear('wai_detectedSpecies')
              clear('wai_speciesConfidence')
              clear('wai_quality')
              clear('wai_rating')
              clear('wai_sceneCount')
              clear('wai_featureSimilarity')
              clear('wai_featureConfidence')
              clear('wai_colorSimilarity')
              clear('wai_colorConfidence')
              clear('wai_jsonPath')
              clear('wai_processed')
            end
            
            -- Delete result files to force fresh processing
            deleteResultFiles(photos)
            -- Also clear processing state files
            Bridge.clearProcessingState(photos)
          end)
          
          LrDialogs.message('WildlifeAI', 'Plugin metadata cleared for ' .. #photos .. ' photos.')
          Log.info('Cleared plugin metadata for ' .. #photos .. ' photos')
        end
        
      elseif props.clearType == 'all' then
        -- Clear all metadata
        local confirmAll = LrDialogs.confirm('Clear ALL Metadata', 
          'This will permanently remove ALL WildlifeAI data from ' .. #photos .. ' photos including:\n\n• Species detection results\n• Quality scores and ratings\n• Star ratings and pick/reject flags\n• Color labels\n• All processing data\n\nThis action cannot be undone!\n\nAre you absolutely sure?',
          'Clear Everything', 'Cancel')
        
        if confirmAll == 'ok' then
          catalog:withWriteAccessDo('WAI Clear All Metadata', function()
            for _, photo in ipairs(photos) do
              -- Clear all plugin metadata properties
              local function clear(id) 
                photo:setPropertyForPlugin(_PLUGIN, id, '')
              end
              
              clear('wai_detectedSpecies')
              clear('wai_speciesConfidence')
              clear('wai_quality')
              clear('wai_rating')
              clear('wai_sceneCount')
              clear('wai_featureSimilarity')
              clear('wai_featureConfidence')
              clear('wai_colorSimilarity')
              clear('wai_colorConfidence')
              clear('wai_jsonPath')
              clear('wai_processed')
              
              -- Clear Lightroom built-in properties that may have been set
              local success, err = pcall(function()
                photo:setRawMetadata('rating', nil)
                photo:setRawMetadata('pickStatus', 0)  -- 0 = unflagged
                photo:setRawMetadata('colorNameForLabel', '')
                photo:setRawMetadata('jobIdentifier', '')
              end)
              
              if not success then
                Log.warning('Failed to clear some Lightroom metadata for ' .. (photo:getFormattedMetadata('fileName') or 'unknown') .. ': ' .. tostring(err))
              end
            end
            
            -- Delete result files to force fresh processing
            deleteResultFiles(photos)
            -- Also clear processing state files
            Bridge.clearProcessingState(photos)
          end)
          
          LrDialogs.message('WildlifeAI', 'All metadata cleared for ' .. #photos .. ' photos.')
          Log.info('Cleared all metadata for ' .. #photos .. ' photos')
        end
      end
    end
  end)
  
  Log.leave(clk,'ClearProcessingStateMenu')
end)
