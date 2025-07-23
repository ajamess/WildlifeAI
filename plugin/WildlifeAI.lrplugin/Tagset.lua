local LrMetadataTagsetFactory = import 'LrMetadataTagsetFactory'

return {
  LrMetadataTagsetFactory.createTagset {
    id    = 'wildlifeAI_tagset',
    title = 'WildlifeAI',
    items = {
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
  }
}
