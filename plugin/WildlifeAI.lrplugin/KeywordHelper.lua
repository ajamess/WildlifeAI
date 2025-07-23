local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local M = {}
local function getOrCreateKeyword(catalog, parts)
  local parent = nil
  for _,name in ipairs(parts) do
    local kw = catalog:createKeyword(name, {}, true, parent, true)
    parent = kw
  end
  return parent
end
local function bucket(v)
  local n = tonumber(v) or 0
  local start = math.floor(n/10)*10
  return start .. '-' .. (start + 9)
end
function M.apply(photo, root, data)
  local catalog = LrApplication.activeCatalog()
  local spec = (data.detected_species and data.detected_species ~= '' and data.detected_species) or 'Unknown'
  local kws = {
    {root, 'Species', spec},
    {root, 'Quality', bucket(data.quality)},
    {root, 'Confidence', bucket(data.species_confidence)},
  }
  for _,parts in ipairs(kws) do
    local kw = getOrCreateKeyword(catalog, parts)
    if kw then photo:addKeyword(kw) end
  end
  Log.debug('Keywords applied to '..(photo:getFormattedMetadata('fileName') or '?'))
end
return M
