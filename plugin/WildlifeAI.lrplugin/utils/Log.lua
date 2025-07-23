-- utils/Log.lua
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs     = import 'LrPrefs'

local M = {}
local filePath = nil

local function ensureFile()
  if filePath then return filePath end
  local dir = LrPathUtils.child(_PLUGIN.path, 'logs')
  LrFileUtils.createAllDirectories(dir)
  filePath = LrPathUtils.child(dir, 'wildlifeai.log')
  return filePath
end

local function write(level, msg)
  local prefs = LrPrefs.prefsForPlugin()
  if not prefs.enableLogging then return end
  local f = io.open(ensureFile(), 'a')
  if f then
    f:write(os.date('%Y-%m-%d %H:%M:%S') .. ' [' .. level .. '] ' .. tostring(msg) .. '\n')
    f:close()
  end
end

function M.info(msg)  write('INFO',  msg) end
function M.error(msg) write('ERROR', msg) end
function M.debug(msg) write('DEBUG', msg) end
function M.path() return ensureFile() end

return M