local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local LrDialogs = import 'LrDialogs'
local json = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/dkjson.lua') )
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local M = {}
local function isWin()
  return WIN_ENV or LrPathUtils.separator == '\\'
end
local function quote(p) if isWin() then return '"'..p..'"' else return "'"..p.."'" end end
local function chooseRunner()
  local prefs = LrPrefs.prefsForPlugin()
  local rel = isWin() and prefs.runnerWin or prefs.runnerMac
  local full = LrPathUtils.child(_PLUGIN.path, rel)
  if LrFileUtils.exists(full) then return full end
  return full -- still return; error later
end
function M.run(photos)
  local clk = Log.enter('Bridge.run')
  local tmp = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_paths.txt')
  local f = assert(io.open(tmp,'w'))
  for _,p in ipairs(photos) do f:write(p:getRawMetadata('path')..'\n') end
  f:close()
  local outDir = LrPathUtils.child(LrPathUtils.getStandardFilePath('pictures'), '.wai')
  LrFileUtils.createAllDirectories(outDir)
  local runner = chooseRunner()
  if not LrFileUtils.exists(runner) then
    Log.error('Runner missing: '..runner)
    LrDialogs.message('WildlifeAI','Runner missing: '..runner,'error')
    Log.leave(clk,'Bridge.run'); return {}
  end
  local runnerLog = LrPathUtils.child(outDir, 'wai_runner.log')
  local prefs = LrPrefs.prefsForPlugin()
  local cmd
  if isWin() then
    cmd = string.format('cmd /c "%s --photo-list %s --output-dir %s --log-file %s"', quote(runner), quote(tmp), quote(outDir), quote(runnerLog))
  else
    cmd = string.format('%s --photo-list %s --output-dir %s --log-file %s', quote(runner), quote(tmp), quote(outDir), quote(runnerLog))
  end
  if prefs.generateCrops == false then cmd = cmd .. ' --no-crop' end
  if prefs.enableLogging then cmd = cmd .. ' --verbose' end
  Log.info('Exec: '..cmd)
  local rc = LrTasks.execute(cmd)
  Log.info('Runner exit: '..tostring(rc))
  if rc ~= 0 then
    LrDialogs.message('WildlifeAI','Runner failed, see log','error')
  end
  local results = {}
  for _,p in ipairs(photos) do
    local src = p:getRawMetadata('path')
    local jsonPath = LrPathUtils.replaceExtension(src, 'json')
    if not LrFileUtils.exists(jsonPath) then
      jsonPath = LrPathUtils.child(outDir, LrPathUtils.leafName(src)..'.json')
    end
    if LrFileUtils.exists(jsonPath) then
      local txt = LrFileUtils.readFile(jsonPath)
      local ok, data = pcall(json.decode, txt)
      if ok then
        results[src] = data
        Log.debug('Loaded '..jsonPath)
      else
        Log.error('JSON parse error '..jsonPath)
      end
    else
      Log.debug('No JSON for '..src)
    end
  end
  Log.leave(clk,'Bridge.run')
  return results
end

function M.runAsync(photos, callback)
  LrTasks.startAsyncTask(function()
    local results = M.run(photos)
    if callback then callback(results) end
  end)
end

return M