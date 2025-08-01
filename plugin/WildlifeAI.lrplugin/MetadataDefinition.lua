return {

   -- The title that appears in the dropdown menu
    title = "WildlifeAI",
    
    -- Unique identifier for this metadata set
    id = "com.WildlifeAI.MetadataDefinition",

  metadataFieldsForPhotos = {
    { id='wai_detectedSpecies',    title='WildlifeAI: Detected Species',   dataType='string', searchable=true, browsable=true },
    { id='wai_speciesConfidence',  title='WildlifeAI: Species Confidence', dataType='string', searchable=true, browsable=true },
    { id='wai_quality',            title='WildlifeAI: Quality',            dataType='string', searchable=true, browsable=true },
    { id='wai_rating',             title='WildlifeAI: Rating',             dataType='string', searchable=true, browsable=true },
    { id='wai_sceneCount',         title='WildlifeAI: Scene Count',        dataType='string', searchable=true, browsable=true },
    { id='wai_featureSimilarity',  title='WildlifeAI: Feature Similarity', dataType='string', searchable=true, browsable=true },
    { id='wai_featureConfidence',  title='WildlifeAI: Feature Confidence', dataType='string', searchable=true, browsable=true },
    { id='wai_colorSimilarity',    title='WildlifeAI: Color Similarity',   dataType='string', searchable=true, browsable=true },
    { id='wai_colorConfidence',    title='WildlifeAI: Color Confidence',   dataType='string', searchable=true, browsable=true },
    { id='wai_jsonPath',           title='WildlifeAI: JSON Result Path',   dataType='url',    searchable=false, browsable=false },
    { id='wai_processed',          title='WildlifeAI: Processing State',   dataType='string', searchable=true, browsable=true },
  },
  schemaVersion = 25,  -- Force Lightroom to refresh metadata schema
}
