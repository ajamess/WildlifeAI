local LrPrefs = import 'LrPrefs'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local prefs = LrPrefs.prefsForPlugin()
prefs.enableLogging = not prefs.enableLogging
Log.info('Toggled logging to '..tostring(prefs.enableLogging))
LrDialogs.message('WildlifeAI', 'Logging is now '..(prefs.enableLogging and 'ON' or 'OFF'))
