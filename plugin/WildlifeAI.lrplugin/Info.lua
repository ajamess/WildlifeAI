return {
  LrSdkVersion = 12.0,
  LrSdkMinimumVersion = 6.0,
  LrToolkitIdentifier = 'com.wildlifeai.plugin',
  LrPluginName = 'WildlifeAI',

  LrPluginInfoProvider = 'PluginInfo.lua',
  LrInitPlugin = 'PluginInit.lua',
  LrShutdownPlugin = 'PluginInit.lua',

  LrPluginMenuItems = {
    { title='WildlifeAI: Analyze Selected Photos', file='Menu/Analyze.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Force Reprocess Photos', file='Menu/ForceReprocess.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Clear Processing State…', file='Menu/ClearProcessingState.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Read WildlifeAI Metadata from IPTC Tags…', file='Menu/ReadFromIptc.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Review Crops…',          file='Menu/Review.lua' },
    { title='WildlifeAI: Configure…',             file='Menu/Config.lua' },
    { title='WildlifeAI: Statistics and Analytics…', file='Menu/Analytics.lua' },
    { title='WildlifeAI: Stack Based on Scene and Quality…', file='Menu/StackBySceneAndQuality.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Analyze Brackets', file='Menu/AnalyzeBrackets.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Stack Brackets', file='Menu/StackBrackets.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Clear Bracket Analysis', file='Menu/ClearBracketAnalysis.lua' },
    { title='WildlifeAI: Toggle Logging',         file='Menu/ToggleLogging.lua' },
    { title='WildlifeAI: Toggle Debug Mode',      file='Menu/ToggleDebug.lua' },
    { title='WildlifeAI: Open Log Folder',        file='Menu/OpenLog.lua' },
  },

  LrLibraryMenuItems = {
    { title='WildlifeAI: Analyze Selected Photos', file='Menu/Analyze.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Force Reprocess Photos', file='Menu/ForceReprocess.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Clear Processing State…', file='Menu/ClearProcessingState.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Read WildlifeAI Metadata from IPTC Tags…', file='Menu/ReadFromIptc.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Review Crops…',          file='Menu/Review.lua' },
    { title='WildlifeAI: Configure…',             file='Menu/Config.lua' },
    { title='WildlifeAI: Statistics and Analytics…', file='Menu/Analytics.lua' },
    { title='WildlifeAI: Stack Based on Scene and Quality…', file='Menu/StackBySceneAndQuality.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Analyze Brackets', file='Menu/AnalyzeBrackets.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Stack Brackets', file='Menu/StackBrackets.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Clear Bracket Analysis', file='Menu/ClearBracketAnalysis.lua' },
    { title='WildlifeAI: Toggle Logging',         file='Menu/ToggleLogging.lua' },
    { title='WildlifeAI: Toggle Debug Mode',      file='Menu/ToggleDebug.lua' },
    { title='WildlifeAI: Open Log Folder',        file='Menu/OpenLog.lua' },
  },

  LrMetadataProvider = 'MetadataDefinition.lua',
  LrMetadataTagsetFactory = 'Tagset.lua',

  VERSION = { major=1, minor=0, revision=0, build=0 },
}
