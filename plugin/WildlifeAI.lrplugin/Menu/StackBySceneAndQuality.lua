local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'

-- CRITICAL FIX: Get photos in synchronous context first
local catalog = LrApplication.activeCatalog()
local photos = {}

catalog:withReadAccessDo(function()
  photos = catalog:getTargetPhotos()
end)

if #photos == 0 then
  LrDialogs.message('No Photos Selected', 'Please select photos to stack.')
  return
end

-- Now pass the photos to the async task and dialog
LrTasks.startAsyncTask(function()
  local success, err = pcall(function()
    -- Create a new function context for the stacking dialog
    LrFunctionContext.callWithContext('WildlifeAI_StackBySceneAndQuality', function(context)
      -- Load the stacking dialog
      local StackingDialog = dofile( LrPathUtils.child(_PLUGIN.path, 'UI/StackingDialog.lua') )
      
      -- Show the dialog with pre-extracted photos
      StackingDialog(context, photos)
    end)
  end)
  
  if not success then
    LrDialogs.message('Stacking Error', 'Failed to open stacking dialog: ' .. tostring(err), 'error')
  end
end)
