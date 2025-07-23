local LrPathUtils = import 'LrPathUtils'
local LrShell = import 'LrShell'
local LrFileUtils = import 'LrFileUtils'
local LrDialogs = import 'LrDialogs'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local folder = LrPathUtils.child(_PLUGIN.path,'logs')
if LrFileUtils.exists(folder) then LrShell.revealInShell(folder); Log.info('Opened log folder')
else LrDialogs.message('WildlifeAI','Log folder missing'); Log.error('Log folder missing') end