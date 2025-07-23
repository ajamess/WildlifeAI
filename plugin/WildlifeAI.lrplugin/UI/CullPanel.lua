local LrDialogs = import 'LrDialogs'
local LrView    = import 'LrView'
local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'

local Log = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/Log.lua' ) )

return function()
  local catalog = LrApplication.activeCatalog()
  local photos = catalog:getTargetPhotos()
  if #photos == 0 then photos = catalog:getAllPhotos() end

  table.sort(photos, function(a,b)
    local qa = tonumber(a:getPropertyForPlugin(_PLUGIN,'wai_quality') or '0') or 0
    local qb = tonumber(b:getPropertyForPlugin(_PLUGIN,'wai_quality') or '0') or 0
    if qa == qb then
      local ca = tonumber(a:getPropertyForPlugin(_PLUGIN,'wai_speciesConfidence') or '0') or 0
      local cb = tonumber(b:getPropertyForPlugin(_PLUGIN,'wai_speciesConfidence') or '0') or 0
      return ca > cb
    end
    return qa > qb
  end)

  local f = LrView.osFactory()
  local rows = {}
  for i,p in ipairs(photos) do
    rows[#rows+1] = f:row {
      spacing = f:control_spacing(),
      f:static_text { title = tostring(i), width_in_chars = 4 },
      f:static_text { title = p:getFormattedMetadata('fileName'), width_in_chars = 40 },
      f:static_text { title = 'Q:'..(p:getPropertyForPlugin(_PLUGIN,'wai_quality') or '0'), width_in_chars = 6 },
      f:static_text { title = 'C:'..(p:getPropertyForPlugin(_PLUGIN,'wai_speciesConfidence') or '0'), width_in_chars = 6 },
    }
  end

  Log.info('Opened Cull Panel for '..#photos..' photos')

  LrDialogs.presentModalDialog {
    title = 'WildlifeAI Cull Panel (sorted by Quality/Confidence)',
    contents = f:scrolled_view { width=700, height=500, f:column(rows) }
  }
end