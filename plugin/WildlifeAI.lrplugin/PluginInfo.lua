local LrView    = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrPrefs   = import 'LrPrefs'
local LrPathUtils = import 'LrPathUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
return function()
    Log.enter('PluginInfo')
    local prefs = LrPrefs.prefsForPlugin()
    local f = LrView.osFactory()
    local c = f:column {
        spacing = f:control_spacing(),
        f:static_text { title = 'WildlifeAI Lightroom Plugin' },
        f:static_text { title = 'Logging: ' .. tostring(prefs.enableLogging) },
        f:static_text { title = 'Log file: ' .. Log.path() },
        f:static_text { title = 'Version: 1.1.1' },
    }
    LrDialogs.presentModalDialog{ title='WildlifeAI Info', contents=c }
    Log.leave('PluginInfo')
end
