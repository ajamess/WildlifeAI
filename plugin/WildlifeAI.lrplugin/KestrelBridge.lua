local LrTasks      = import 'LrTasks'
local LrFileUtils  = import 'LrFileUtils'
local LrPathUtils  = import 'LrPathUtils'
local LrPrefs      = import 'LrPrefs'

local json = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/dkjson.lua' ) )
local Log  = dofile( LrPathUtils.child( _PLUGIN.path, 'utils/Log.lua' ) )

local M = {}
local function runnerPath()
  local prefs = LrPrefs.prefsForPlugin()
  local rel = WIN_ENV and prefs.pythonBinaryWin or prefs.pythonBinaryMac
  if not rel or rel == '' then
    rel = WIN_ENV and 'bin/win/kestrel_runner.exe' or 'bin/mac/kestrel_runner'
  end
  local full = LrPathUtils.child(_PLUGIN.path, rel)
  Log.debug('Runner resolved: '..tostring(full))
  return full
end
local function quote(p)
  if WIN_ENV then return '"'..p..'"' else return "'"..p.."'" end
end
function M.run(photos)
  Log.info('run() on '..#photos..' photos')
  local tmp = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_paths.txt')
  local f = assert(io.open(tmp, 'w'))
  for _,p in ipairs(photos) do f:write(p:getRawMetadata('path')..'\n') end
  f:close()

  local outDir = LrPathUtils.child(LrPathUtils.getStandardFilePath('pictures'), '.kestrel')
  LrFileUtils.createAllDirectories(outDir)

  local runner = runnerPath()
  if not LrFileUtils.exists(runner) then
    Log.error('Runner missing: '..runner)
    return {}
  end
  local runLog = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'wai_runner_stdout.txt')
  local cmd
  if WIN_ENV then
    cmd = string.format('%s --photo-list %s --output-dir %s 1> %s 2>&1',
      quote(runner), quote(tmp), quote(outDir), quote(runLog))
  else
    cmd = string.format('%s --photo-list %s --output-dir %s > %s 2>&1',
      quote(runner), quote(tmp), quote(outDir), quote(runLog))
  end
  Log.info('Exec: '..cmd)
  local rc = LrTasks.execute(cmd)
  Log.info('Exit code: '..tostring(rc))
  local out = LrFileUtils.readFile(runLog) or ''
  if #out > 0 then Log.debug('Runner output:\n'..out) end

  local results = {}
  for _,p in ipairs(photos) do
    local src = p:getRawMetadata('path')
    local jsonPath = LrPathUtils.replaceExtension(src, 'json')
    if not LrFileUtils.exists(jsonPath) then
      local leaf = LrPathUtils.leafName(src)..'.json'
      jsonPath = LrPathUtils.child(outDir, leaf)
    end
    if LrFileUtils.exists(jsonPath) then
      local content = LrFileUtils.readFile(jsonPath)
      local ok, data = pcall(json.decode, content)
      if ok then
        data.json_path = jsonPath
        results[src] = data
        Log.debug('Loaded JSON: '..jsonPath)
      else
        Log.error('JSON parse fail '..jsonPath)
      end
    else
      Log.debug('No JSON for '..src)
    end
  end
  Log.info('run() done')
  return results
end
return M
