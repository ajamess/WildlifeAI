local LrPathUtils = import 'LrPathUtils'
local LrShell    = import 'LrShell'
local LrDialogs  = import 'LrDialogs'
local LrFileUtils= import 'LrFileUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local folder = LrPathUtils.child(_PLUGIN.path, 'logs')
if not LrFileUtils.exists(folder) then
    LrDialogs.message('WildlifeAI', 'Log folder not found: '..folder)
    Log.error('Log folder not found: '..folder)
else
    LrShell.revealInShell(folder)
    Log.info('Opened log folder')
end
