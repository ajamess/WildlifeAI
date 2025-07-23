local LrLogger    = import 'LrLogger'
local LrPrefs     = import 'LrPrefs'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

local logger = LrLogger('WildlifeAI')
logger:enable('print')

local prefs = LrPrefs.prefsForPlugin()

prefs.pythonBinaryWin = prefs.pythonBinaryWin or 'bin/win/kestrel_runner.exe'
prefs.pythonBinaryMac = prefs.pythonBinaryMac or 'bin/mac/kestrel_runner'
prefs.keywordRoot     = prefs.keywordRoot     or 'WildlifeAI'
if prefs.enableStacking == nil then prefs.enableStacking = true end
if prefs.writeXmp == nil then prefs.writeXmp = false end
if prefs.mirrorToIptc == nil then prefs.mirrorToIptc = false end
if prefs.enableLogging == nil then prefs.enableLogging = true end

local logDir = LrPathUtils.child(_PLUGIN.path, 'logs')
LrFileUtils.createAllDirectories(logDir)

logger:info('WildlifeAI init complete. Logging='..tostring(prefs.enableLogging))

return { shutdown = function() logger:info('WildlifeAI shutdown') end }