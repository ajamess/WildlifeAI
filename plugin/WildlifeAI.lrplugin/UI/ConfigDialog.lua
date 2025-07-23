local LrDialogs = import 'LrDialogs'
local LrView    = import 'LrView'
local LrPrefs   = import 'LrPrefs'
return function()
  local f = LrView.osFactory()
  local prefs = LrPrefs.prefsForPlugin()
  local c = f:column {
    bind_to_object = prefs,
    spacing = f:control_spacing(),
    f:static_text { title = 'WildlifeAI Configuration', size = 'large' },
    f:row { f:static_text { title='Windows Runner:' },  f:edit_field { value=LrView.bind('pythonBinaryWin'), width_in_chars=50 } },
    f:row { f:static_text { title='macOS Runner:' },    f:edit_field { value=LrView.bind('pythonBinaryMac'), width_in_chars=50 } },
    f:row { f:static_text { title='Keyword Root:' },    f:edit_field { value=LrView.bind('keywordRoot'), width_in_chars=30 } },
    f:checkbox { title='Enable stacking by scene count after analysis', value=LrView.bind('enableStacking') },
    f:checkbox { title='Write XMP sidecars after metadata update', value=LrView.bind('writeXmp') },
    f:checkbox { title='Mirror numeric fields to IPTC Job Identifier (sortable)', value=LrView.bind('mirrorToIptc') },
    f:checkbox { title='Enable verbose logging (logs/wildlifeai.log)', value=LrView.bind('enableLogging') },
  }
  LrDialogs.presentModalDialog { title='WildlifeAI Configuration', contents=c }
end
