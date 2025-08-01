-- WildlifeAI Review Crops - Simplified and Robust Implementation
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrTasks = import 'LrTasks'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )

LrTasks.startAsyncTask(function()
  LrFunctionContext.callWithContext('WAI_Review', function(context)
        local catalog = LrApplication.activeCatalog()
        local photos = catalog:getTargetPhotos()
        
        if #photos == 0 then
          LrDialogs.message('WildlifeAI','Select one or more analyzed photos first.')
          return
        end
        
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)
        
        -- Initialize photo data
        local photoData = {}
        local changes = {}
        
        for i, photo in ipairs(photos) do
          local photoPath = photo:getRawMetadata('path')
          local photoDir = LrPathUtils.parent(photoPath)
          local filename = LrPathUtils.leafName(photoPath)
          local filenameNoExt = LrPathUtils.removeExtension(filename)
          local outputDir = LrPathUtils.child(photoDir, '.wildlifeai')
          local cropPath = LrPathUtils.child(outputDir, filenameNoExt .. '_crop.jpg')
          
          if not LrFileUtils.exists(cropPath) then
            cropPath = nil
          end
          
          -- Get current metadata values
          local rating = photo:getRawMetadata('rating') or 0
          local pickStatus = photo:getRawMetadata('pickStatus') or 0
          local colorLabel = photo:getRawMetadata('colorNameForLabel') or 'none'
          
          photoData[i] = {
            photo = photo,
            filename = filename,
            cropPath = cropPath,
            originalRating = rating,
            originalPickStatus = pickStatus,
            originalColorLabel = colorLabel
          }
          
          -- Create property keys for this photo
          props['rating_' .. i] = rating
          props['pickStatus_' .. i] = pickStatus
          props['colorLabel_' .. i] = colorLabel
          
          changes[i] = false
        end
        
        props.hasAnyChanges = false
        
        -- Function to check if a photo has changes
        local function updatePhotoChanges(index)
          local data = photoData[index]
          local hasChanges = (props['rating_' .. index] ~= data.originalRating) or
                            (props['pickStatus_' .. index] ~= data.originalPickStatus) or
                            (props['colorLabel_' .. index] ~= data.originalColorLabel)
          
          changes[index] = hasChanges
          
          -- Update overall changes flag
          props.hasAnyChanges = false
          for i = 1, #photos do
            if changes[i] then
              props.hasAnyChanges = true
              break
            end
          end
        end
        
        -- Add observers to track changes
        for i = 1, #photos do
          props:addObserver('rating_' .. i, function() updatePhotoChanges(i) end)
          props:addObserver('pickStatus_' .. i, function() updatePhotoChanges(i) end)
          props:addObserver('colorLabel_' .. i, function() updatePhotoChanges(i) end)
        end
        
        -- Create a simple row for each photo
        local photoRows = {}
        
        for i, data in ipairs(photoData) do
          local photoRow = f:group_box {
            title = data.filename,
            fill_horizontal = 1,
            
            f:row {
              spacing = f:control_spacing(),
              fill_horizontal = 1,
              
              -- Crop image section
              f:column {
                spacing = 5,
                width = 200,
                
                data.cropPath and f:picture {
                  value = data.cropPath,
                  width = 190,
                  height = 120
                } or f:static_text {
                  title = 'No crop available',
                  alignment = 'center',
                  width = 190,
                  height = 120
                }
              },
              
              f:spacer { width = 10 },
              
              -- Metadata controls section
              f:column {
                spacing = 10,
                fill_horizontal = 1,
                
                -- Pick/Reject flags
                f:row {
                  spacing = 10,
                  
                  f:static_text { title = 'Flag:', width = 50 },
                  
                  f:radio_button {
                    title = 'Reject',
                    value = LrView.bind('pickStatus_' .. i),
                    checked_value = -1
                  },
                  
                  f:radio_button {
                    title = 'Unflag',
                    value = LrView.bind('pickStatus_' .. i),
                    checked_value = 0
                  },
                  
                  f:radio_button {
                    title = 'Pick',
                    value = LrView.bind('pickStatus_' .. i),
                    checked_value = 1
                  }
                },
                
                -- Rating slider
                f:row {
                  spacing = 10,
                  
                  f:static_text { title = 'Rating:', width = 50 },
                  
                  f:slider {
                    value = LrView.bind('rating_' .. i),
                    min = 0,
                    max = 5,
                    integral = true,
                    width = 150
                  },
                  
                  f:static_text {
                    title = LrView.bind {
                      key = 'rating_' .. i,
                      transform = function(rating)
                        return string.rep('★', rating) .. string.rep('☆', 5 - rating)
                      end
                    },
                    font = '<system/14>',
                    width = 100
                  }
                },
                
                -- Color Label dropdown
                f:row {
                  spacing = 10,
                  
                  f:static_text { title = 'Color:', width = 50 },
                  
                  f:popup_menu {
                    value = LrView.bind('colorLabel_' .. i),
                    items = {
                      { title = 'None', value = 'none' },
                      { title = 'Red', value = 'red' },
                      { title = 'Yellow', value = 'yellow' },
                      { title = 'Green', value = 'green' },
                      { title = 'Blue', value = 'blue' },
                      { title = 'Purple', value = 'purple' }
                    },
                    width = 100
                  }
                }
              }
            }
          }
          
          table.insert(photoRows, photoRow)
        end
        
        -- Main dialog content
        local content = f:column {
          spacing = f:control_spacing(),
          fill_horizontal = 1,
          
          -- Header
          f:row {
            fill_horizontal = 1,
            
            f:static_text {
              title = 'Review Crops - ' .. #photos .. ' photos',
              font = '<system/bold>'
            },
            
            f:spacer { fill_horizontal = 1 },
            
            f:static_text {
              title = LrView.bind {
                key = 'hasAnyChanges',
                transform = function(hasChanges)
                  return hasChanges and 'Changes pending' or 'No changes'
                end
              },
              font = '<system/bold>'
            }
          },
          
          f:separator { fill_horizontal = 1 },
          
          -- Scrollable photo list
          f:scrolled_view {
            width = 800,
            height = 500,
            horizontal_scroller = false,
            vertical_scroller = true,
            
            f:column {
              spacing = 10,
              fill_horizontal = 1,
              unpack(photoRows)
            }
          }
        }
        
        -- Present the dialog
        local result = LrDialogs.presentModalDialog {
          title = 'WildlifeAI Review Crops',
          contents = content,
          actionVerb = 'Save Changes',
          cancelVerb = 'Cancel',
          resizable = true
        }
        
        -- Save changes if user clicked Save
        if result == 'ok' then
          catalog:withWriteAccessDo('WAI save crop reviews', function()
            local changedCount = 0
            
            for i, data in ipairs(photoData) do
              if changes[i] then
                local photo = data.photo
                
                -- Update rating
                local newRating = props['rating_' .. i]
                if newRating ~= data.originalRating then
                  photo:setRawMetadata('rating', newRating)
                  Log.info('Updated rating for ' .. data.filename .. ': ' .. newRating)
                end
                
                -- Update pick status
                local newPickStatus = props['pickStatus_' .. i]
                if newPickStatus ~= data.originalPickStatus then
                  photo:setRawMetadata('pickStatus', newPickStatus)
                  Log.info('Updated pick status for ' .. data.filename .. ': ' .. newPickStatus)
                end
                
                -- Update color label
                local newColorLabel = props['colorLabel_' .. i]
                if newColorLabel ~= data.originalColorLabel then
                  if newColorLabel == 'none' then
                    photo:setRawMetadata('colorNameForLabel', nil)
                  else
                    photo:setRawMetadata('colorNameForLabel', newColorLabel)
                  end
                  Log.info('Updated color label for ' .. data.filename .. ': ' .. newColorLabel)
                end
                
                changedCount = changedCount + 1
              end
            end
            
            Log.info('Saved changes to ' .. changedCount .. ' of ' .. #photos .. ' photos')
          end, {timeout = 60})
        end
        
        Log.info('Review dialog closed with result: ' .. tostring(result))
  end)
end)
