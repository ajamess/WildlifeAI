local LrPathUtils = import 'LrPathUtils'
local LrShell    = import 'LrShell'
local LrDialogs  = import 'LrDialogs'

local path = LrPathUtils.child(_PLUGIN.path, 'logs')
local ok = LrShell.openFilesInApp( { path }, '' )
if not ok then
  LrDialogs.message('WildlifeAI', 'Cannot open log folder: '..path)
end