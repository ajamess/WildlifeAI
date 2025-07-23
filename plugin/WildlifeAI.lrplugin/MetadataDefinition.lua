return {
  metadataFieldsForPhotos = {
    { id='wai_detectedSpecies',     title='WildlifeAI: Detected Species',    dataType='string', searchable=true, browsable=true },
    { id='wai_speciesConfidence',   title='WildlifeAI: Species Confidence',  dataType='number', minValue=0, maxValue=100, searchable=true, browsable=true },
    { id='wai_quality',             title='WildlifeAI: Quality',             dataType='number', minValue=0, maxValue=100, searchable=true, browsable=true },
    { id='wai_rating',              title='WildlifeAI: Rating',              dataType='number', minValue=0, maxValue=100, searchable=true, browsable=true },
    { id='wai_sceneCount',          title='WildlifeAI: Scene Count',         dataType='number', minValue=0, searchable=true, browsable=true },
    { id='wai_featureSimilarity',   title='WildlifeAI: Feature Similarity',  dataType='number', minValue=0, maxValue=100, searchable=true, browsable=true },
    { id='wai_colorSimilarity',     title='WildlifeAI: Color Similarity',    dataType='number', minValue=0, maxValue=100, searchable=true, browsable=true },
    { id='wai_colorConfidence',     title='WildlifeAI: Color Confidence',    dataType='number', minValue=0, maxValue=100, searchable=true, browsable=true },
    { id='wai_jsonPath',            title='WildlifeAI: JSON Result Path',    dataType='string', searchable=false, browsable=false },
  },
  schemaVersion = 2,
}