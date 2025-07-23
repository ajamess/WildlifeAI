local LrApplication = import 'LrApplication'

local M = {}

local function getOrCreateKeyword(catalog, parts)
  local parent = nil
  for _, name in ipairs(parts) do
    local kw = catalog:createKeyword(name, {}, true, parent, true)
    parent = kw
  end
  return parent
end

local function bucket(v)
  local n = tonumber(v) or 0
  local start = math.floor(n/10) * 10
  return start .. '-' .. (start + 9)
end

function M.applyKeywords(photo, root, data)
  local catalog = LrApplication.activeCatalog()
  local spec = (data.detected_species ~= '' and data.detected_species) or 'Unknown'
  local kws = {
    { root, 'Species', spec },
    { root, 'Quality', bucket(data.quality) },
    { root, 'Confidence', bucket(data.species_confidence) },
  }
  catalog:withWriteAccessDo('WildlifeAI Keywords', function()
    for _, parts in ipairs(kws) do
      local kw = getOrCreateKeyword(catalog, parts)
      if kw then photo:addKeyword(kw) end
    end
  end)
end

return M
