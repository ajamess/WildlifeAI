local LrLogger = import 'LrLogger'
local LrPrefs  = import 'LrPrefs'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

local logger = LrLogger('WildlifeAI')
logger:enable('print')

local prefs = LrPrefs.prefsForPlugin()

local M = {}

function M.start()
    prefs.pythonBinaryWin = prefs.pythonBinaryWin or 'bin/win/kestrel_runner.exe'
    prefs.pythonBinaryMac = prefs.pythonBinaryMac or 'bin/mac/kestrel_runner'
    prefs.keywordRoot     = prefs.keywordRoot     or 'WildlifeAI'
    prefs.enableStacking  = prefs.enableStacking  or true
    prefs.writeXmp        = prefs.writeXmp        or false
    prefs.mirrorToIptc    = prefs.mirrorToIptc    or false
    prefs.enableLogging   = prefs.enableLogging   or false

    -- ensure log dir exists
    local logDir = LrPathUtils.child(_PLUGIN.path, 'logs')
    LrFileUtils.createAllDirectories(logDir)
end

function M.shutdown()
    logger:info('WildlifeAI shutting down')
end

return M