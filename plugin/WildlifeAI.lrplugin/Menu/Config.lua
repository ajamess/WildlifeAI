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
    bind_to_object = prefs, spacing = f:control_spacing(),
    f:static_text{ title='WildlifeAI Preferences' },
    f:row{ f:static_text{ title='Runner (Windows):' }, f:edit_field{ value=LrView.bind('runnerWin'), width_in_chars=50 } },
    f:row{ f:static_text{ title='Runner (macOS):' },   f:edit_field{ value=LrView.bind('runnerMac'), width_in_chars=50 } },
    f:row{ f:static_text{ title='Keyword Root:' },     f:edit_field{ value=LrView.bind('keywordRoot'), width_in_chars=20 } },
    f:checkbox{ title='Enable stacking after analysis', value=LrView.bind('enableStacking') },
    f:checkbox{ title='Write XMP sidecars after metadata update', value=LrView.bind('writeXMP') },
    f:checkbox{ title='Mirror numeric fields to IPTC Job Identifier', value=LrView.bind('mirrorJobId') },
    f:checkbox{ title='Enable verbose logging', value=LrView.bind('enableLogging') },
    f:checkbox{ title='Generate crops of birds found in images', value=LrView.bind('generateCrops') },
  }
  LrDialogs.presentModalDialog{ title='WildlifeAI Preferences', contents=c }
  Log.info('Config closed')
end)