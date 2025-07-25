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
    { title='WildlifeAI: Review Crops…',          file='Menu/Review.lua' },
    { title='WildlifeAI: Configure…',             file='Menu/Config.lua' },
    { title='WildlifeAI: Stack by Scene Count',   file='Menu/Stack.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Toggle Logging',         file='Menu/ToggleLogging.lua' },
    { title='WildlifeAI: Open Log Folder',        file='Menu/OpenLog.lua' },
  },

  LrLibraryMenuItems = {
    { title='WildlifeAI: Analyze Selected Photos', file='Menu/Analyze.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Review Crops…',          file='Menu/Review.lua' },
    { title='WildlifeAI: Configure…',             file='Menu/Config.lua' },
    { title='WildlifeAI: Stack by Scene Count',   file='Menu/Stack.lua', enabledWhen='photosSelected' },
    { title='WildlifeAI: Toggle Logging',         file='Menu/ToggleLogging.lua' },
    { title='WildlifeAI: Open Log Folder',        file='Menu/OpenLog.lua' },
  },

  LrMetadataProvider = 'MetadataDefinition.lua',
  LrMetadataTagsetFactory = 'Tagset.lua',

  VERSION = { major=2, minor=0, revision=0, build=0 },
}