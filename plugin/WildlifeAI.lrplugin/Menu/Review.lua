-- WildlifeAI Review Crops - Filmstrip style interface
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrTasks = import 'LrTasks'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )

-- Helper to safely set a property
local function setProp(props, key, value)
  props[key] = value
  props:notifyObservers(key)
end

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

    local photoData = {}
    local changes = {}

    for i, photo in ipairs(photos) do
      local photoPath = photo:getRawMetadata('path')
      local photoDir = LrPathUtils.parent(photoPath)
      local filename = LrPathUtils.leafName(photoPath)
      local filenameNoExt = LrPathUtils.removeExtension(filename)
      local outputDir = LrPathUtils.child(photoDir, '.wildlifeai')
      local cropPath = LrPathUtils.child(outputDir, filenameNoExt .. '_crop.jpg')
      if not LrFileUtils.exists(cropPath) then cropPath = nil end

      local rating = photo:getRawMetadata('rating') or 0
      local pickStatus = photo:getRawMetadata('pickStatus') or 0
      local colorLabel = photo:getRawMetadata('colorNameForLabel') or 'none'

      photoData[i] = {
        photo = photo,
        filename = filename,
        cropPath = cropPath,
        originalRating = rating,
        originalPickStatus = pickStatus,
        originalColorLabel = colorLabel,
        rating = rating,
        pickStatus = pickStatus,
        colorLabel = colorLabel
      }
      changes[i] = false
    end

    props.currentIndex = 1
    props.hasAnyChanges = false
    props.rating = photoData[1].rating
    props.pickStatus = photoData[1].pickStatus
    props.colorLabel = photoData[1].colorLabel

    local function updateChange(idx)
      local d = photoData[idx]
      changes[idx] = (d.rating ~= d.originalRating) or
                     (d.pickStatus ~= d.originalPickStatus) or
                     (d.colorLabel ~= d.originalColorLabel)
      props.hasAnyChanges = false
      for _,c in ipairs(changes) do
        if c then props.hasAnyChanges = true break end
      end
    end

    local function loadCurrent()
      local d = photoData[props.currentIndex]
      if not d then return end
      setProp(props, 'rating', d.rating)
      setProp(props, 'pickStatus', d.pickStatus)
      setProp(props, 'colorLabel', d.colorLabel)
    end

    props:addObserver('rating', function()
      local idx = props.currentIndex
      photoData[idx].rating = props.rating
      updateChange(idx)
    end)
    props:addObserver('pickStatus', function()
      local idx = props.currentIndex
      photoData[idx].pickStatus = props.pickStatus
      updateChange(idx)
    end)
    props:addObserver('colorLabel', function()
      local idx = props.currentIndex
      photoData[idx].colorLabel = props.colorLabel
      updateChange(idx)
    end)
    props:addObserver('currentIndex', loadCurrent)

    -- Build thumbnails
    local thumbs = {}
    for i, data in ipairs(photoData) do
      local thumb = data.cropPath and f:picture {
        value = data.cropPath,
        width = 100,
        height = 70,
        mouse_down = function() setProp(props,'currentIndex',i) end
      } or f:static_text {
        title = 'No crop',
        width = 100,
        height = 70,
        mouse_down = function() setProp(props,'currentIndex',i) end
      }
      table.insert(thumbs, thumb)
    end

    local filmstrip = f:scrolled_view {
      width = 800,
      height = 80,
      horizontal_scroller = true,
      vertical_scroller = false,
      f:row { spacing = 5, unpack(thumbs) }
    }

    local preview = f:picture {
      value = LrView.bind {
        keys = { 'currentIndex' },
        object = props,
        transform = function(idx)
          return photoData[idx] and photoData[idx].cropPath
        end
      },
      width = 780,
      height = 520,
      fill_color = LrView.bind {
        keys = { 'currentIndex' },
        object = props,
        transform = function(idx)
          return changes[idx] and {0.2,0.3,0.2} or {0,0,0}
        end
      }
    }

    -- Metadata controls for current photo
    local controls = f:column {
      spacing = f:control_spacing(),

      f:row {
        spacing = 10,
        f:static_text { title = 'Flag:', width = 50 },
        f:radio_button { title='Reject', value=LrView.bind('pickStatus'), checked_value=-1 },
        f:radio_button { title='Unflag', value=LrView.bind('pickStatus'), checked_value=0 },
        f:radio_button { title='Pick',   value=LrView.bind('pickStatus'), checked_value=1 }
      },

      f:row {
        spacing = 10,
        f:static_text { title = 'Rating:', width = 50 },
        f:slider { value=LrView.bind('rating'), min=0, max=5, integral=true, width=150 },
        f:static_text {
          title = LrView.bind { key='rating', object=props, transform=function(r) return string.rep('★',r)..string.rep('☆',5-r) end },
          font = '<system/14>',
          width = 100
        }
      },

      f:row {
        spacing = 10,
        f:static_text { title = 'Color:', width = 50 },
        f:popup_menu {
          value = LrView.bind('colorLabel'),
          items = {
            { title='None', value='none' },
            { title='Red', value='red' },
            { title='Yellow', value='yellow' },
            { title='Green', value='green' },
            { title='Blue', value='blue' },
            { title='Purple', value='purple' }
          },
          width = 100
        }
      }
    }

    -- Combine preview and controls
    local previewRow = f:row { spacing = 20, preview, controls }

    -- Keyboard shortcuts handler (Lightroom style keys)
    local function handleKey(key)
      if key == 'Left' and props.currentIndex > 1 then
        setProp(props,'currentIndex', props.currentIndex - 1)
      elseif key == 'Right' and props.currentIndex < #photoData then
        setProp(props,'currentIndex', props.currentIndex + 1)
      elseif key == 'p' or key == 'P' then
        setProp(props,'pickStatus',1)
      elseif key == 'x' or key == 'X' then
        setProp(props,'pickStatus',-1)
      elseif key == 'u' or key == 'U' then
        setProp(props,'pickStatus',0)
      elseif key:match('^[0-5]$') then
        setProp(props,'rating', tonumber(key))
      elseif key == '6' then setProp(props,'colorLabel','red')
      elseif key == '7' then setProp(props,'colorLabel','yellow')
      elseif key == '8' then setProp(props,'colorLabel','green')
      elseif key == '9' then setProp(props,'colorLabel','blue')
      end
    end

    local content = f:view {
      width = 800,
      bind_to_object = props,
      key_press = function(_, key) handleKey(key) end,
      f:column {
        spacing = f:control_spacing(),
        f:row {
          fill_horizontal = 1,
          f:static_text { title = 'Review Crops - '..#photos..' photos', font='<system/bold>' },
          f:spacer { fill_horizontal = 1 },
          f:static_text {
            title = LrView.bind { key='hasAnyChanges', object=props, transform=function(h) return h and 'Changes pending' or 'No changes' end },
            font = '<system/bold>'
          }
        },
        f:separator { fill_horizontal=1 },
        previewRow,
        filmstrip
      }
    }

    local result = LrDialogs.presentModalDialog {
      title = 'WildlifeAI Review Crops',
      contents = content,
      actionVerb = 'Save Changes',
      cancelVerb = 'Cancel',
      resizable = true
    }

    if result == 'ok' then
      catalog:withWriteAccessDo('WAI save crop reviews', function()
        local changedCount = 0
        for i, d in ipairs(photoData) do
          if changes[i] then
            if d.rating ~= d.originalRating then
              d.photo:setRawMetadata('rating', d.rating)
              Log.info('Updated rating for '..d.filename..': '..d.rating)
            end
            if d.pickStatus ~= d.originalPickStatus then
              d.photo:setRawMetadata('pickStatus', d.pickStatus)
              Log.info('Updated pick status for '..d.filename..': '..d.pickStatus)
            end
            if d.colorLabel ~= d.originalColorLabel then
              if d.colorLabel == 'none' then
                d.photo:setRawMetadata('colorNameForLabel', nil)
              else
                d.photo:setRawMetadata('colorNameForLabel', d.colorLabel)
              end
              Log.info('Updated color label for '..d.filename..': '..d.colorLabel)
            end
            changedCount = changedCount + 1
          end
        end
        Log.info('Saved changes to '..changedCount..' of '..#photos..' photos')
      end, {timeout = 60})
    end

    Log.info('Review dialog closed with result: ' .. tostring(result))
  end)
end)
