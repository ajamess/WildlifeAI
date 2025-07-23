local LrTasks      = import 'LrTasks'
local LrFileUtils  = import 'LrFileUtils'
local LrPathUtils  = import 'LrPathUtils'
local LrPrefs      = import 'LrPrefs'
local json = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/dkjson.lua' ) )
local Log  = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/Log.lua' ) )
local M = {}
local function isWindows() return (WIN_ENV == true) or (LrPathUtils.separator == '\\') end
local function defaultRunnerPath() if isWindows() then return 'bin/win/kestrel_runner.exe' else return 'bin/mac/kestrel_runner' end end
local function getRunnerPath()
  local prefs = LrPrefs.prefsForPlugin()
  local rel = isWindows() and prefs.pythonBinaryWin or prefs.pythonBinaryMac
  if not rel or rel == '' then
    rel = defaultRunnerPath()
    if isWindows() then prefs.pythonBinaryWin = rel else prefs.pythonBinaryMac = rel end
  end
  local full = LrPathUtils.child(_PLUGIN.path, rel)
  Log.debug('Runner path resolved to: '..tostring(full))
  return full
end
function M.runKestrel(photos)
  Log.info('runKestrel: '..tostring(#photos)..' photos')
  local tmp = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_paths.txt')
  local f = assert(io.open(tmp, 'w'))
  for _,p in ipairs(photos) do f:write(p:getRawMetadata('path') .. '\n') end
  f:close()
  Log.debug('Photo list file: '..tmp)
  local outDir = LrPathUtils.child(LrPathUtils.getStandardFilePath('pictures'), '.kestrel')
  LrFileUtils.createAllDirectories(outDir)
  Log.debug('Output dir: '..outDir)
  local cmd = string.format('"%s" --photo-list "%s" --output-dir "%s"', getRunnerPath(), tmp, outDir)
  Log.info('Executing: '..cmd)
  local rc = LrTasks.execute(cmd)
  Log.info('Runner exit: '..tostring(rc))
  local results = {}
  for _,p in ipairs(photos) do
    local pth = p:getRawMetadata('path')
    local jsonPath = LrPathUtils.replaceExtension(pth, 'json')
    if not LrFileUtils.exists(jsonPath) then
      local leaf = LrPathUtils.leafName(pth) .. '.json'
      jsonPath = LrPathUtils.child(outDir, leaf)
    end
    if LrFileUtils.exists(jsonPath) then
      local content = LrFileUtils.readFile(jsonPath)
      local ok, data = pcall(json.decode, content)
      if ok then
        data.json_path = jsonPath
        results[pth] = data
        Log.debug('Parsed JSON: '..jsonPath)
      else
        Log.error('JSON parse failed: '..jsonPath)
      end
    else
      Log.debug('JSON not found for '..pth)
    end
  end
  Log.info('runKestrel finished')
  return results
end
return M
