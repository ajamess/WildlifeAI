local ok, Factory = pcall( import, 'LrMetadataTagsetFactory' )
if not ok then
  ok, Factory = pcall( import, 'LrMetadataTagset' )
  if ok and Factory.createTagsetFromItems then
    Factory = { createTagset = Factory.createTagsetFromItems }
  end
end
Factory = Factory or { createTagset = function(spec) return spec end }

return {
  Factory.createTagset {
    id = 'wildlifeAI_tagset',
    title = 'WildlifeAI',
    items = {
      'wai_detectedSpecies','wai_speciesConfidence','wai_quality','wai_rating','wai_sceneCount',
      'wai_featureSimilarity','wai_featureConfidence','wai_colorSimilarity','wai_colorConfidence','wai_jsonPath'
    }
  }
}