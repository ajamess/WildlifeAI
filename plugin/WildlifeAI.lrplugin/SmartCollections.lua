local LrApplication = import 'LrApplication'
local catalog = LrApplication.activeCatalog()
local function ensure(name, rules)
  for _,c in ipairs(catalog:getChildCollections()) do
    if c:getName()==name and c:isSmartCollection() then return c end
  end
  return catalog:createSmartCollection(name, rules, nil)
end
ensure('WildlifeAI: Quality ≥ 90', {
  { criteria='wai_quality', operation='greaterThanOrEqualTo', value='90' }
})
ensure('WildlifeAI: Low Confidence ≤ 50', {
  { criteria='wai_speciesConfidence', operation='lessThanOrEqualTo', value='50' }
})
