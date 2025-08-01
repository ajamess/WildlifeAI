local LrPathUtils = import 'LrPathUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'

LrTasks.startAsyncTask(function()
  LrFunctionContext.callWithContext('WAI_Config', function(context)
    dofile(LrPathUtils.child(_PLUGIN.path, 'UI/ConfigDialog.lua'))(context)
  end)
end)
