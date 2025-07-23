local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local M = {}
local path
local function ensure()
  if path then return path end
  local dir = LrPathUtils.child(_PLUGIN.path, 'logs')
  LrFileUtils.createAllDirectories(dir)
  path = LrPathUtils.child(dir, 'wildlifeai.log')
  local f=io.open(path,'a'); if f then f:close() end
  return path
end
local function write(level,msg)
  if LrPrefs.prefsForPlugin().enableLogging==false then return end
  local f=io.open(ensure(),'a')
  if f then f:write(os.date('%Y-%m-%d %H:%M:%S')..' ['..level..'] '..tostring(msg)..'\n'); f:close() end
end
function M.path() return ensure() end
function M.info(m) write('INFO',m) end
function M.debug(m) write('DEBUG',m) end
function M.error(m) write('ERROR',m) end
function M.enter(name) write('TRACE','>> '..name); return os.clock(), name end
function M.leave(clk,name) name=name or '?'; write('TRACE','<< '..name..' ('..string.format('%.3f',os.clock()-clk)..'s)') end
return M