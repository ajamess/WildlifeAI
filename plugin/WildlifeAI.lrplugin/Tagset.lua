local ok, Factory = pcall(import, 'LrMetadataTagsetFactory')
local items = {
  'wai_detectedSpecies',
  'wai_speciesConfidence',
  'wai_quality',
  'wai_rating',
  'wai_sceneCount',
  'wai_featureSimilarity',
  'wai_colorSimilarity',
  'wai_colorConfidence',
  'wai_jsonPath',
}
if ok and Factory then
  return { Factory.createTagset { id='wildlifeAI_tagset', title='WildlifeAI', items=items } }
else
  return { { id='wildlifeAI_tagset', title='WildlifeAI', items=items } }
end
