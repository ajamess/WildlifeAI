local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'
local LrPathUtils = import 'LrPathUtils'
local LrDialogs = import 'LrDialogs'

LrTasks.startAsyncTask(function()
  LrFunctionContext.callWithContext('WAI_StackBrackets', function()
    local BracketStacking = dofile(LrPathUtils.child(_PLUGIN.path, 'BracketStacking.lua'))
    if not BracketStacking.hasAnalysis() then
      LrDialogs.message('WildlifeAI', 'Analyze brackets before stacking.')
      return
    end
    BracketStacking.stack()
  end)
end)
