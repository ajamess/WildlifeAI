local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'
local LrDialogs = import 'LrDialogs'

-- Launch the analytics dialog in its own task so the function context remains
-- active for the lifetime of the UI. The previous implementation created the
-- context first and then started a task which caused the context to be
-- released before the task executed, preventing the dialog from opening.
LrTasks.startAsyncTask(function()
  LrFunctionContext.callWithContext('WildlifeAI_Analytics', function(context)
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
