local LrPrefs = import 'LrPrefs'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )

local prefs = LrPrefs.prefsForPlugin()

-- Toggle debug mode
prefs.debugMode = not prefs.debugMode

local status = prefs.debugMode and 'enabled' or 'disabled'
Log.info('Debug mode ' .. status)

LrDialogs.message('WildlifeAI', 'Debug mode ' .. status .. '.\n\nRestart Lightroom to see full debug output in logs.', 'info')
