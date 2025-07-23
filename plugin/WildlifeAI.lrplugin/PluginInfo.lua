local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrPrefs = import 'LrPrefs'
local LrPathUtils = import 'LrPathUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
return function()
  local prefs = LrPrefs.prefsForPlugin()
  local f=LrView.osFactory()
  local c=f:column{
    spacing=f:control_spacing(),
    f:static_text{ title='WildlifeAI Lightroom Plugin v2.0' },
    f:static_text{ title='Runner (Win): '..tostring(prefs.runnerWin) },
    f:static_text{ title='Runner (Mac): '..tostring(prefs.runnerMac) },
    f:static_text{ title='Log file: '..Log.path() }
  }
  LrDialogs.presentModalDialog{ title='WildlifeAI Info', contents=c }
end