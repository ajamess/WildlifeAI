local LrApplication=import'LrApplication';local LrDialogs=import'LrDialogs'
local M={}
function M.stackByScene(photos)
  local catalog=LrApplication.activeCatalog()
  photos=photos or catalog:getTargetPhotos()
  if #photos==0 then LrDialogs.message('WildlifeAI','No photos selected to stack.');return end
  local groups={}
  for _,p in ipairs(photos) do
    local sc=tonumber(p:getPropertyForPlugin(_PLUGIN,'wai_sceneCount') or '0') or 0
    groups[sc]=groups[sc] or {};table.insert(groups[sc],p)
  end
  catalog:withWriteAccessDo('WildlifeAI Stack',function()
    for _,arr in pairs(groups) do
      table.sort(arr,function(a,b)
        return (tonumber(a:getPropertyForPlugin(_PLUGIN,'wai_quality') or '0') or 0) > (tonumber(b:getPropertyForPlugin(_PLUGIN,'wai_quality') or '0') or 0)
      end)
      local top=arr[1];for i=2,#arr do catalog:createPhotoStack(top,arr[i]) end
    end
  end)
  LrDialogs.message('WildlifeAI','Stacking complete.')
end
return M