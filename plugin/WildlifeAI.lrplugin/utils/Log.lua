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
  local f = io.open(filePath, 'a'); if f then f:close() end
  return filePath
end
local function write(level, msg)
  local prefs = LrPrefs.prefsForPlugin()
  if prefs.enableLogging == false then return end
  local f = io.open(ensure(), 'a')
  if f then
    f:write(os.date('%Y-%m-%d %H:%M:%S') .. ' ['..level..'] ' .. tostring(msg) .. '\n')
    f:close()
  end
end
function M.path() return ensure() end
function M.info(m)  write('INFO',  m) end
function M.debug(m) write('DEBUG', m) end
function M.error(m) write('ERROR', m) end
function M.enter(name) write('TRACE', '>> '..tostring(name)); return os.clock(), name end
function M.leave(clockOrName, maybeName)
  local clk, name
  if type(clockOrName)=='number' then clk=clockOrName; name=maybeName or '?' else name=clockOrName end
  local dur = clk and string.format(' (%.3fs)', os.clock()-clk) or ''
  write('TRACE', '<< '..tostring(name)..dur)
end
return M
