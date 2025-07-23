local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs     = import 'LrPrefs'
local M = {}
local filePath
local function ensure()
  if filePath then return filePath end
  local dir = LrPathUtils.child(_PLUGIN.path, 'logs')
  LrFileUtils.createAllDirectories(dir)
  filePath = LrPathUtils.child(dir, 'wildlifeai.log')
  return filePath
end
local function write(level, msg)
  local prefs = LrPrefs.prefsForPlugin()
  if not prefs.enableLogging then return end
  local ok, f = pcall(io.open, ensure(), 'a')
  if ok and f then
    f:write(os.date('%Y-%m-%d %H:%M:%S') .. ' ['..level..'] ' .. tostring(msg) .. '\n')
    f:close()
  end
end
function M.info(m)  write('INFO',  m) end
function M.debug(m) write('DEBUG', m) end
function M.error(m) write('ERROR', m) end
function M.path() return ensure() end
return M
