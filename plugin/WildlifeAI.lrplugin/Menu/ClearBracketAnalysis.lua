local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'
local LrPathUtils = import 'LrPathUtils'

LrTasks.startAsyncTask(function()
  LrFunctionContext.callWithContext('WAI_ClearBracketAnalysis', function()
    local BracketStacking = dofile(LrPathUtils.child(_PLUGIN.path, 'BracketStacking.lua'))
    BracketStacking.clear()
  end)
end)
