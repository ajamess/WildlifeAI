-- UI/ConfigDialog.lua : comprehensive configuration screen
local LrDialogs = import 'LrDialogs'
local LrView    = import 'LrView'
local LrPrefs   = import 'LrPrefs'

return function()
  local f = LrView.osFactory()
  local prefs = LrPrefs.prefsForPlugin()

  local c = f:column {
    bind_to_object = prefs,
    spacing = f:control_spacing(),

    f:static_text { title = 'WildlifeAI Configuration', size = 'large', fill_horizontal = 1 },

    f:row { f:static_text { title = 'Windows Runner EXE:' },  f:edit_field { value = LrView.bind('pythonBinaryWin'), width_in_chars = 55 } },
    f:row { f:static_text { title = 'macOS Runner Bin:' },    f:edit_field { value = LrView.bind('pythonBinaryMac'), width_in_chars = 55 } },

    f:row { f:static_text { title = 'Keyword Root:' },        f:edit_field { value = LrView.bind('keywordRoot'), width_in_chars = 35 } },

    f:checkbox { title = 'Enable stacking after analysis', value = LrView.bind('enableStacking') },
    f:checkbox { title = 'Write XMP sidecars after metadata update', value = LrView.bind('writeXmp') },
    f:checkbox { title = 'Mirror numeric fields to IPTC Job Identifier (sortable)', value = LrView.bind('mirrorToIptc') },
    f:checkbox { title = 'Enable verbose logging', value = LrView.bind('enableLogging') },
  }

  LrDialogs.presentModalDialog {
    title   = 'Configure WildlifeAI',
    contents = c,
  }
end