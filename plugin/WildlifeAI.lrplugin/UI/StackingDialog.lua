-- WildlifeAI Stacking Dialog
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrPrefs = import 'LrPrefs'
local LrBinding = import 'LrBinding'
local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'
local LrProgressScope = import 'LrProgressScope'

return function(context, photos)
  local f = LrView.osFactory()
  local prefs = LrPrefs.prefsForPlugin()
  local bind = LrView.bind
  
  -- Set stacking defaults
  if prefs.stackingMethod == nil then prefs.stackingMethod = 'scene_then_quality' end
  if prefs.collapseStacks == nil then prefs.collapseStacks = true end
  if prefs.qualityOrder == nil then prefs.qualityOrder = 'highest_first' end
  if prefs.includeUnprocessed == nil then prefs.includeUnprocessed = false end
  if prefs.minStackSize == nil then prefs.minStackSize = 2 end
  prefs.minQualityThreshold = prefs.minQualityThreshold or 0
  
  -- Create validation properties
  local props = LrBinding.makePropertyTable(context)
  props.photoCount = #photos
  props.processedCount = 0
  
  -- Count processed photos
  for _, photo in ipairs(photos) do
    local processed = photo:getPropertyForPlugin(_PLUGIN, 'wai_processed')
    if processed == 'true' then
      props.processedCount = props.processedCount + 1
    end
  end
  
  local function createStackingMethodItems()
    return {
      { title = 'Scene Count, then Quality (recommended)', value = 'scene_then_quality' },
      { title = 'Quality only', value = 'quality_only' },
      { title = 'Species, then Quality', value = 'species_then_quality' },
      { title = 'Species, then Scene, then Quality', value = 'species_scene_quality' },
      { title = 'Rating, then Quality', value = 'rating_then_quality' }
    }
  end
  
  local function createQualityOrderItems()
    return {
      { title = 'Highest Quality First (recommended)', value = 'highest_first' },
      { title = 'Lowest Quality First', value = 'lowest_first' }
    }
  end
  
  local function createMinStackSizeItems()
    return {
      { title = '2 photos', value = 2 },
      { title = '3 photos', value = 3 },
      { title = '4 photos', value = 4 },
      { title = '5 photos', value = 5 }
    }
  end
  
  -- Main dialog content
  local c = f:column {
    bind_to_object = prefs,
    spacing = f:control_spacing(),
    
    f:static_text { 
      title = 'Stack Photos Based on Scene and Quality', 
      font = '<system/bold>',
      fill_horizontal = 1 
    },
    
    f:spacer { height = 10 },
    
    -- Summary
    f:group_box {
      title = 'Selection Summary',
      fill_horizontal = 1,
      
      f:column {
        f:static_text {
          title = bind {
            key = 'photoCount',
            object = props,
            transform = function(count)
              return string.format('Total Photos Selected: %d', count)
            end
          }
        },
        f:static_text {
          title = bind {
            key = 'processedCount',
            object = props,
            transform = function(count)
              return string.format('Processed by WildlifeAI: %d', count)
            end
          }
        }
      }
    },
    
    f:spacer { height = 10 },
    
    -- Stacking Method
    f:group_box {
      title = 'Stacking Method',
      fill_horizontal = 1,
      spacing = f:control_spacing(),
      
      f:row {
        f:static_text { 
          title = 'Stack by:', 
          width = 80,
          alignment = 'right'
        },
        f:popup_menu {
          value = bind('stackingMethod'),
          items = createStackingMethodItems(),
          immediate = true,
          fill_horizontal = 1
        }
      },
      
      f:spacer { height = 8 },
      
      f:static_text {
        title = bind {
          key = 'stackingMethod',
          transform = function(method)
            if method == 'scene_then_quality' then
              return 'Groups photos by scene count, then sorts by quality within each scene group.'
            elseif method == 'quality_only' then
              return 'Creates stacks based purely on quality ranges (ignoring scene information).'
            elseif method == 'species_then_quality' then
              return 'Groups by detected species first, then by quality within each species.'
            elseif method == 'species_scene_quality' then
              return 'Groups by species, then scene count, then quality (most detailed grouping).'
            elseif method == 'rating_then_quality' then
              return 'Groups by star rating first, then by quality within each rating.'
            else
              return 'Select a stacking method to see description.'
            end
          end
        },
        font = '<system/small>',
        fill_horizontal = 1
      }
    },
    
    f:spacer { height = 10 },
    
    -- Quality Options
    f:group_box {
      title = 'Quality Options',
      fill_horizontal = 1,
      spacing = f:control_spacing(),
      
      f:row {
        f:static_text { 
          title = 'Quality Order:', 
          width = 100,
          alignment = 'right'
        },
        f:popup_menu {
          value = bind('qualityOrder'),
          items = createQualityOrderItems(),
          immediate = true,
          width = 200
        }
      },
      
      f:spacer { height = 8 },
      
      f:row {
        f:static_text { 
          title = 'Min Quality:', 
          width = 100,
          alignment = 'right'
        },
        f:edit_field {
          value = bind('minQualityThreshold'),
          width_in_chars = 8,
          immediate = true
        },
        f:static_text { 
          title = '(0-100, exclude photos below this quality)',
          font = '<system/small>'
        }
      }
    },
    
    f:spacer { height = 10 },
    
    -- Stack Options
    f:group_box {
      title = 'Stack Options',
      fill_horizontal = 1,
      spacing = f:control_spacing(),
      
      f:row {
        f:static_text { 
          title = 'Min Stack Size:', 
          width = 100,
          alignment = 'right'
        },
        f:popup_menu {
          value = bind('minStackSize'),
          items = createMinStackSizeItems(),
          immediate = true,
          width = 120
        },
        f:static_text { 
          title = '(don\'t create stacks smaller than this)',
          font = '<system/small>'
        }
      },
      
      f:spacer { height = 8 },
      
      f:checkbox { 
        title = 'Collapse all stacks after creation', 
        value = bind('collapseStacks') 
      },
      
      f:checkbox { 
        title = 'Include unprocessed photos in stacks', 
        value = bind('includeUnprocessed') 
      }
    },
    
    f:spacer { height = 10 },
    
    -- Warning
    f:group_box {
      title = 'Warning',
      fill_horizontal = 1,
      
      f:static_text {
        title = 'This operation will modify existing stacks and cannot be undone. Make sure to backup your catalog before proceeding.',
        font = '<system/small>',
        fill_horizontal = 1
      }
    }
  }
  
  local result = LrDialogs.presentModalDialog { 
    title = 'Stack by Scene and Quality', 
    contents = c,
    actionVerb = 'Create Stacks',
    cancelVerb = 'Cancel',
    save_frame = 'WildlifeAI_StackingDialog'
  }
  
  if result == 'ok' then
    -- Validate inputs
    local minQuality = tonumber(prefs.minQualityThreshold) or 0
    if minQuality < 0 or minQuality > 100 then
      LrDialogs.message('Invalid Quality Threshold', 'Quality threshold must be between 0 and 100.')
      return false
    end
    
    -- Perform stacking operation
    LrTasks.startAsyncTask(function()
      local progressScope = LrProgressScope {
        title = 'Creating Photo Stacks',
        caption = 'Creating photo stacks...'
      }
      
      local catalog = LrApplication.activeCatalog()
      
      catalog:withWriteAccessDo('Stack Photos', function()
        -- Collect photo metadata (photos already provided as parameter)
        local photoData = {}
        
        for i, photo in ipairs(photos) do
          if progressScope then
            progressScope:setPortionComplete(i / #photos * 0.3) -- 30% for data collection
          end
          
          local processed = photo:getPropertyForPlugin(_PLUGIN, 'wai_processed')
          local include = (processed == 'true') or prefs.includeUnprocessed
          
          if include then
            local quality = tonumber(photo:getPropertyForPlugin(_PLUGIN, 'wai_quality')) or 0
            local rating = tonumber(photo:getPropertyForPlugin(_PLUGIN, 'wai_rating')) or 0
            local sceneCount = tonumber(photo:getPropertyForPlugin(_PLUGIN, 'wai_sceneCount')) or 1
            local species = photo:getPropertyForPlugin(_PLUGIN, 'wai_detectedSpecies') or 'Unknown'
            
            if quality >= minQuality then
              table.insert(photoData, {
                photo = photo,
                quality = quality,
                rating = rating,
                sceneCount = sceneCount,
                species = species,
                processed = processed == 'true'
              })
            end
          end
        end
        
        -- Group photos based on stacking method
        local groups = {}
        
        for i, data in ipairs(photoData) do
          if progressScope then
            progressScope:setPortionComplete(0.3 + (i / #photoData * 0.4)) -- 40% for grouping
          end
          
          local groupKey
          local method = prefs.stackingMethod
          
          if method == 'scene_then_quality' then
            groupKey = string.format('scene_%d', data.sceneCount)
          elseif method == 'quality_only' then
            local qualityBucket = math.floor(data.quality / 20) -- 0-19, 20-39, etc.
            groupKey = string.format('quality_%d', qualityBucket)
          elseif method == 'species_then_quality' then
            groupKey = string.format('species_%s', data.species)
          elseif method == 'species_scene_quality' then
            groupKey = string.format('species_%s_scene_%d', data.species, data.sceneCount)
          elseif method == 'rating_then_quality' then
            groupKey = string.format('rating_%d', data.rating)
          end
          
          if not groups[groupKey] then
            groups[groupKey] = {}
          end
          table.insert(groups[groupKey], data)
        end
        
        -- Sort and create stacks
        local stackCount = 0
        local groupIndex = 0
        local totalGroups = 0
        for _ in pairs(groups) do totalGroups = totalGroups + 1 end
        
        for groupKey, groupPhotos in pairs(groups) do
          groupIndex = groupIndex + 1
          if progressScope then
            progressScope:setPortionComplete(0.7 + (groupIndex / totalGroups * 0.3)) -- Final 30% for stacking
          end
          
          if #groupPhotos >= prefs.minStackSize then
            -- Sort by quality
            table.sort(groupPhotos, function(a, b)
              if prefs.qualityOrder == 'highest_first' then
                return a.quality > b.quality
              else
                return a.quality < b.quality
              end
            end)
            
            -- Create stack
            local photosToStack = {}
            for _, data in ipairs(groupPhotos) do
              table.insert(photosToStack, data.photo)
            end
            
            if #photosToStack >= 2 then
              -- Remove any existing stacks first
              for _, photo in ipairs(photosToStack) do
                if photo:getRawMetadata('isInStackInFolder') then
                  photo:removeFromStack()
                end
              end
              
              -- Create new stack with highest quality photo on top
              local topPhoto = photosToStack[1]
              -- Verify the top photo is a valid LrPhoto instance
              local isPhoto = false
              if topPhoto then
                local ok = pcall(function() topPhoto:getRawMetadata('uuid') end)
                isPhoto = ok and type(topPhoto.addToStack) == 'function'
              end

              if isPhoto then
                for i = 2, #photosToStack do
                  topPhoto:addToStack(photosToStack[i])
                end

                -- Collapse if requested
                if prefs.collapseStacks and type(topPhoto.setStackCollapsed) == 'function' then
                  topPhoto:setStackCollapsed(true)
                end

                stackCount = stackCount + 1
              else
                LrDialogs.message('Stacking Error', 'Cannot create stack: invalid top photo.')
              end
            end
          end
        end
        
        if progressScope then
          progressScope:setPortionComplete(1.0)
          progressScope:done()
        end
        LrDialogs.message('Stacking Complete', 
          string.format('Created %d stacks from %d photos using method: %s', 
            stackCount, #photoData, prefs.stackingMethod), 'info')
      end)
    end)
  end
  
  return result
end
