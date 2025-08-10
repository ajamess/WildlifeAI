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

  -- Photos array where the first entry is invalid (nil)
  local photosToStack = {
    nil, -- Invalid top photo
    { id = 2 },
    { id = 3 },
  }

  local topPhoto = photosToStack[1]

  if topPhoto then
    for i = 2, #photosToStack do
      -- Simulate catalog stacking call
      print(string.format("Stacking photo %s under top %s", photosToStack[i].id, topPhoto.id))
    end
    if prefs.collapseStacks and type(topPhoto.setStackCollapsed) == 'function' then
      topPhoto:setStackCollapsed(true)
    end
  else
    LrDialogs.message('Stacking Error', 'Cannot create stack: invalid top photo.')
  end
end

simulateStackCreation()
