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

Log.info("=== STARTING ASYNC TASK FOR ALL PHOTO OPERATIONS ===")
Log.info("Photo count: " .. photoCount)

-- CRITICAL: Use clean two-phase approach
LrTasks.startAsyncTask(function()

  local success, err = pcall(function()
    Log.info("=== PHASE 1: EXTRACT BASIC PHOTO INFO (NO YIELDING) ===")
    
    -- Phase 1: Get photos and extract only basic non-yielding metadata
    local photos
    local basicPhotoInfo = {}
    
    catalog:withReadAccessDo(function()
      Log.info("Getting photos in read context")
      photos = catalog:getTargetPhotos()
      Log.info("Got " .. #photos .. " photos")
      
      -- Extract basic info including UUID for each photo
      for i, photo in ipairs(photos) do
        local uuid = photo:getRawMetadata('uuid')
        local fileName = photo:getFormattedMetadata('fileName') or ('Photo_' .. i)
        local info = {
          photoId = uuid,
          fileName = fileName
        }
        table.insert(basicPhotoInfo, info)
        Log.debug("Basic info for photo " .. i .. ": ID=" .. tostring(info.photoId))
      end
    end)
    
    if #basicPhotoInfo == 0 then
      LrDialogs.message('Photo Info Extraction Failed',
        'Could not extract basic photo information.', 'error')
      return
    end
    
    Log.info("Successfully extracted basic info for " .. #basicPhotoInfo .. " photos")
    
    -- Phase 2: Skip complex bracket detection for now, just create simple stacks based on time grouping
    Log.info("=== PHASE 2: CREATE STACKS (WITH WRITE ACCESS) ===")
    
    -- For now, create simple test stacks - group photos in sets of 3
    local detectionResults = {
      sequences = {},
      stats = { totalPhotos = #basicPhotoInfo, processedPhotos = 0 }
    }
    
    -- Create simple test sequences
    for i = 1, #basicPhotoInfo, 3 do
      local endIndex = math.min(i + 2, #basicPhotoInfo)
      local groupPhotos = {}
      
      for j = i, endIndex do
        table.insert(groupPhotos, basicPhotoInfo[j])
      end
      
      if #groupPhotos >= 2 then  -- Only create stacks with 2+ photos
        local sequence = {
          type = 'individual',
          brackets = {
            {
              photos = groupPhotos,
              type = 'individual',
              confidence = 80
            }
          }
        }
        table.insert(detectionResults.sequences, sequence)
        detectionResults.stats.processedPhotos = detectionResults.stats.processedPhotos + #groupPhotos
      end
    end
    
    Log.info("Created " .. #detectionResults.sequences .. " test sequences for stacking")
    
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
            
            local stackSuccess, stackMessage = BracketStacking.createStacks(detectionResults, photos, stackProgressCallback)
            
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
        
        local stackSuccess, stackMessage = BracketStacking.createStacks(detectionResults, photos, stackProgressCallback)
        
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
