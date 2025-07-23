local LrPrefs = import 'LrPrefs'
local LrDialogs = import 'LrDialogs'
local prefs = LrPrefs.prefsForPlugin()
prefs.enableLogging = not prefs.enableLogging
LrDialogs.message('WildlifeAI', 'Logging is now '..(prefs.enableLogging and 'ON' or 'OFF'))
