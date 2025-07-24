local LrPrefs = import 'LrPrefs'
local LrPathUtils = import 'LrPathUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )

local prefs = LrPrefs.prefsForPlugin()
prefs.runnerWin       = prefs.runnerWin       or 'bin/win/kestrel_runner.exe'
prefs.runnerMac       = prefs.runnerMac       or 'bin/mac/kestrel_runner'
prefs.keywordRoot     = prefs.keywordRoot     or 'WildlifeAI'
if prefs.enableLogging == nil then prefs.enableLogging = false end
prefs.enableStacking  = prefs.enableStacking  or false
prefs.writeXMP        = prefs.writeXMP        or false
prefs.mirrorJobId     = prefs.mirrorJobId     or false
prefs.generateCrops   = prefs.generateCrops   ~= false -- default true

Log.info('Plugin init complete. Logging='..tostring(prefs.enableLogging))

return {
  shutdown = function() Log.info('Shutdown') end
}