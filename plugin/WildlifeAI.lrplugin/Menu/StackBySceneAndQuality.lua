local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'

LrFunctionContext.callWithContext('WildlifeAI_StackBySceneAndQuality', function(context)
  LrTasks.startAsyncTask(function()
    local success, err = pcall(function()
      -- Get selected photos
      local catalog = LrApplication.activeCatalog()
      local photos = catalog:getTargetPhotos()
      
      if #photos == 0 then
        LrDialogs.message('No Photos Selected', 'Please select photos to stack.')
        return
      end
      
      -- Load the stacking dialog
      local StackingDialog = dofile( LrPathUtils.child(_PLUGIN.path, 'UI/StackingDialog.lua') )
      
      -- Show the dialog
      StackingDialog(context, photos)
    end)
    
    if not success then
      LrDialogs.message('Stacking Error', 'Failed to open stacking dialog: ' .. tostring(err), 'error')
    end
  end)
end)
