local LrPrefs = import 'LrPrefs'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )

local function setupDefaultPrefs()
  local prefs = LrPrefs.prefsForPlugin()
  
  -- Enhanced runner preferences (updated defaults)
  prefs.runnerWin       = prefs.runnerWin       or 'bin/win/wildlifeai_runner_cpu.exe'
  prefs.runnerMac       = prefs.runnerMac       or 'bin/mac/wildlifeai_runner'
  prefs.keywordRoot     = prefs.keywordRoot     or 'WildlifeAI'
  
  -- Logging and debugging (enable by default for troubleshooting)
  if prefs.enableLogging == nil then prefs.enableLogging = true end
  if prefs.debugMode == nil then prefs.debugMode = true end
  if prefs.verboseRunner == nil then prefs.verboseRunner = true end
  
  -- Processing options
  prefs.enableStacking  = prefs.enableStacking  or false
  prefs.writeXMP        = prefs.writeXMP        or false
  prefs.mirrorJobId     = prefs.mirrorJobId     or false
  prefs.generateCrops   = prefs.generateCrops   ~= false -- default true
  prefs.useGPU          = prefs.useGPU          or false
  prefs.maxWorkers      = prefs.maxWorkers      or 4

  -- Bracket processing options
  if prefs.enableBracketProcessing == nil then prefs.enableBracketProcessing = false end
  prefs.bracketGroupSize = prefs.bracketGroupSize or 3
  prefs.bracketStepEV    = prefs.bracketStepEV    or 1
  prefs.bracketAnalysisDone = prefs.bracketAnalysisDone or false

  
  -- Per-photo processing options
  if prefs.perPhotoOutput == nil then prefs.perPhotoOutput = true end -- default enabled
  if prefs.useProcessingState == nil then prefs.useProcessingState = true end -- default enabled
  
  -- Fallback Python configuration (for development)
  prefs.pythonBinaryWin = prefs.pythonBinaryWin or 'python.exe'
  prefs.pythonBinaryMac = prefs.pythonBinaryMac or 'python3'
  
  return prefs
end

local function validateRunners()
  local prefs = LrPrefs.prefsForPlugin()
  local binDir = LrPathUtils.child(_PLUGIN.path, 'bin/win')
  
  -- Check for enhanced runner
  local enhancedRunner = LrPathUtils.child(binDir, 'wildlifeai_runner_cpu.exe')
  local hasEnhancedRunner = LrFileUtils.exists(enhancedRunner)
  
  -- Check for legacy runner
  local legacyRunner = LrPathUtils.child(binDir, 'kestrel_runner.exe')
  local hasLegacyRunner = LrFileUtils.exists(legacyRunner)
  
  Log.info('Enhanced runner exists: ' .. tostring(hasEnhancedRunner) .. ' at ' .. enhancedRunner)
  Log.info('Legacy runner exists: ' .. tostring(hasLegacyRunner) .. ' at ' .. legacyRunner)
  
  if not hasEnhancedRunner and not hasLegacyRunner then
    Log.warning('No runners found in bin directory!')
  end
  
  return hasEnhancedRunner, hasLegacyRunner
end

-- Initialize preferences
local prefs = setupDefaultPrefs()

-- Validate installation
local hasEnhanced, hasLegacy = validateRunners()

-- Enhanced logging
if prefs.debugMode then
  Log.info('=== WildlifeAI Plugin Debug Info ===')
  Log.info('Plugin path: ' .. _PLUGIN.path)
  Log.info('Enhanced runner available: ' .. tostring(hasEnhanced))
  Log.info('Legacy runner available: ' .. tostring(hasLegacy))
  Log.info('Logging enabled: ' .. tostring(prefs.enableLogging))
  Log.info('Debug mode: ' .. tostring(prefs.debugMode))
  Log.info('Verbose runner: ' .. tostring(prefs.verboseRunner))
  Log.info('Use GPU: ' .. tostring(prefs.useGPU))
  Log.info('Max workers: ' .. tostring(prefs.maxWorkers))
  Log.info('Generate crops: ' .. tostring(prefs.generateCrops))
  Log.info('===================================')
end

Log.info('Plugin init complete. Enhanced=' .. tostring(hasEnhanced) .. ' Logging=' .. tostring(prefs.enableLogging) .. ' Debug=' .. tostring(prefs.debugMode))

return {
  shutdown = function() 
    Log.info('WildlifeAI Plugin shutdown')
    if prefs.debugMode then
      Log.info('Debug mode was enabled during this session')
    end
  end
}
