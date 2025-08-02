-- WildlifeAI Configuration Dialog
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrPrefs = import 'LrPrefs'
local LrBinding = import 'LrBinding'

-- Get system CPU count for max workers limit
local function getSystemCPUCount()
  local success, result = pcall(function()
    -- Try to read from environment or use sensible defaults
    local cores = os.getenv('NUMBER_OF_PROCESSORS') or '8'
    return tonumber(cores) or 8
  end)
  return success and result or 8
end

local function createThresholdItems()
  local items = {}
  for i = 0, 5 do
    table.insert(items, { title = tostring(i), value = i })
  end
  return items
end

local function createColorItems()
  return {
    { title = 'Red', value = 'red' },
    { title = 'Yellow', value = 'yellow' },
    { title = 'Green', value = 'green' },
    { title = 'Blue', value = 'blue' },
    { title = 'Purple', value = 'purple' },
    { title = 'None', value = 'none' }
  }
end

local function createIptcFieldItems()
  return {
    { title = 'Job Identifier', value = 'jobIdentifier' },
    { title = 'Instructions', value = 'instructions' },
    { title = 'Caption/Description', value = 'caption' },
    { title = 'Keywords', value = 'keywords' },
    { title = 'Title', value = 'title' },
    { title = 'Headline', value = 'headline' },
    { title = 'Creator', value = 'creator' },
    { title = 'Copyright', value = 'copyright' },
    { title = 'Source', value = 'source' },
    { title = 'Category', value = 'intellectualGenre' },
    { title = 'Supplemental Categories', value = 'scene' },
    { title = 'None (Disabled)', value = 'none' }
  }
end

-- Helper function to parse range string like "0-20" or "80-100"
local function parseRange(rangeStr)
  if not rangeStr or rangeStr == '' then return nil end
  local min, max = string.match(rangeStr, '^(%d+)%-(%d+)$')
  if min and max then
    min, max = tonumber(min), tonumber(max)
    if min and max and min >= 0 and max <= 100 and min <= max then
      return { min = min, max = max }
    end
  end
  return nil
end

-- Helper function to check if ranges overlap
local function rangesOverlap(ranges)
  for i = 1, #ranges - 1 do
    for j = i + 1, #ranges do
      local r1, r2 = ranges[i], ranges[j]
      if r1 and r2 then
        if not (r1.max < r2.min or r2.max < r1.min) then
          return true, i, j
        end
      end
    end
  end
  return false
end

return function(context)
  local f = LrView.osFactory()
  local prefs = LrPrefs.prefsForPlugin()
  local bind = LrView.bind
  local maxCPUs = getSystemCPUCount()
  
  -- Set defaults
  prefs.maxWorkers = prefs.maxWorkers or math.min(4, maxCPUs)
  if prefs.useGPU == nil then prefs.useGPU = false end
  if prefs.writeXMP == nil then prefs.writeXMP = false end
  if prefs.mirrorJobId == nil then prefs.mirrorJobId = false end
  if prefs.enableLogging == nil then prefs.enableLogging = false end
  if prefs.generateCrops == nil then prefs.generateCrops = true end
  
  -- Rating and labeling defaults
  if prefs.enableRating == nil then prefs.enableRating = false end
  if prefs.enableRejection == nil then prefs.enableRejection = false end
  prefs.rejectionThreshold = prefs.rejectionThreshold or 2
  if prefs.enablePicks == nil then prefs.enablePicks = false end
  prefs.picksThreshold = prefs.picksThreshold or 4
  if prefs.enableColorLabels == nil then prefs.enableColorLabels = false end
  
  -- New advanced options defaults
  prefs.qualityMode = prefs.qualityMode or 'rating' -- 'rating' or 'quality'
  prefs.rejectionQualityThreshold = prefs.rejectionQualityThreshold or 20
  prefs.picksQualityThreshold = prefs.picksQualityThreshold or 80
  prefs.colorLabelMode = prefs.colorLabelMode or 'rating' -- 'rating' or 'quality'
  
  -- Color label defaults for rating mode (maps rating values to colors)
  prefs.colorLabel0 = prefs.colorLabel0 or 1  -- 0 stars -> Red (rating 1)
  prefs.colorLabel1 = prefs.colorLabel1 or 2  -- 1 star -> Yellow (rating 2)
  prefs.colorLabel2 = prefs.colorLabel2 or 3  -- 2 stars -> Green (rating 3)
  prefs.colorLabel3 = prefs.colorLabel3 or 4  -- 3 stars -> Blue (rating 4)
  prefs.colorLabel4 = prefs.colorLabel4 or 5  -- 4 stars -> Purple (rating 5)
  prefs.colorLabel5 = prefs.colorLabel5 or 0  -- 5 stars -> No label (rating 0)
  
  -- Color label defaults for quality ranges - sensible defaults for wildlife photography
  if prefs.colorRangeRedEnabled == nil then prefs.colorRangeRedEnabled = true end
  prefs.colorRangeRedMin = prefs.colorRangeRedMin or 0
  prefs.colorRangeRedMax = prefs.colorRangeRedMax or 30    -- Poor quality: 0-30
  
  if prefs.colorRangeYellowEnabled == nil then prefs.colorRangeYellowEnabled = true end
  prefs.colorRangeYellowMin = prefs.colorRangeYellowMin or 31
  prefs.colorRangeYellowMax = prefs.colorRangeYellowMax or 50   -- Fair quality: 31-50
  
  if prefs.colorRangeGreenEnabled == nil then prefs.colorRangeGreenEnabled = true end
  prefs.colorRangeGreenMin = prefs.colorRangeGreenMin or 51
  prefs.colorRangeGreenMax = prefs.colorRangeGreenMax or 70    -- Good quality: 51-70
  
  if prefs.colorRangeBlueEnabled == nil then prefs.colorRangeBlueEnabled = true end
  prefs.colorRangeBlueMin = prefs.colorRangeBlueMin or 71
  prefs.colorRangeBlueMax = prefs.colorRangeBlueMax or 85      -- Very good quality: 71-85
  
  if prefs.colorRangePurpleEnabled == nil then prefs.colorRangePurpleEnabled = true end
  prefs.colorRangePurpleMin = prefs.colorRangePurpleMin or 86
  prefs.colorRangePurpleMax = prefs.colorRangePurpleMax or 100  -- Excellent quality: 86-100
  
  if prefs.colorRangeNoneEnabled == nil then prefs.colorRangeNoneEnabled = false end
  prefs.colorRangeNoneMin = prefs.colorRangeNoneMin or 0
  prefs.colorRangeNoneMax = prefs.colorRangeNoneMax or 0
  
  -- Enhanced IPTC mirroring defaults (all enabled by default)
  if prefs.enableIptcMirror == nil then prefs.enableIptcMirror = false end
  prefs.iptcField = prefs.iptcField or 'jobIdentifier'
  prefs.iptcReadField = prefs.iptcReadField or 'jobIdentifier'
  
  -- All metadata elements enabled by default with unique 2-char qualifiers
  if prefs.includeDetectedSpecies == nil then prefs.includeDetectedSpecies = true end -- Sp
  if prefs.includeSpeciesConfidence == nil then prefs.includeSpeciesConfidence = true end -- Co
  if prefs.includeQuality == nil then prefs.includeQuality = true end -- Qu
  if prefs.includeRating == nil then prefs.includeRating = true end -- Ra
  if prefs.includeSceneCount == nil then prefs.includeSceneCount = true end -- Sc
  if prefs.includeFeatureSimilarity == nil then prefs.includeFeatureSimilarity = true end -- Fs
  if prefs.includeFeatureConfidence == nil then prefs.includeFeatureConfidence = true end -- Fc
  if prefs.includeColorSimilarity == nil then prefs.includeColorSimilarity = true end -- Cs
  if prefs.includeColorConfidence == nil then prefs.includeColorConfidence = true end -- Cc
  if prefs.includeProcessingTime == nil then prefs.includeProcessingTime = true end -- Pt
  
  -- Enhanced keywording system defaults
  if prefs.enableKeywording == nil then prefs.enableKeywording = false end
  prefs.keywordRoot = prefs.keywordRoot or 'WildlifeAI'
  prefs.speciesKeywordRoot = prefs.speciesKeywordRoot or ''
  if prefs.keywordQuality == nil then prefs.keywordQuality = true end
  if prefs.keywordRating == nil then prefs.keywordRating = true end
  if prefs.keywordSpeciesConfidence == nil then prefs.keywordSpeciesConfidence = true end
  if prefs.keywordSceneCount == nil then prefs.keywordSceneCount = true end
  if prefs.keywordDetectedSpecies == nil then prefs.keywordDetectedSpecies = true end
  if prefs.keywordSpeciesUnderSpeciesRoot == nil then prefs.keywordSpeciesUnderSpeciesRoot = false end
  
  -- Create validation properties with proper function context
  local props = LrBinding.makePropertyTable(context)
  props.validationError = ''
  props.rejectionValid = true
  props.picksValid = true
  props.colorRangeValid = true
  props.colorRangeError = ''
  
  -- Enhanced validation function
  local function validateThresholds()
    local rejectionEnabled = prefs.enableRejection
    local picksEnabled = prefs.enablePicks
    local qualityMode = prefs.qualityMode
    
    props.rejectionValid = true
    props.picksValid = true
    props.validationError = ''
    
    if qualityMode == 'rating' then
      local rejectionThreshold = prefs.rejectionThreshold or 2
      local picksThreshold = prefs.picksThreshold or 4
      
      if rejectionEnabled and picksEnabled then
        if rejectionThreshold >= picksThreshold then
          props.rejectionValid = false
          props.picksValid = false
          props.validationError = 'Error: Rejection threshold (' .. rejectionThreshold .. ') must be lower than picks threshold (' .. picksThreshold .. ')'
          return false
        end
      end
    else -- quality mode
      local rejectionThreshold = prefs.rejectionQualityThreshold or 20
      local picksThreshold = prefs.picksQualityThreshold or 80
      
      -- Validate range 0-100 - ensure numeric conversion
      rejectionThreshold = tonumber(rejectionThreshold) or 20
      picksThreshold = tonumber(picksThreshold) or 80
      
      if rejectionThreshold < 0 or rejectionThreshold > 100 then
        props.rejectionValid = false
        props.validationError = 'Error: Rejection quality threshold must be 0-100'
        return false
      end
      
      if picksThreshold < 0 or picksThreshold > 100 then
        props.picksValid = false
        props.validationError = 'Error: Picks quality threshold must be 0-100'
        return false
      end
      
      if rejectionEnabled and picksEnabled then
        if rejectionThreshold >= picksThreshold then
          props.rejectionValid = false
          props.picksValid = false
          props.validationError = 'Error: Rejection threshold (' .. rejectionThreshold .. ') must be lower than picks threshold (' .. picksThreshold .. ')'
          return false
        end
      end
    end
    
    return true
  end
  
  -- Color range validation function
  local function validateColorRanges()
    props.colorRangeValid = true
    props.colorRangeError = ''
    
    if prefs.colorLabelMode ~= 'quality' then
      return true
    end
    
    local ranges = {}
    local colors = {
      {name = 'Red', min = prefs.colorRangeRedMin, max = prefs.colorRangeRedMax},
      {name = 'Yellow', min = prefs.colorRangeYellowMin, max = prefs.colorRangeYellowMax},
      {name = 'Green', min = prefs.colorRangeGreenMin, max = prefs.colorRangeGreenMax},
      {name = 'Blue', min = prefs.colorRangeBlueMin, max = prefs.colorRangeBlueMax},
      {name = 'Purple', min = prefs.colorRangePurpleMin, max = prefs.colorRangePurpleMax}
    }
    
    if prefs.colorRangeNoneEnabled then
      table.insert(colors, {name = 'None', min = prefs.colorRangeNoneMin, max = prefs.colorRangeNoneMax})
    end
    
    -- Validate individual ranges
    for _, color in ipairs(colors) do
      local minVal = tonumber(color.min) or 0
      local maxVal = tonumber(color.max) or 0
      
      if minVal < 0 or minVal > 100 or maxVal < 0 or maxVal > 100 then
        props.colorRangeValid = false
        props.colorRangeError = string.format('Error: %s range values must be 0-100', color.name)
        return false
      end
      
      if minVal > maxVal then
        props.colorRangeValid = false
        props.colorRangeError = string.format('Error: %s minimum (%d) must be less than or equal to maximum (%d)', color.name, minVal, maxVal)
        return false
      end
      
      table.insert(ranges, {min = minVal, max = maxVal, name = color.name})
    end
    
    -- Check for overlaps
    for i = 1, #ranges - 1 do
      for j = i + 1, #ranges do
        local r1, r2 = ranges[i], ranges[j]
        if not (r1.max < r2.min or r2.max < r1.min) then
          props.colorRangeValid = false
          props.colorRangeError = string.format('Error: %s and %s ranges overlap', r1.name, r2.name)
          return false
        end
      end
    end
    
    return true
  end
  
  -- Combined validation function
  local function validateAll()
    local thresholdValid = validateThresholds()
    local rangeValid = validateColorRanges()
    return thresholdValid and rangeValid
  end
  
  -- Bind validation to all relevant changes
  prefs:addObserver('rejectionThreshold', validateAll)
  prefs:addObserver('picksThreshold', validateAll)
  prefs:addObserver('rejectionQualityThreshold', validateAll)
  prefs:addObserver('picksQualityThreshold', validateAll)
  prefs:addObserver('enableRejection', validateAll)
  prefs:addObserver('enablePicks', validateAll)
  prefs:addObserver('qualityMode', validateAll)
  prefs:addObserver('colorLabelMode', validateAll)
  -- Add observers for all color range fields
  prefs:addObserver('colorRangeRedMin', validateAll)
  prefs:addObserver('colorRangeRedMax', validateAll)
  prefs:addObserver('colorRangeYellowMin', validateAll)
  prefs:addObserver('colorRangeYellowMax', validateAll)
  prefs:addObserver('colorRangeGreenMin', validateAll)
  prefs:addObserver('colorRangeGreenMax', validateAll)
  prefs:addObserver('colorRangeBlueMin', validateAll)
  prefs:addObserver('colorRangeBlueMax', validateAll)
  prefs:addObserver('colorRangePurpleMin', validateAll)
  prefs:addObserver('colorRangePurpleMax', validateAll)
  prefs:addObserver('colorRangeNoneMin', validateAll)
  prefs:addObserver('colorRangeNoneMax', validateAll)
  prefs:addObserver('colorRangeNoneEnabled', validateAll)

  -- Left Column Controls
  local leftColumn = f:column {
    spacing = f:control_spacing(),
    fill_horizontal = 1,
    
    -- Performance Configuration  
    f:group_box {
      title = 'Performance Settings',
      fill_horizontal = 1,
      spacing = f:control_spacing(),
      
      f:row {
        f:static_text { 
          title = 'Max Workers:', 
          width = 100,
          alignment = 'right'
        },
        f:edit_field { 
          value = bind('maxWorkers'), 
          width_in_chars = 8,
          immediate = true
        },
        f:static_text { 
          title = '(1-' .. maxCPUs .. ')',
          font = '<system/small>'
        }
      },
      
      f:checkbox { 
        title = 'Enable GPU acceleration', 
        value = bind('useGPU')
      },
      f:checkbox { 
        title = 'Generate crop images', 
        value = bind('generateCrops') 
      }
    },
    
    f:spacer { height = 5 },
    
    -- Metadata Configuration
    f:group_box {
      title = 'Metadata & Export',
      fill_horizontal = 1,
      spacing = f:control_spacing(),
      
      f:checkbox { 
        title = 'Write XMP sidecars', 
        value = bind('writeXMP') 
      },
      f:checkbox { 
        title = 'Enable verbose logging', 
        value = bind('enableLogging') 
      }
    },
    
    f:spacer { height = 5 },
    
    -- Automatic Keywording System
    f:group_box {
      title = 'Automatic Keywording',
      fill_horizontal = 1,
      spacing = f:control_spacing(),
      
      f:checkbox { 
        title = 'Enable automatic keyword generation', 
        value = bind('enableKeywording') 
      },
      
      f:spacer { height = 8 },
      
      f:row {
        enabled = bind('enableKeywording'),
        f:static_text { 
          title = 'Root:', 
          width = 50,
          alignment = 'right'
        },
        f:edit_field { 
          value = bind('keywordRoot'), 
          width_in_chars = 20 
        }
      },
      
      f:spacer { height = 5 },
      
      -- Keyword Elements Selection
      f:column {
        enabled = bind('enableKeywording'),
        spacing = f:control_spacing(),
        
        f:checkbox { title = 'Quality Ranges (0-10, 11-20, etc.)', value = bind('keywordQuality') },
        f:checkbox { title = 'Star Ratings (1-5 stars)', value = bind('keywordRating') },
        f:checkbox { title = 'Species Confidence Ranges', value = bind('keywordSpeciesConfidence') },
        f:checkbox { title = 'Scene Count (1, 2, 3+ scenes)', value = bind('keywordSceneCount') },
        f:checkbox { title = 'Detected Species Names', value = bind('keywordDetectedSpecies') },
        
        f:spacer { height = 8 },
        
        -- Species Keywords Sub-section
        f:column {
          enabled = bind('keywordDetectedSpecies'),
          spacing = f:control_spacing(),
          
          f:static_text { 
            title = 'Species Keywords:', 
            font = '<system/small/bold>' 
          },
          
          f:checkbox { 
            title = 'Save species under a second keyword path', 
            value = bind('keywordSpeciesUnderSpeciesRoot') 
          },
          
          f:row {
            enabled = bind('keywordSpeciesUnderSpeciesRoot'),
            f:static_text { 
              title = 'Path:', 
              width = 40,
              alignment = 'right'
            },
            f:edit_field { 
              value = bind('speciesKeywordRoot'), 
              width_in_chars = 15
            }
          },
          
          f:static_text {
            title = 'Example: "Birds > Robin" in addition to "WildlifeAI > Species > Robin"',
            font = '<system/small>',
            enabled = bind('keywordSpeciesUnderSpeciesRoot')
          }
        }
      }
    },
    
    f:spacer { height = 5 },
    
    -- IPTC Metadata Mirroring
    f:group_box {
      title = 'IPTC Metadata Mirroring',
      fill_horizontal = 1,
      spacing = f:control_spacing(),
      
      f:checkbox { 
        title = 'Enable IPTC metadata mirroring', 
        value = bind('enableIptcMirror') 
      },
      
      f:spacer { height = 8 },
      
      f:row {
        enabled = bind('enableIptcMirror'),
        f:static_text { 
          title = 'Field:', 
          width = 50,
          alignment = 'right'
        },
        f:popup_menu {
          value = bind('iptcField'),
          items = createIptcFieldItems(),
          immediate = true,
          width = 180
        }
      },
      
      f:spacer { height = 5 },
      
      -- Metadata Elements Selection
      f:column {
        enabled = bind('enableIptcMirror'),
        spacing = f:control_spacing(),
        
        f:static_text { 
          title = 'Include in IPTC output:', 
          font = '<system/small>' 
        },
        
        f:checkbox { title = 'Quality (Qu)', value = bind('includeQuality') },
        f:checkbox { title = 'Rating (Ra)', value = bind('includeRating') },
        f:checkbox { title = 'Species & Confidence (Sp/Co)', value = bind('includeDetectedSpecies') },
        f:checkbox { title = 'Scene Count (Sc)', value = bind('includeSceneCount') },
        f:checkbox { title = 'Similarity Metrics (Fs/Fc/Cs/Cc)', value = bind('includeFeatureSimilarity') },
        f:checkbox { title = 'Processing Time (Pt)', value = bind('includeProcessingTime') }
      }
    }
  }

  -- Right Column Controls
  local rightColumn = f:column {
    spacing = f:control_spacing(),
    fill_horizontal = 1,
    
    -- Photo Rating & Flagging
    f:group_box {
      title = 'Automatic Rating & Flagging',
      fill_horizontal = 1,
      spacing = f:control_spacing(),
      
      f:checkbox { 
        title = 'Set star rating based on quality (0-5 stars)', 
        value = bind('enableRating') 
      },
      
      f:spacer { height = 10 },
      
      -- Flag Settings
      f:column {
        f:static_text { 
          title = 'Flag Settings:', 
          font = '<system/bold>'
        },
        
        f:spacer { height = 5 },
        
        f:radio_button {
          title = '0-5 Rating Scale (based on computed rating)',
          value = bind('qualityMode'),
          checked_value = 'rating'
        },
        
        f:radio_button {
          title = '0-100 Quality Scale (based on raw quality)',
          value = bind('qualityMode'),
          checked_value = 'quality'
        }
      },
      
      f:spacer { height = 10 },
      
      -- Rating-based thresholds (0-5) - only visible when rating mode selected
      f:column {
        visible = bind {
          key = 'qualityMode',
          transform = function(value) return value == 'rating' end
        },
        spacing = f:control_spacing(),
        
        f:row {
          f:checkbox { 
            title = 'Mark low quality photos as rejected (rating:', 
            value = bind('enableRejection')
          },
          f:popup_menu {
            value = bind('rejectionThreshold'),
            items = createThresholdItems(),
            immediate = true,
            width = 60
          },
          f:static_text { 
            title = 'or below)'
          }
        },
        
        f:row {
          f:checkbox { 
            title = 'Mark high quality photos as picks (rating:', 
            value = bind('enablePicks')
          },
          f:popup_menu {
            value = bind('picksThreshold'),
            items = createThresholdItems(),
            immediate = true,
            width = 60
          },
          f:static_text { 
            title = 'or above)'
          }
        }
      },
      
      -- Quality-based thresholds (0-100) - only visible when quality mode selected
      f:column {
        visible = bind {
          key = 'qualityMode',
          transform = function(value) return value == 'quality' end
        },
        spacing = f:control_spacing(),
        
        f:row {
          f:checkbox { 
            title = 'Mark low quality photos as rejected (quality:', 
            value = bind('enableRejection')
          },
          f:edit_field {
            value = bind('rejectionQualityThreshold'),
            width_in_chars = 8,
            immediate = true
          },
          f:static_text { 
            title = 'or below)'
          }
        },
        
        f:row {
          f:checkbox { 
            title = 'Mark high quality photos as picks (quality:', 
            value = bind('enablePicks')
          },
          f:edit_field {
            value = bind('picksQualityThreshold'),
            width_in_chars = 8,
            immediate = true
          },
          f:static_text { 
            title = 'or above)'
          }
        }
      },
      
      -- Validation error display
      f:static_text {
        title = bind {
          key = 'validationError',
          object = props
        },
        font = '<system/small/bold>',
        visible = bind {
          key = 'validationError',
          object = props,
          transform = function(value)
            return value and value ~= ''
          end
        }
      }
    },
    
    f:spacer { height = 5 },
    
    -- Color Labels and Pick Flags - Improved 3-Column Layout
    f:group_box {
      title = 'Automatic Color Labels and Pick Flags',
      fill_horizontal = 1,
      spacing = f:control_spacing(),
      
      f:checkbox { 
        title = 'Enable automatic color labeling', 
        value = bind('enableColorLabels') 
      },
      
      f:spacer { height = 8 },
      
      -- Settings
      f:column {
        enabled = bind('enableColorLabels'),
        spacing = f:control_spacing(),

        -- Header row for 3-column layout
        f:row {
          spacing = 10,
          
          f:static_text { 
            title = 'Color Label',
            font = '<system/bold>',
            width = 120,
            alignment = 'center'
          },
          
          f:radio_button {
            title = 'Quality Range (0-100)',
            value = bind('colorLabelMode'),
            checked_value = 'quality',
            width = 150, alignment = 'center'
          },

          f:radio_button {
            title = 'Rating Level (0-5)',
            value = bind('colorLabelMode'),
            checked_value = 'rating',
            width = 120, alignment = 'center'
          }
        },
        
        f:separator { fill_horizontal = 1 },
        
        -- Red Label Row
        f:row {
          spacing = 10,
          
          -- Column 1: Checkbox and Label
          f:row {
            width = 120,
            f:checkbox { 
              title = 'Red',
              value = bind('colorRangeRedEnabled'),
              width = 120
            }
          },
          
          -- Column 2: Quality Range (0-100)
          f:row {
            width = 150,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangeRedEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'quality' and values.colorRangeRedEnabled
              end
            },
            
            f:edit_field { 
              value = bind('colorRangeRedMin'), 
              width_in_chars = 4, 
              immediate = true
            },
            f:static_text { title = ' to ', width = 25, alignment = 'center' },
            f:edit_field { 
              value = bind('colorRangeRedMax'), 
              width_in_chars = 4, 
              immediate = true
            }
          },
          
          -- Column 3: Rating Level (0-5)
          f:row {
            width = 120,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangeRedEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'rating' and values.colorRangeRedEnabled
              end
            },
            
            f:popup_menu {
              value = bind('colorLabel0'), -- Red maps to rating 0 by default
              items = createThresholdItems(),
              width = 60
            },
            f:static_text { title = ' stars', width = 50 }
          }
        },
        
        -- Yellow Label Row
        f:row {
          spacing = 10,
          
          f:row {
            width = 120,
            f:checkbox { 
              title = 'Yellow',
              value = bind('colorRangeYellowEnabled'),
              width = 120
            }
          },
          
          f:row {
            width = 150,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangeYellowEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'quality' and values.colorRangeYellowEnabled
              end
            },
            
            f:edit_field { 
              value = bind('colorRangeYellowMin'), 
              width_in_chars = 4, 
              immediate = true
            },
            f:static_text { title = ' to ', width = 25, alignment = 'center' },
            f:edit_field { 
              value = bind('colorRangeYellowMax'), 
              width_in_chars = 4, 
              immediate = true
            }
          },
          
          f:row {
            width = 120,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangeYellowEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'rating' and values.colorRangeYellowEnabled
              end
            },
            
            f:popup_menu {
              value = bind('colorLabel1'), -- Yellow maps to rating 1 by default
              items = createThresholdItems(),
              width = 60
            },
            f:static_text { title = ' stars', width = 50 }
          }
        },
        
        -- Green Label Row
        f:row {
          spacing = 10,
          
          f:row {
            width = 120,
            f:checkbox { 
              title = 'Green',
              value = bind('colorRangeGreenEnabled'),
              width = 120
            }
          },
          
          f:row {
            width = 150,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangeGreenEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'quality' and values.colorRangeGreenEnabled
              end
            },
            
            f:edit_field { 
              value = bind('colorRangeGreenMin'), 
              width_in_chars = 4, 
              immediate = true
            },
            f:static_text { title = ' to ', width = 25, alignment = 'center' },
            f:edit_field { 
              value = bind('colorRangeGreenMax'), 
              width_in_chars = 4, 
              immediate = true
            }
          },
          
          f:row {
            width = 120,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangeGreenEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'rating' and values.colorRangeGreenEnabled
              end
            },
            
            f:popup_menu {
              value = bind('colorLabel2'), -- Green maps to rating 2 by default
              items = createThresholdItems(),
              width = 60
            },
            f:static_text { title = ' stars', width = 50 }
          }
        },
        
        -- Blue Label Row
        f:row {
          spacing = 10,
          
          f:row {
            width = 120,
            f:checkbox { 
              title = 'Blue',
              value = bind('colorRangeBlueEnabled'),
              width = 120
            }
          },
          
          f:row {
            width = 150,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangeBlueEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'quality' and values.colorRangeBlueEnabled
              end
            },
            
            f:edit_field { 
              value = bind('colorRangeBlueMin'), 
              width_in_chars = 4, 
              immediate = true
            },
            f:static_text { title = ' to ', width = 25, alignment = 'center' },
            f:edit_field { 
              value = bind('colorRangeBlueMax'), 
              width_in_chars = 4, 
              immediate = true
            }
          },
          
          f:row {
            width = 120,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangeBlueEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'rating' and values.colorRangeBlueEnabled
              end
            },
            
            f:popup_menu {
              value = bind('colorLabel3'), -- Blue maps to rating 3 by default
              items = createThresholdItems(),
              width = 60
            },
            f:static_text { title = ' stars', width = 50 }
          }
        },
        
        -- Purple Label Row
        f:row {
          spacing = 10,
          
          f:row {
            width = 120,
            f:checkbox { 
              title = 'Purple',
              value = bind('colorRangePurpleEnabled'),
              width = 120
            }
          },
          
          f:row {
            width = 150,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangePurpleEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'quality' and values.colorRangePurpleEnabled
              end
            },
            
            f:edit_field { 
              value = bind('colorRangePurpleMin'), 
              width_in_chars = 4, 
              immediate = true
            },
            f:static_text { title = ' to ', width = 25, alignment = 'center' },
            f:edit_field { 
              value = bind('colorRangePurpleMax'), 
              width_in_chars = 4, 
              immediate = true
            }
          },
          
          f:row {
            width = 120,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangePurpleEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'rating' and values.colorRangePurpleEnabled
              end
            },
            
            f:popup_menu {
              value = bind('colorLabel4'), -- Purple maps to rating 4 by default
              items = createThresholdItems(),
              width = 60
            },
            f:static_text { title = ' stars', width = 50 }
          }
        },
        
        -- None/No Label Row
        f:row {
          spacing = 10,
          
          f:row {
            width = 120,
            f:checkbox { 
              title = 'No Label',
              value = bind('colorRangeNoneEnabled'),
              width = 120
            }
          },
          
          f:row {
            width = 150,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangeNoneEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'quality' and values.colorRangeNoneEnabled
              end
            },
            
            f:edit_field { 
              value = bind('colorRangeNoneMin'), 
              width_in_chars = 4, 
              immediate = true
            },
            f:static_text { title = ' to ', width = 25, alignment = 'center' },
            f:edit_field { 
              value = bind('colorRangeNoneMax'), 
              width_in_chars = 4, 
              immediate = true
            }
          },
          
          f:row {
            width = 120,
            enabled = bind {
              keys = {'colorLabelMode', 'colorRangeNoneEnabled'},
              operation = function(binder, values)
                return values.colorLabelMode == 'rating' and values.colorRangeNoneEnabled
              end
            },
            
            f:popup_menu {
              value = bind('colorLabel5'), -- No label maps to rating 5 by default
              items = createThresholdItems(),
              width = 60
            },
            f:static_text { title = ' stars', width = 50 }
          }
        },
        
        f:spacer { height = 8 },
        
        -- Color range validation error display
        f:static_text {
          title = bind {
            key = 'colorRangeError',
            object = props
          },
          font = '<system/small/bold>',
          visible = bind {
            key = 'colorRangeError',
            object = props,
            transform = function(value)
              return value and value ~= ''
            end
          }
        }
      }
    },
    
    f:spacer { height = 5 },
    
    -- Current Status
    f:group_box {
      title = 'Current Status',
      fill_horizontal = 1,
      spacing = f:control_spacing(),
      
      f:static_text { 
        title = 'Platform: ' .. (WIN_ENV and 'Windows' or 'macOS'),
        font = '<system/small>'
      },
      f:static_text { 
        title = bind {
          keys = {'useGPU', 'maxWorkers'},
          operation = function(binder, values, fromTable)
            local gpu = values.useGPU and 'GPU' or 'CPU'
            local workers = values.maxWorkers or 4
            return string.format('Mode: %s with %d workers', gpu, workers)
          end
        },
        font = '<system/small>'
      }
    }
  }
  
  -- Main dialog content with two-column layout
  local c = f:column {
    bind_to_object = prefs,
    spacing = f:control_spacing(),
    
    f:static_text { 
      title = 'WildlifeAI Configuration', 
      font = '<system/bold>',
      fill_horizontal = 1 
    },
    
    f:spacer { height = 10 },
    
    -- Two-column layout
    f:row {
      spacing = 15,
      leftColumn,
      rightColumn
    }
  }
  
  -- Initial validation
  validateAll()
  
  local result = LrDialogs.presentModalDialog { 
    title = 'Configure WildlifeAI', 
    contents = c,
    actionVerb = 'Save',
    cancelVerb = 'Cancel',
    save_frame = 'WildlifeAI_ConfigDialog',
    resizable = true
  }
  
  -- Validate before saving
  if result == 'ok' then
    if not validateAll() then
      LrDialogs.message('Configuration Error', 'Please fix the validation errors before saving.')
      return -- Re-open dialog or handle error
    end
    
    -- Ensure max workers is within bounds
    if prefs.maxWorkers then
      prefs.maxWorkers = math.max(1, math.min(prefs.maxWorkers, maxCPUs))
    end
    
    -- Validate and convert quality thresholds to numbers
    if prefs.rejectionQualityThreshold then
      prefs.rejectionQualityThreshold = tonumber(prefs.rejectionQualityThreshold) or 20
    end
    if prefs.picksQualityThreshold then
      prefs.picksQualityThreshold = tonumber(prefs.picksQualityThreshold) or 80
    end
  end
  
  return result
end
