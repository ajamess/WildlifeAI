local LrTasks      = import 'LrTasks'
local LrFileUtils  = import 'LrFileUtils'
local LrPathUtils  = import 'LrPathUtils'
local LrPrefs      = import 'LrPrefs'
local json = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/dkjson.lua') )
local Log  = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local M = {}
local function isWindows() return LrPathUtils.separator == '\\' end
local function runnerPath()
  local prefs = LrPrefs.prefsForPlugin()
  local rel = isWindows() and prefs.pythonBinaryWin or prefs.pythonBinaryMac
  if not rel or rel == '' then
    rel = isWindows() and 'bin/win/kestrel_runner.exe' or 'bin/mac/kestrel_runner'
  end
  local full = LrPathUtils.child(_PLUGIN.path, rel)
  Log.debug('Runner path: '..tostring(full))
  return full
end
local function quote(path)
  if isWindows() then return '"'..path..'"' else return "'"..path.."'" end
end
function M.run(photos)
  local clk = Log.enter('Bridge.run')
  local tmp = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_paths.txt')
  local f = assert(io.open(tmp, 'w'))
  for _,p in ipairs(photos) do
    f:write(p:getRawMetadata('path')..'\n')
  end
  f:close()
  local outDir = LrPathUtils.child(LrPathUtils.getStandardFilePath('pictures'), '.kestrel')
  LrFileUtils.createAllDirectories(outDir)
  local runner = runnerPath()
  if not LrFileUtils.exists(runner) then
    Log.error('Runner missing: '..runner)
    Log.leave(clk, 'Bridge.run')
    return {}
  end
  local runLog = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_runner_stdout.txt')
  if LrFileUtils.exists(runLog) then LrFileUtils.delete(runLog) end
  local cmd
  if isWindows() then
    cmd = string.format('%s --photo-list %s --output-dir %s 1> %s 2>&1',
      quote(runner), quote(tmp), quote(outDir), quote(runLog))
  else
    cmd = string.format('%s --photo-list %s --output-dir %s > %s 2>&1',
      quote(runner), quote(tmp), quote(outDir), quote(runLog))
  end
  Log.info('Exec: '..cmd)
  local rc = LrTasks.execute(cmd)
  Log.info('Runner exit code: '..tostring(rc))
  local runnerOutput = LrFileUtils.readFile(runLog) or ''
  if #runnerOutput > 0 then Log.debug('Runner output:\n'..runnerOutput) end
  local results = {}
  for _,p in ipairs(photos) do
    local path = p:getRawMetadata('path')
    local jsonPath = LrPathUtils.replaceExtension(path, 'json')
    if not LrFileUtils.exists(jsonPath) then
      local leaf = LrPathUtils.leafName(path)..'.json'
      jsonPath = LrPathUtils.child(outDir, leaf)
    end
    if LrFileUtils.exists(jsonPath) then
      local content = LrFileUtils.readFile(jsonPath)
      local ok, data = pcall(json.decode, content)
      if ok then
        data.json_path = jsonPath
        results[path] = data
        Log.debug('Loaded JSON: '..jsonPath)
      else
        Log.error('JSON parse fail: '..jsonPath)
      end
    else
      Log.debug('No JSON for '..path)
    end
  end
  Log.leave(clk, 'Bridge.run')
  return results
end
return M
