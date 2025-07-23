local LrLogger = import 'LrLogger'
local LrPrefs  = import 'LrPrefs'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

local logger = LrLogger('WildlifeAI')
logger:enable('print')

local prefs = LrPrefs.prefsForPlugin()

prefs.pythonBinaryWin = prefs.pythonBinaryWin or 'bin/win/kestrel_runner.exe'
prefs.pythonBinaryMac = prefs.pythonBinaryMac or 'bin/mac/kestrel_runner'
prefs.keywordRoot     = prefs.keywordRoot     or 'WildlifeAI'
if prefs.enableStacking == nil then prefs.enableStacking = true end
prefs.writeXmp        = prefs.writeXmp        or false
prefs.mirrorToIptc    = prefs.mirrorToIptc    or false
prefs.enableLogging   = prefs.enableLogging   or false

local logDir = LrPathUtils.child(_PLUGIN.path, 'logs')
LrFileUtils.createAllDirectories(logDir)

logger:info('WildlifeAI init done')

return { shutdown = function() logger:info('WildlifeAI shutdown') end }
