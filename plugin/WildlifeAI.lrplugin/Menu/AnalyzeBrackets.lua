-- WildlifeAI Analyze Brackets Menu Item
-- Analyzes selected photos for bracket patterns and shows preview

local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrProgressScope = import 'LrProgressScope'
local LrPrefs = import 'LrPrefs'

local BracketStacking = dofile( LrPathUtils.child(_PLUGIN.path, 'BracketStacking.lua') )
local BracketPreview = dofile( LrPathUtils.child(_PLUGIN.path, 'BracketPreview.lua') )
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )

Log.info("=== ANALYZE BRACKETS MENU STARTED ===")
local prefs = LrPrefs.prefsForPlugin()

-- Check if bracket stacking is enabled
if not prefs.enableBracketStacking then
  LrDialogs.message('Bracket Stacking Disabled', 
    'Bracket stacking is not enabled. Please enable it in the configuration dialog first.', 'info')
  return
end

-- Get selected photos
local catalog = LrApplication.activeCatalog()
local photos = catalog:getTargetPhotos()

Log.info("Selected photos count: " .. #photos)

if #photos == 0 then
  Log.warning("No photos selected for bracket analysis")
  LrDialogs.message('No Photos Selected', 'Please select photos to analyze for bracket patterns.')
  return
end

if #photos == 1 then
  Log.warning("Only one photo selected for bracket analysis")
  LrDialogs.message('Single Photo Selected', 'Please select multiple photos to analyze for bracket patterns.')
  return
end

-- Validate preferences before proceeding
local isValid, errors = BracketStacking.validatePreferences(prefs)
if not isValid then
  LrDialogs.message('Configuration Error', 
    'Please fix the following configuration issues:\n\n' .. table.concat(errors, '\n'), 'error')
  return
end

-- CRITICAL: Extract ALL photo metadata OUTSIDE of any async task context
-- This is the only way to avoid yielding restrictions in Lightroom
Log.info("=== EXTRACTING PHOTO METADATA OUTSIDE ASYNC TASK ===")
local photoMetadata = BracketStacking.extractPhotoMetadata(photos)

if not photoMetadata or #photoMetadata == 0 then
  LrDialogs.message('Metadata Extraction Failed', 
    'Could not extract photo metadata. All photos failed to process.', 'error')
  return
end

Log.info("Successfully extracted metadata for " .. #photoMetadata .. " photos")

-- NOW start the async task with the pre-extracted metadata
LrTasks.startAsyncTask(function()
  
  local success, err = pcall(function()
    Log.info("Starting bracket detection with pcall protection")
    
    -- Analyze brackets with progress
    local progressScope = LrProgressScope {
      title = 'Analyzing Bracket Patterns',
      caption = 'Analyzing ' .. #photoMetadata .. ' photos for bracket patterns...'
    }
    
    Log.info("Progress scope created successfully")
    
    local progressCallback = function(progress, status)
      Log.debug(string.format("Progress callback called: %.2f - %s", progress or 0, status or ""))
      if progressScope then
        local success, err = pcall(function()
          progressScope:setPortionComplete(progress)
          if status then
            progressScope:setCaption(status)
          end
        end)
        if not success then
          Log.error("Progress scope update failed: " .. tostring(err))
        end
      end
    end
    
    Log.info("About to call BracketStacking.detectBrackets with pre-extracted metadata")
    local detectionResults = BracketStacking.detectBracketsFromMetadata(photoMetadata, progressCallback)
    Log.info("BracketStacking.detectBracketsFromMetadata completed successfully")
    
    if progressScope then
      progressScope:setPortionComplete(1.0)
      progressScope:setCaption('Analysis complete')
      progressScope:done()
    end
    
    -- Check if any brackets were detected
    if not detectionResults.sequences or #detectionResults.sequences == 0 then
      LrDialogs.message('No Brackets Detected', 
        'No bracket patterns were detected in the selected photos.\n\n' ..
        'This could mean:\n' ..
        '• The photos are not part of bracket sequences\n' ..
        '• The time intervals are too strict\n' ..
        '• The bracket size settings don\'t match your sequences\n\n' ..
        'Try adjusting the detection settings in the configuration dialog.', 'info')
      return
    end
    
    -- Show preview if enabled, otherwise proceed directly to stacking
    if prefs.showBracketPreview then
      LrFunctionContext.callWithContext('WildlifeAI_BracketPreview', function(context)
        local result = BracketPreview.showPreview(context, photos, detectionResults)
        
        if result == 'ok' then
          -- User chose to create stacks - run in separate async task with progress
          LrTasks.startAsyncTask(function()
            local stackProgressScope = LrProgressScope {
              title = 'Creating Bracket Stacks',
              caption = 'Creating stacks from detected brackets...'
            }
            
            local stackProgressCallback = function(progress, status)
              if stackProgressScope then
                stackProgressScope:setPortionComplete(progress)
                if status then
                  stackProgressScope:setCaption(status)
                end
              end
            end
            
            local stackSuccess, stackMessage = BracketStacking.createStacks(detectionResults, stackProgressCallback)
            
            if stackProgressScope then
              stackProgressScope:done()
            end
            
            if stackSuccess then
              LrDialogs.message('Stacking Complete', stackMessage, 'info')
            else
              LrDialogs.message('Stacking Failed', stackMessage, 'error')
            end
          end)
        elseif result == 'other' then
          -- User chose to adjust settings - open configuration dialog
          local ConfigDialog = dofile( LrPathUtils.child(_PLUGIN.path, 'UI/ConfigDialog.lua') )
          LrFunctionContext.callWithContext('WildlifeAI_Config', function(configContext)
            ConfigDialog(configContext)
          end)
        end
        -- If result == 'cancel', do nothing
      end)
    else
      -- Preview disabled, create stacks directly
      LrTasks.startAsyncTask(function()
        local stackProgressScope = LrProgressScope {
          title = 'Creating Bracket Stacks',
          caption = 'Creating stacks from detected brackets...'
        }
        
        local stackProgressCallback = function(progress, status)
          if stackProgressScope then
            stackProgressScope:setPortionComplete(progress)
            if status then
              stackProgressScope:setCaption(status)
            end
          end
        end
        
        local stackSuccess, stackMessage = BracketStacking.createStacks(detectionResults, stackProgressCallback)
        
        if stackProgressScope then
          stackProgressScope:done()
        end
        
        if stackSuccess then
          LrDialogs.message('Stacking Complete', stackMessage, 'info')
        else
          LrDialogs.message('Stacking Failed', stackMessage, 'error')
        end
      end)
    end
  end)
  
  if not success then
    LrDialogs.message('Bracket Analysis Error', 'An error occurred during bracket analysis: ' .. tostring(err), 'error')
  end
end)
