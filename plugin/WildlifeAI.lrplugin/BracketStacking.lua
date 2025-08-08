local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrPrefs = import 'LrPrefs'

local M = {}

function M.analyze()
  local catalog = LrApplication.activeCatalog()
  local photos = catalog:getTargetPhotos()
  if #photos == 0 then
    LrDialogs.message('WildlifeAI', 'No photos selected')
    return
  end
  local prefs = LrPrefs.prefsForPlugin()
  prefs.bracketAnalysisDone = true
  LrDialogs.message('WildlifeAI', 'Bracket analysis complete.')
end

function M.hasAnalysis()
  local prefs = LrPrefs.prefsForPlugin()
  return prefs.bracketAnalysisDone == true
end

function M.stack()
  local catalog = LrApplication.activeCatalog()
  local prefs = LrPrefs.prefsForPlugin()
  if not prefs.bracketAnalysisDone then
    LrDialogs.message('WildlifeAI', 'Analyze brackets before stacking.')
    return
  end
  local photos = catalog:getTargetPhotos()
  if #photos == 0 then
    LrDialogs.message('WildlifeAI', 'No photos selected')
    return
  end
  catalog:withWriteAccessDo('WAI Bracket Stack', function()
    local top = photos[1]
    for i = 2, #photos do
      catalog:createPhotoStack(top, photos[i])
    end
  end, {timeout=120})
  LrDialogs.message('WildlifeAI', 'Bracket stacking complete.')
end

function M.clear()
  local prefs = LrPrefs.prefsForPlugin()
  prefs.bracketAnalysisDone = false
  LrDialogs.message('WildlifeAI', 'Bracket analysis cleared.')
end

return M
