local LrTasks      = import 'LrTasks'
local LrFileUtils  = import 'LrFileUtils'
local LrPathUtils  = import 'LrPathUtils'
local LrPrefs      = import 'LrPrefs'
local json = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/dkjson.lua') )
local Log  = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )
local M = {}
local function isWindows() return LrPathUtils.separator == '\\' end
local function chooseRunner()
  local prefs = LrPrefs.prefsForPlugin()
  local default = isWindows() and 'bin/win/kestrel_runner.exe' or 'bin/mac/kestrel_runner'
  local configured = isWindows() and prefs.pythonBinaryWin or prefs.pythonBinaryMac
  local candidates = { configured, default }
  for _,rel in ipairs(candidates) do
    if rel and rel ~= '' then
      local full = LrPathUtils.child(_PLUGIN.path, rel)
      if LrFileUtils.exists(full) then return full end
    end
  end
  return LrPathUtils.child(_PLUGIN.path, default)
end
local function quote(path)
  if isWindows() then return '"'..path..'"' else return "'"..path.."'" end
end
function M.run(photos)
  local clk = Log.enter('Bridge.run')
  local tmp = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_paths.txt')
  local f = assert(io.open(tmp, 'w'))
  for _,p in ipairs(photos) do f:write(p:getRawMetadata('path')..'\n') end
  f:close()
  local outDir = LrPathUtils.child(LrPathUtils.getStandardFilePath('pictures'), '.kestrel')
  LrFileUtils.createAllDirectories(outDir)
  local runner = chooseRunner()
  if not LrFileUtils.exists(runner) then Log.error('Runner missing: '..runner); Log.leave(clk,'Bridge.run'); return {} end
  local runnerLog = LrPathUtils.child(outDir, 'kestrel_runner.log')
  -- Precreate log to avoid read errors
  local lf = io.open(runnerLog,'w'); if lf then lf:write('start\n'); lf:close() end
  local cmd
  if isWindows() then
    cmd = string.format('cmd /c "%s --photo-list %s --output-dir %s --log-file %s"',
      quote(runner), quote(tmp), quote(outDir), quote(runnerLog))
  else
    cmd = string.format('%s --photo-list %s --output-dir %s --log-file %s',
      quote(runner), quote(tmp), quote(outDir), quote(runnerLog))
  end
  Log.info('Exec: '..cmd)
  local rc = LrTasks.execute(cmd)
  Log.info('Runner exit code: '..tostring(rc))
  if LrFileUtils.exists(runnerLog) then
    local text = LrFileUtils.readFile(runnerLog) or ''
    if #text > 0 then Log.debug('Runner log:\n'..text) end
  else
    Log.debug('Runner log not found')
  end
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
      if ok then data.json_path = jsonPath; results[path] = data; Log.debug('Loaded JSON: '..jsonPath)
      else Log.error('JSON parse fail: '..jsonPath) end
    else
      Log.debug('No JSON for '..path)
    end
  end
  Log.leave(clk, 'Bridge.run')
  return results
end
return M
