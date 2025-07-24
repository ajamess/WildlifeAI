local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )

LrFunctionContext.callWithContext('WAI_Review', function()
  local catalog = LrApplication.activeCatalog()
  local photos = catalog:getTargetPhotos()
  if #photos==0 then
    LrDialogs.message('WildlifeAI','Select one or more analyzed photos first.'); return
  end
  local f=LrView.osFactory()
  local props=LrBinding.makePropertyTable(context)
  local rows={}
  for _,p in ipairs(photos) do
    local jsonPath = p:getPropertyForPlugin(_PLUGIN,'wai_jsonPath') or ''
    local crop = jsonPath:gsub('%.json$','_crop.jpg')
    if not LrFileUtils.exists(crop) then crop='' end
    local key='r'..tostring(#rows+1)
    props[key]=tonumber(p:getPropertyForPlugin(_PLUGIN,'wai_rating') or 0)
    rows[#rows+1]=f:row{
      spacing=f:control_spacing(),
      f:static_text{ title=p:getFormattedMetadata('fileName'), width_in_chars=35 },
      crop~='' and f:picture{ value=crop, width=200, height=120 } or f:static_text{ title='(no crop)' },
      f:popup_menu{ items={{title='0',value=0},{title='1',value=1},{title='2',value=2},{title='3',value=3},{title='4',value=4},{title='5',value=5}}, value=LrView.bind(key) }
    }
  end
  LrDialogs.presentModalDialog{ title='WildlifeAI Review Crops', contents=f:scrolled_view{ width=800, height=600, f:column(rows) } }
  catalog:withWriteAccessDo('WAI rate crops', function()
    local idx=1
    for _,p in ipairs(photos) do
      local key='r'..tostring(idx)
      p:setPropertyForPlugin(_PLUGIN,'wai_rating', tostring(props[key] or 0))
      idx=idx+1
    end
  end,{timeout=60})
  Log.info('Review dialog closed')
end)