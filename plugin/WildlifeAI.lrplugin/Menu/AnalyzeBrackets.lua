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

-- Validate preferences first (before any photo operations)
local isValid, errors = BracketStacking.validatePreferences(prefs)
if not isValid then
  LrDialogs.message('Configuration Error',
    'Please fix the following configuration issues:\n\n' .. table.concat(errors, '\n'), 'error')
  return
end

-- Get basic photo count outside of task (for early validation)
local catalog = LrApplication.activeCatalog()
local photoCount = 0

catalog:withReadAccessDo(function()
  local photos = catalog:getTargetPhotos()
  photoCount = #photos
end)

if photoCount == 0 then
  LrDialogs.message('No Photos Selected', 'Please select photos to analyze for bracket patterns.')
  return
end

if photoCount == 1 then
  LrDialogs.message('Single Photo Selected', 'Please select multiple photos to analyze for bracket patterns.')
  return
end

Log.info("=== EXTRACTING ALL METADATA IN SYNCHRONOUS CONTEXT ===")
Log.info("Photo count: " .. photoCount)
Log.info("CRITICAL: All metadata extraction MUST happen in sync context before async task")

-- CRITICAL FIX: Extract ALL metadata in synchronous context
local photos = {}
local photoData = {}

-- Get photos and extract metadata in single synchronous context
catalog:withReadAccessDo(function()
  Log.info("=== SYNCHRONOUS METADATA EXTRACTION ===")
  Log.info("Context: withReadAccessDo - completely synchronous, no yielding issues")
  
  photos = catalog:getTargetPhotos()
  Log.info(string.format("Retrieved %d target photos from catalog", #photos))
  
  -- Extract metadata using the safe method IN SYNCHRONOUS CONTEXT
  photoData, _ = BracketStacking.extractPhotoMetadataSafe(photos)
  
  Log.info(string.format("✓ Extracted metadata for %d photos in synchronous context", #photoData))
end)

-- Validate metadata extraction
if #photoData == 0 then
  LrDialogs.message('Metadata Extraction Failed', 
    'Failed to extract photo metadata. Please check the logs for details.', 'error')
  return
end

Log.info("=== STARTING ASYNC TASK WITH PRE-EXTRACTED METADATA ===")
Log.info("All metadata extracted - async task will use cached data only")

-- ASYNC TASK WITH PRE-EXTRACTED METADATA (NO METADATA CALLS)
LrTasks.startAsyncTask(function()

  local success, err = pcall(function()
    Log.info("=== ASYNC TASK STARTED ===")
    Log.info("Context: Async task - using PRE-EXTRACTED metadata (no yielding)")
    Log.info(string.format("Working with %d cached metadata records", #photoData))

    -- STEP 1: INTELLIGENT BRACKET DETECTION USING CACHED METADATA
    Log.info("=== STEP 1: INTELLIGENT BRACKET DETECTION ===")
    Log.info("Using cached metadata - NO photo object access")

    local detectionResults = BracketStacking.detectBracketsFromMetadata(photoData)
    
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
    
    -- STEP 2: MAP METADATA BACK TO PHOTO OBJECTS FOR STACKING
    Log.info("=== STEP 2: MAPPING METADATA TO PHOTOS FOR STACKING ===")
    Log.info("Enhancing detection results with original photo objects")
    
    -- Enhance detection results with original photo objects
    for _, sequence in ipairs(detectionResults.sequences) do
      for _, bracket in ipairs(sequence.brackets) do
        for _, photoMetadata in ipairs(bracket.photos) do
          -- Map back to original photo using photoIndex
          if photoMetadata.photoIndex and photos[photoMetadata.photoIndex] then
            photoMetadata.photo = photos[photoMetadata.photoIndex]
            Log.debug(string.format("Mapped metadata record to photo object (index %d)", 
              photoMetadata.photoIndex))
          else
            Log.warning(string.format("Could not map metadata record to photo object (index %s)",
              tostring(photoMetadata.photoIndex)))
          end
        end
      end
    end
    
    -- Show preview if enabled, otherwise proceed directly to stacking
    if prefs.showBracketPreview then
      LrFunctionContext.callWithContext('WildlifeAI_BracketPreview', function(context)
        local result = BracketPreview.showPreview(context, detectionResults)
        
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
    Log.error("Async task error: " .. tostring(err))
    LrDialogs.message('Bracket Analysis Error', 'An error occurred during bracket analysis: ' .. tostring(err), 'error')
  end
end)
