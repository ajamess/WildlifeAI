local LrTasks=import'LrTasks';local LrFileUtils=import'LrFileUtils';local LrPathUtils=import'LrPathUtils';local LrLogger=import'LrLogger';local LrPrefs=import'LrPrefs';local json=require'utils/dkjson'
local logger=LrLogger('WildlifeAI');logger:enable('print')
local M={}
local function runner()
  local prefs=LrPrefs.prefsForPlugin()
  if WIN_ENV then return LrPathUtils.child(_PLUGIN.path, prefs.pythonBinaryWin)
  else return LrPathUtils.child(_PLUGIN.path, prefs.pythonBinaryMac) end
end
function M.runKestrel(photos)
  local tmp=LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'),'wai_paths.txt')
  local f=io.open(tmp,'w');for _,p in ipairs(photos) do f:write(p:getRawMetadata('path')..'\n') end f:close()
  local outDir=LrPathUtils.child(LrPathUtils.getStandardFilePath('pictures'),'.kestrel');LrFileUtils.createAllDirectories(outDir)
  local cmd=string.format('"%s" --photo-list "%s" --output-dir "%s"',runner(),tmp,outDir)
  logger:info('Exec: '..cmd);LrTasks.execute(cmd)
  local res={}
  for _,p in ipairs(photos) do
    local pth=p:getRawMetadata('path');local jp=LrPathUtils.replaceExtension(pth,'json')
    if not LrFileUtils.exists(jp) then jp=LrPathUtils.child(outDir,LrPathUtils.leafName(pth)..'.json') end
    if LrFileUtils.exists(jp) then
      local ok,data=pcall(function() return json.decode(LrFileUtils.readFile(jp)) end)
      if ok then data.json_path=jp;res[pth]=data end
    end
  end
  return res
end
return M