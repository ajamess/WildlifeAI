local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
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
  local rows={}
  for _,p in ipairs(photos) do
    local jsonPath = p:getPropertyForPlugin(_PLUGIN,'wai_jsonPath') or ''
    local crop = jsonPath:gsub('%.json$','_crop.jpg')
    if not LrFileUtils.exists(crop) then crop='' end
    rows[#rows+1]=f:row{
      spacing=f:control_spacing(),
      f:static_text{ title=p:getFormattedMetadata('fileName'), width_in_chars=35 },
      crop~='' and f:picture{ value=crop, width=200, height=120 } or f:static_text{ title='(no crop)' },
    }
  end
  LrDialogs.presentModalDialog{ title='WildlifeAI Review Crops', contents=f:scrolled_view{ width=800, height=600, f:column(rows) } }
  Log.info('Review dialog closed')
end)