local LrTasks      = import 'LrTasks'
local LrFileUtils  = import 'LrFileUtils'
local LrPathUtils  = import 'LrPathUtils'
local LrPrefs      = import 'LrPrefs'

local json = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/dkjson.lua' ) )
local Log  = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/Log.lua' ) )

local M = {}

local function isWindows() return (LrPathUtils.separator == '\\') end
local function defaultRunner() return isWindows() and 'bin/win/kestrel_runner.exe' or 'bin/mac/kestrel_runner' end
local function runnerPath()
  local prefs = LrPrefs.prefsForPlugin()
  local rel = isWindows() and prefs.pythonBinaryWin or prefs.pythonBinaryMac
  if not rel or rel == '' then
    rel = defaultRunner()
    if isWindows() then prefs.pythonBinaryWin = rel else prefs.pythonBinaryMac = rel end
  end
  return LrPathUtils.child(_PLUGIN.path, rel)
end

function M.run(photos)
  Log.info('run start '..#photos)
  local tmp = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_paths.txt')
  local f = assert(io.open(tmp, 'w'))
  for _,p in ipairs(photos) do f:write(p:getRawMetadata('path')..'\n') end
  f:close()

  local outDir = LrPathUtils.child(LrPathUtils.getStandardFilePath('pictures'), '.kestrel')
  LrFileUtils.createAllDirectories(outDir)

  local cmd = string.format('"%s" --photo-list "%s" --output-dir "%s"', runnerPath(), tmp, outDir)
  Log.info('exec '..cmd)
  local rc = LrTasks.execute(cmd)
  Log.info('rc '..tostring(rc))

  local results = {}
  for _,p in ipairs(photos) do
    local pth = p:getRawMetadata('path')
    local jsonPath = LrPathUtils.replaceExtension(pth, 'json')
    if not LrFileUtils.exists(jsonPath) then
      local leaf = LrPathUtils.leafName(pth)..'.json'
      jsonPath = LrPathUtils.child(outDir, leaf)
    end
    if LrFileUtils.exists(jsonPath) then
      local content = LrFileUtils.readFile(jsonPath)
      local ok, data = pcall(json.decode, content)
      if ok then
        data.json_path = jsonPath
        results[pth] = data
      else
        Log.error('json parse fail '..jsonPath)
      end
    end
  end
  Log.info('run done')
  return results
end

return M
