-- Manual test script for StackingDialog invalid top photo handling
-- Simulates the stacking logic with an invalid top photo to ensure
-- the dialog reports an error instead of failing.

local function simulateStackCreation()
  -- Stub dialog to capture messages
  local LrDialogs = {
    message = function(title, msg)
      print(string.format("%s: %s", title, msg))
    end,
  }

  -- Preferences stub
  local prefs = { collapseStacks = true }

  -- Photos array where the first entry lacks addToStack
  local photosToStack = {
    {}, -- Invalid top photo
    { id = 2 },
    { id = 3 },
  }

  local topPhoto = photosToStack[1]
  local isPhoto = false
  if topPhoto then
    local ok = pcall(function() return topPhoto:getRawMetadata('uuid') end)
    isPhoto = ok and type(topPhoto.addToStack) == 'function'
  end

  if isPhoto then
    for i = 2, #photosToStack do
      topPhoto:addToStack(photosToStack[i])
    end
    if prefs.collapseStacks and type(topPhoto.setStackCollapsed) == 'function' then
      topPhoto:setStackCollapsed(true)
    end
  else
    LrDialogs.message('Stacking Error', 'Cannot create stack: invalid top photo.')
  end
end

simulateStackCreation()
