local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'
local LrDialogs = import 'LrDialogs'

LrFunctionContext.callWithContext('WildlifeAI_Analytics', function(context)
  LrTasks.startAsyncTask(function()
    local success, err = pcall(function()
      -- Load the analytics dialog
      local AnalyticsDialog = dofile( LrPathUtils.child(_PLUGIN.path, 'UI/AnalyticsDialog.lua') )
      
      -- Show the dialog
      AnalyticsDialog(context)
    end)
    
    if not success then
      LrDialogs.message('Analytics Error', 'Failed to open analytics: ' .. tostring(err), 'error')
    end
  end)
end)
