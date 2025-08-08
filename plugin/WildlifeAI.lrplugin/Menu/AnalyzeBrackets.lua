local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'

LrFunctionContext.callWithContext('WAI_AnalyzeBrackets', function()
  local BracketStacking = dofile(LrPathUtils.child(_PLUGIN.path, 'BracketStacking.lua'))
  BracketStacking.analyze()
end)
