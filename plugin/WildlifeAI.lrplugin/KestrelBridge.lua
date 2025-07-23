local LrTasks      = import 'LrTasks'
local LrFileUtils  = import 'LrFileUtils'
local LrPathUtils  = import 'LrPathUtils'
local LrPrefs      = import 'LrPrefs'

local json = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/dkjson.lua' ) )
local Log  = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/Log.lua' ) )

local M = {}

local function isWindows()
  return (WIN_ENV == true) or (LrPathUtils.separator == '\\')
end

local function getRunnerPath()
  local prefs = LrPrefs.prefsForPlugin()
  local path
  if isWindows() then
    path = LrPathUtils.child(_PLUGIN.path, prefs.pythonBinaryWin)
  else
    path = LrPathUtils.child(_PLUGIN.path, prefs.pythonBinaryMac)
  end
  Log.debug('Runner path: '..tostring(path))
  return path
end

function M.runKestrel(photos)
  Log.info('runKestrel start with '..#photos..' photos')
  local tmp = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_paths.txt')
  local f = assert(io.open(tmp, 'w'))
  for _,p in ipairs(photos) do
    f:write(p:getRawMetadata('path') .. '\n')
  end
  f:close()
  Log.debug('Wrote photo list: '..tmp)

  local outDir = LrPathUtils.child(LrPathUtils.getStandardFilePath('pictures'), '.kestrel')
  LrFileUtils.createAllDirectories(outDir)
  Log.debug('Output dir: '..outDir)

  local cmd = string.format('"%s" --photo-list "%s" --output-dir "%s"', getRunnerPath(), tmp, outDir)
  Log.info('Executing: '..cmd)
  local rc = LrTasks.execute(cmd)
  Log.info('Runner exit code: '..tostring(rc))

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
        Log.debug('Parsed JSON for '..pth)
      else
        Log.error('JSON parse failed: '..jsonPath)
      end
    else
      Log.debug('JSON not found for '..pth)
    end
  end
  Log.info('runKestrel done')
  return results
end

return M