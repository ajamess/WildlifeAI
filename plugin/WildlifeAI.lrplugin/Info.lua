return {
    LrSdkVersion        = 12.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'com.wildlifeai.plugin',
    LrPluginName        = 'WildlifeAI',

    LrPluginInfoUrl      = 'https://github.com/ajamess/WildlifeAI',
    LrPluginInfoProvider = 'PluginInfo.lua',

    LrInitPlugin     = 'PluginInit.lua',
    LrShutdownPlugin = 'PluginInit.lua',

    LrPluginMenuItems = {
        { title = 'WildlifeAI: Analyze Selected Photos', file = 'Menu/Analyze.lua', enabledWhen = 'photosSelected' },
        { title = 'WildlifeAI: Configure…',              file = 'Menu/Config.lua' },
        { title = 'WildlifeAI: Cull Panel…',             file = 'Menu/Cull.lua' },
        { title = 'WildlifeAI: Stack by Scene Count',    file = 'Menu/Stack.lua', enabledWhen = 'photosSelected' },
        { title = 'WildlifeAI: Generate Smart Collections', file = 'Menu/SmartCollections.lua' },
        { title = 'WildlifeAI: Toggle Logging',          file = 'Menu/ToggleLogging.lua' },
        { title = 'WildlifeAI: Open Log Folder',         file = 'Menu/OpenLog.lua' },
    },

    LrLibraryMenuItems = {
        { title = 'WildlifeAI: Analyze Selected Photos', file = 'Menu/Analyze.lua', enabledWhen = 'photosSelected' },
        { title = 'WildlifeAI: Configure…',              file = 'Menu/Config.lua' },
        { title = 'WildlifeAI: Cull Panel…',             file = 'Menu/Cull.lua' },
        { title = 'WildlifeAI: Stack by Scene Count',    file = 'Menu/Stack.lua', enabledWhen = 'photosSelected' },
        { title = 'WildlifeAI: Generate Smart Collections', file = 'Menu/SmartCollections.lua' },
        { title = 'WildlifeAI: Toggle Logging',          file = 'Menu/ToggleLogging.lua' },
        { title = 'WildlifeAI: Open Log Folder',         file = 'Menu/OpenLog.lua' },
    },

    LrMetadataProvider      = 'MetadataDefinition.lua',
    LrMetadataTagsetFactory = 'Tagset.lua',

    VERSION = { major=1, minor=1, revision=0, build=0 },
}