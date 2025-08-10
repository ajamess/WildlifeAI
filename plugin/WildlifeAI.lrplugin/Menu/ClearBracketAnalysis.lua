-- WildlifeAI Clear Bracket Analysis Menu Item
-- Clears any stored bracket analysis results and resets UI state

local LrTasks = import 'LrTasks'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrPrefs = import 'LrPrefs'

LrTasks.startAsyncTask(function()
  local success, err = pcall(function()
    local prefs = LrPrefs.prefsForPlugin()
    
    -- Check if bracket stacking is enabled
    if not prefs.enableBracketStacking then
      LrDialogs.message('Bracket Stacking Disabled', 
        'Bracket stacking is not enabled in the configuration.', 'info')
      return
    end
    
    -- Get selected photos
    local catalog = LrApplication.activeCatalog()
    local photos = catalog:getTargetPhotos()
    
    if #photos == 0 then
      LrDialogs.message('No Photos Selected', 'Please select photos to clear bracket analysis data from.')
      return
    end
    
    -- Confirm action
    local result = LrDialogs.confirm(
      'Clear Bracket Analysis',
      'This will clear any stored bracket analysis data for the selected photos.\n\n' ..
      'This action cannot be undone. Continue?',
      'Clear Analysis',
      'Cancel'
    )
    
    if result ~= 'ok' then
      return
    end
    
    -- Clear any plugin metadata related to bracket analysis
    local clearedCount = 0
    
    catalog:withWriteAccessDo('Clear Bracket Analysis', function()
      for _, photo in ipairs(photos) do
        -- Clear any bracket-related metadata we might have stored
        local hadData = false
        
        -- Check if photo has any bracket-related metadata
        local bracketAnalyzed = photo:getPropertyForPlugin(_PLUGIN, 'wai_bracket_analyzed')
        local bracketSequenceId = photo:getPropertyForPlugin(_PLUGIN, 'wai_bracket_sequence')
        local bracketType = photo:getPropertyForPlugin(_PLUGIN, 'wai_bracket_type')
        local bracketConfidence = photo:getPropertyForPlugin(_PLUGIN, 'wai_bracket_confidence')
        
        if bracketAnalyzed or bracketSequenceId or bracketType or bracketConfidence then
          hadData = true
        end
        
        -- Clear the metadata
        photo:setPropertyForPlugin(_PLUGIN, 'wai_bracket_analyzed', nil)
        photo:setPropertyForPlugin(_PLUGIN, 'wai_bracket_sequence', nil)
        photo:setPropertyForPlugin(_PLUGIN, 'wai_bracket_type', nil)
        photo:setPropertyForPlugin(_PLUGIN, 'wai_bracket_confidence', nil)
        photo:setPropertyForPlugin(_PLUGIN, 'wai_bracket_position', nil)
        photo:setPropertyForPlugin(_PLUGIN, 'wai_bracket_size', nil)
        photo:setPropertyForPlugin(_PLUGIN, 'wai_bracket_exposure_analysis', nil)
        
        if hadData then
          clearedCount = clearedCount + 1
        end
      end
    end)
    
    -- Show result
    if clearedCount > 0 then
      LrDialogs.message('Analysis Cleared', 
        string.format('Cleared bracket analysis data from %d photos.', clearedCount), 'info')
    else
      LrDialogs.message('No Data Found', 
        'No bracket analysis data was found for the selected photos.', 'info')
    end
  end)
  
  if not success then
    LrDialogs.message('Clear Analysis Error', 'An error occurred while clearing bracket analysis: ' .. tostring(err), 'error')
  end
end)
