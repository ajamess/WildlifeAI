local LrApplication = import 'LrApplication'

local M = {}

local function getOrCreateKeyword(catalog, pathParts)
  local parent = nil
  for _,name in ipairs(pathParts) do
    local kw = catalog:createKeyword(name, {}, true, parent, true)
    parent = kw
  end
  return parent
end

local function bucket(value)
  local start = math.floor((value or 0)/10)*10
  return start .. '-' .. (start + 9)
end

function M.applyKeywords(photo, root, data)
  local catalog = LrApplication.activeCatalog()

  local spec = data.detected_species or 'Unknown'
  local specKw = {root, 'Species', spec}

  local qBucket = {root, 'Quality', bucket(data.quality or 0)}
  local cBucket = {root, 'Confidence', bucket(data.species_confidence or 0)}

  local kws = { specKw, qBucket, cBucket }
  catalog:withWriteAccessDo('WildlifeAI Keywords', function()
    for _,pathParts in ipairs(kws) do
      local kw = getOrCreateKeyword(catalog, pathParts)
      if kw then photo:addKeyword(kw) end
    end
  end)
end

return M