local LrPathUtils = import 'LrPathUtils'
local LrShell    = import 'LrShell'
local LrDialogs  = import 'LrDialogs'
local folder = LrPathUtils.child(_PLUGIN.path, 'logs')
local ok = LrShell.revealInShell(folder)
if not ok then LrDialogs.message('WildlifeAI', 'Unable to open log folder: '..folder) end
