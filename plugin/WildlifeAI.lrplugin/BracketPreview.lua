-- WildlifeAI Bracket Preview Dialog
-- Displays analysis results with summary statistics and thumbnail previews

local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'

-- Cache table for analysis results.  The key is a concatenation of photo identifiers
local analysisCache = {}

-- Analyze selected photos and build per-photo result data.
-- This function derives bracket number and quality from photo metadata
-- stored by WildlifeAI (wai_bracket and wai_quality respectively).
-- It returns a summary table and array of per-photo results.
local function analyzePhotos(photos)
  local results = {}
  local summary = {
    total = #photos,
    warnings = 0,
    bracketCounts = {}
  }

  for _, photo in ipairs(photos) do
    local bracket = tonumber(photo:getPropertyForPlugin(_PLUGIN, 'wai_bracket')) or 1
    local quality = tonumber(photo:getPropertyForPlugin(_PLUGIN, 'wai_quality')) or 0
    local fileName = photo:getFormattedMetadata('fileName')

    summary.bracketCounts[bracket] = (summary.bracketCounts[bracket] or 0) + 1

    local warning
    if quality < 20 then
      warning = 'Low quality'
      summary.warnings = summary.warnings + 1
    end

    table.insert(results, {
      photo = photo,
      bracket = bracket,
      quality = quality,
      fileName = fileName,
      warning = warning
    })
  end

  local bracketTotal = 0
  for _ in pairs(summary.bracketCounts) do
    bracketTotal = bracketTotal + 1
  end
  summary.brackets = bracketTotal

  return summary, results
end

-- Build a stable cache key based on selected photos
local function buildCacheKey(photos)
  local parts = {}
  for _, p in ipairs(photos) do
    parts[#parts + 1] = tostring(p.localIdentifier or '')
  end
  return table.concat(parts, ',')
end

-- Create a color for a row based on presence of a warning
local function rowColor(warning)
  if warning then
    return {0.4, 0.1, 0.1}
  end
  return {0, 0, 0}
end

-- Present the Bracket Preview dialog
return function(context, photos)
  local cacheKey = buildCacheKey(photos)
  local summary, results
  if analysisCache[cacheKey] then
    summary = analysisCache[cacheKey].summary
    results = analysisCache[cacheKey].results
  else
    summary, results = analyzePhotos(photos)
    analysisCache[cacheKey] = { summary = summary, results = results }
  end

  local f = LrView.osFactory()
  local bind = LrView.bind
  local props = LrBinding.makePropertyTable(context)

  -- Build results table rows
  local tableRows = {
    f:row {
      spacing = 10,
      f:static_text { title = 'Preview', width = 70 },
      f:static_text { title = 'File', width = 200 },
      f:static_text { title = 'Bracket', width = 60 },
      f:static_text { title = 'Quality', width = 60 },
      f:static_text { title = 'Warning', fill_horizontal = 1 }
    }
  }

  for _, r in ipairs(results) do
    table.insert(tableRows, f:row {
      spacing = 10,
      fill_color = rowColor(r.warning),
      f:catalog_photo { photo = r.photo, width = 60, height = 60 },
      f:static_text { title = r.fileName, width = 200 },
      f:static_text { title = tostring(r.bracket), width = 60 },
      f:static_text { title = string.format('%.1f', r.quality), width = 60 },
      f:static_text { title = r.warning or '', text_color = {1, 0.4, 0.4}, fill_horizontal = 1 }
    })
  end

  local resultsView = f:scrolled_view {
    width = 700,
    height = 300,
    horizontal_scroller = false,
    vertical_scroller = true,
    f:column(tableRows)
  }

  local summaryView = f:group_box {
    title = 'Summary',
    fill_horizontal = 1,
    f:column {
      spacing = f:control_spacing(),
      f:static_text { title = string.format('Total Photos: %d', summary.total) },
      f:static_text { title = string.format('Bracket Groups: %d', summary.brackets) },
      f:static_text { title = string.format('Warnings: %d', summary.warnings), text_color = {1,0.4,0.4} }
    }
  }

  local contents = f:column {
    bind_to_object = props,
    spacing = f:control_spacing(),
    summaryView,
    resultsView,
    summary.warnings > 0 and f:static_text {
      title = 'Check warnings before stacking.',
      text_color = {1,0.4,0.4},
      fill_horizontal = 1
    } or nil
  }

  local result = LrDialogs.presentModalDialog {
    title = 'Bracket Preview',
    contents = contents,
    actionVerb = 'Apply Stacking',
    otherVerb = 'Adjust Settings',
    cancelVerb = 'Cancel',
    save_frame = 'WildlifeAI_BracketPreview'
  }

  if result == 'ok' then
    return 'apply', analysisCache[cacheKey]
  elseif result == 'other' then
    LrFunctionContext.callWithContext('WAI_Config', function(cfgContext)
      dofile(LrPathUtils.child(_PLUGIN.path, 'UI/ConfigDialog.lua'))(cfgContext)
    end)
    return 'adjust'
  else
    return 'cancel'
  end
end

