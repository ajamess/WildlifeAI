local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrPrefs = import 'LrPrefs'
local LrPathUtils = import 'LrPathUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
LrFunctionContext.callWithContext('WAI_Config', function()
  local f = LrView.osFactory()
  local prefs = LrPrefs.prefsForPlugin()
  local c = f:column {
    bind_to_object=prefs, spacing=f:control_spacing(),
    f:static_text{ title='WildlifeAI Preferences' },
    f:row{ f:static_text{ title='Runner (Windows):' }, f:edit_field{ value=LrView.bind('runnerWin'), width_in_chars=50 } },
    f:row{ f:static_text{ title='Runner (macOS):' },   f:edit_field{ value=LrView.bind('runnerMac'), width_in_chars=50 } },
    f:checkbox{ title='Enable logging', value=LrView.bind('enableLogging') },
  }
  LrDialogs.presentModalDialog{ title='WildlifeAI Preferences', contents=c }
  Log.info('Config closed')
end)