local LrTasks      = import 'LrTasks'
local LrFileUtils  = import 'LrFileUtils'
local LrPathUtils  = import 'LrPathUtils'
local LrLogger     = import 'LrLogger'
local LrPrefs      = import 'LrPrefs'
local json         = require 'utils/dkjson'

local logger = LrLogger('WildlifeAI'); logger:enable('print')
local M = {}

local function getRunnerPath()
  local prefs = LrPrefs.prefsForPlugin()
  if WIN_ENV then
    return LrPathUtils.child(_PLUGIN.path, prefs.pythonBinaryWin)
  else
    return LrPathUtils.child(_PLUGIN.path, prefs.pythonBinaryMac)
  end
end

function M.runKestrel(photos)
  local tmp = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_paths.txt')
  local f = io.open(tmp, 'w')
  for _,p in ipairs(photos) do f:write(p:getRawMetadata('path')..'\n') end
  f:close()

  local outDir = LrPathUtils.child(LrPathUtils.getStandardFilePath('pictures'), '.kestrel')
  LrFileUtils.createAllDirectories(outDir)

  local cmd = string.format('"%s" --photo-list "%s" --output-dir "%s"', getRunnerPath(), tmp, outDir)
  logger:info('Executing: '..cmd)
  LrTasks.execute(cmd)

  local results = {}
  for _,p in ipairs(photos) do
    local path = p:getRawMetadata('path')
    local j = LrPathUtils.replaceExtension(path, 'json')
    if not LrFileUtils.exists(j) then
      j = LrPathUtils.child(outDir, LrPathUtils.leafName(path) .. '.json')
    end
    if LrFileUtils.exists(j) then
      local content = LrFileUtils.readFile(j)
      local ok, data = pcall(json.decode, content)
      if ok then
        data.json_path = j
        results[path] = data
      else
        logger:error('JSON parse failed: '..j)
      end
    end
  end
  return results
end

return M