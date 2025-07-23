local LrTasks      = import 'LrTasks'
local LrFileUtils  = import 'LrFileUtils'
local LrPathUtils  = import 'LrPathUtils'
local LrLogger     = import 'LrLogger'
local LrPrefs      = import 'LrPrefs'
local json         = require 'utils/dkjson'

local logger = LrLogger('WildlifeAI')
logger:enable('print')

local Bridge = {}

local function getRunnerPath()
  local prefs = LrPrefs.prefsForPlugin()
  local base = _PLUGIN.path
  if WIN_ENV then
    return LrPathUtils.child(base, prefs.pythonBinaryWin)
  else
    return LrPathUtils.child(base, prefs.pythonBinaryMac)
  end
end

function Bridge.runKestrel(photos)
  local tempFile = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_paths.txt')
  local f = io.open(tempFile, 'w')
  for _,p in ipairs(photos) do
    f:write(p:getRawMetadata('path') .. '\n')
  end
  f:close()

  local outDir = LrPathUtils.child(LrPathUtils.getStandardFilePath('pictures'), '.kestrel')
  LrFileUtils.createAllDirectories(outDir)

  local cmd = string.format('"%s" --photo-list "%s" --output-dir "%s"', getRunnerPath(), tempFile, outDir)
  logger:info('Executing: '..cmd)
  local rc = LrTasks.execute(cmd)
  logger:info('Runner exit: '..tostring(rc))

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
        results[pth] = data
        data.json_path = jsonPath
      else
        logger:error('JSON parse failed '..jsonPath)
      end
    end
  end
  return results
end

return Bridge