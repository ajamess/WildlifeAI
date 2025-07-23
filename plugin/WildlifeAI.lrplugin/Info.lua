return {
    LrSdkVersion            = 12.0,
    LrSdkMinimumVersion     = 6.0,
    LrToolkitIdentifier     = 'com.wildlifeai.plugin',
    LrPluginName            = 'WildlifeAI',

    LrPluginInfoUrl         = 'https://github.com/yourname/WildlifeAI',
    LrPluginInfoProvider    = 'PluginInit.lua',

    LrInitPlugin            = 'PluginInit.lua',
    LrShutdownPlugin        = 'PluginInit.lua',

    LrExportMenuItems = {
        { title = 'Analyze Selected Photos with WildlifeAI', file = 'Tasks.lua', enabledWhen = 'photosSelected' }
    },

    LrPluginMenuItems = {
        { title = 'Configure WildlifeAI…', file = 'UI/ConfigDialog.lua' },
        { title = 'Toggle Logging On/Off', file = 'UI/ToggleLogging.lua' },
        { title = 'Open Log Folder', file = 'UI/OpenLogFolder.lua' },
        { title = 'Re-run Analysis on Missing Results', file = 'Tasks.lua', enabledWhen = 'photosAvailable' },
        { title = 'Stack by Scene Count', file = 'QualityStack.lua', enabledWhen = 'photosSelected' },
        { title = 'Cull Panel…', file = 'UI/CullPanel.lua', enabledWhen = 'photosAvailable' },
        { title = 'Generate Smart Collections', file = 'SmartCollections.lua', enabledWhen = 'catalog' },
    },

    LrMetadataProvider      = 'MetadataDefinition.lua',
    LrMetadataTagsetFactory = 'Tagset.lua',

    VERSION = { major=1, minor=0, revision=4, build=0 },
}