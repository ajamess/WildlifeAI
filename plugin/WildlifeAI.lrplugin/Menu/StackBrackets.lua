-- WildlifeAI Stack Brackets Menu Item
-- Creates stacks from previously analyzed bracket patterns

local LrTasks = import 'LrTasks'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrProgressScope = import 'LrProgressScope'
local LrPrefs = import 'LrPrefs'
local LrPathUtils = import 'LrPathUtils'

local BracketStacking = dofile( LrPathUtils.child(_PLUGIN.path, 'BracketStacking.lua') )

LrTasks.startAsyncTask(function()
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
  
  if #photos == 0 then
    LrDialogs.message('No Photos Selected', 'Please select photos to stack into brackets.')
    return
  end
  
  if #photos == 1 then
    LrDialogs.message('Single Photo Selected', 'Please select multiple photos to create bracket stacks.')
    return
  end
  
  -- Validate preferences before proceeding
  local isValid, errors = BracketStacking.validatePreferences(prefs)
  if not isValid then
    LrDialogs.message('Configuration Error', 
      'Please fix the following configuration issues:\n\n' .. table.concat(errors, '\n'), 'error')
    return
  end
  
  local success, err = pcall(function()
    -- Analyze and create stacks directly (no preview)
    local progressScope = LrProgressScope {
      title = 'Creating Bracket Stacks',
      caption = 'Analyzing ' .. #photos .. ' photos for bracket patterns...'
    }
    
    local progressCallback = function(progress, status)
      if progressScope then
        progressScope:setPortionComplete(progress * 0.7) -- Reserve 30% for stack creation
        if status then
          progressScope:setCaption(status)
        end
      end
    end
    
    local detectionResults = BracketStacking.detectBrackets(photos, progressCallback)
    
    -- Check if any brackets were detected
    if not detectionResults.sequences or #detectionResults.sequences == 0 then
      if progressScope then
        progressScope:done()
      end
      LrDialogs.message('No Brackets Detected', 
        'No bracket patterns were detected in the selected photos.\n\n' ..
        'This could mean:\n' ..
        '• The photos are not part of bracket sequences\n' ..
        '• The time intervals are too strict\n' ..
        '• The bracket size settings don\'t match your sequences\n\n' ..
        'Try using "Analyze Brackets" first to see detailed detection results, or adjust the settings.', 'info')
      return
    end
    
    -- Create stacks
    if progressScope then
      progressScope:setCaption('Creating bracket stacks...')
    end
    
    local stackProgressCallback = function(progress, status)
      if progressScope then
        progressScope:setPortionComplete(0.7 + (progress * 0.3)) -- Use remaining 30%
        if status then
          progressScope:setCaption(status)
        end
      end
    end
    
    local stackSuccess, stackMessage = BracketStacking.createStacks(detectionResults, stackProgressCallback)
    
    if progressScope then
      progressScope:setPortionComplete(1.0)
      progressScope:done()
    end
    
    if stackSuccess then
      LrDialogs.message('Stacking Complete', stackMessage, 'info')
    else
      LrDialogs.message('Stacking Failed', stackMessage, 'error')
    end
  end)
  
  if not success then
    LrDialogs.message('Bracket Stacking Error', 'An error occurred during bracket stacking: ' .. tostring(err), 'error')
  end
end)
