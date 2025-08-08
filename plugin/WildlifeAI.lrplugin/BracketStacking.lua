local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local LrDialogs = import 'LrDialogs'
local LrPrefs = import 'LrPrefs'
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )

local M = {}
local lastAnalysis = nil

-- Lightroom metadata fields used: 'dateTimeOriginal' for capture time and 'orientation'
-- for image rotation. Assumes orientation codes follow EXIF 1-8 specification.

local DEFAULTS = {
  timeGap = 2, -- seconds between shots to be grouped
  exposureTolerance = 0.1, -- EV difference treated as same exposure
  expectedBracketSize = 3,
  collapseStacks = true,
  bracketDebugMode = false,
  orientationTolerance = 0, -- orientation code difference to start new group
}

local function parseNumber(v)
  if type(v) == 'number' then return v end
  if type(v) ~= 'string' then return 0 end
  local n,d = v:match('^(%-?%d+)%/(%d+)$')
  if n and d then
    return tonumber(n)/tonumber(d)
  end
  return tonumber(v) or 0
end

-- Safely read raw metadata fields
local function safeGetMetadata(photo, field)
  local ok, value = pcall(function() return photo:getRawMetadata(field) end)
  if not ok then
    Log.warning('Failed to read '..field..' from photo '..tostring(photo))
    return nil
  end
  return value
end

local function getExposureValue(photo)
  local shutter = parseNumber(safeGetMetadata(photo, 'shutterSpeed'))
  local aperture = parseNumber(safeGetMetadata(photo, 'aperture'))
  local iso = parseNumber(safeGetMetadata(photo, 'isoSpeedRating'))
  if shutter <= 0 or aperture <= 0 or iso <= 0 then return nil end
  local ev = math.log(aperture * aperture / shutter * 100 / iso, 2)
  return ev
end


local function formatExposures(exposures)
  local t = {}
  for _,ev in ipairs(exposures) do
    t[#t+1] = string.format('%.2f', ev)
  end
  return table.concat(t, ', ')

local function getOrientation(photo)
  return safeGetMetadata(photo, 'orientation')

end

-- Return capture time using original EXIF date/time field. Lightroom returns
-- either a numeric epoch value or a formatted string; convert both to seconds.
local function getCaptureTime(photo)
  local dt = safeGetMetadata(photo, 'dateTimeOriginal')
  if type(dt) == 'number' then return dt end
  if type(dt) == 'string' then
    local y,mo,d,h,mi,s = dt:match('^(%d+):(%d+):(%d+) (%d+):(%d+):(%d+)')
    if y then
      return os.time{year=tonumber(y), month=tonumber(mo), day=tonumber(d),
                     hour=tonumber(h), min=tonumber(mi), sec=tonumber(s)}
    end
    return tonumber(dt) or 0
  end
  return 0
end

-- Group photos by capture time
local function groupByTime(photos, prefs)
  table.sort(photos, function(a,b)
    return getCaptureTime(a) < getCaptureTime(b)
  end)
  local groups = {}
  local cur
  local lastCt, lastOr = nil, nil
  local gap = prefs.timeGap or DEFAULTS.timeGap
  local oTol = prefs.orientationTolerance or DEFAULTS.orientationTolerance -- orientation code tolerance (EXIF 1-8)
  for _,p in ipairs(photos) do

    local ct = getCaptureTime(p)
    local o = getOrientation(p)
    if lastCt and prefs.bracketDebugMode then
      Log.debug(string.format('Time gap to previous: %.2fs', ct - lastCt))
    end

    local timeBreak = lastCt and (ct - lastCt) > gap
    local orientationBreak = false
    if lastOr and o then
      -- orientation codes are integers; treat any change beyond tolerance as a new group
      orientationBreak = math.abs(o - lastOr) > oTol
      if orientationBreak and prefs.bracketDebugMode then
        Log.debug(string.format('Orientation change %d -> %d exceeds %d', lastOr, o, oTol))
      end
    end

    if not cur or timeBreak or orientationBreak then
      if cur then table.insert(groups, cur) end
      cur = {photos={}, exposures={}, orientations={}, lowConfidence=false}
    end
    table.insert(cur.photos, p)
    local ev = getExposureValue(p)
    if not ev then
      cur.lowConfidence = true
      Log.warning('Missing exposure data for '..tostring(p))
    end
    table.insert(cur.exposures, ev or 0)
    if not o then
      cur.lowConfidence = true
      Log.warning('Missing orientation for '..tostring(p))
    end
    table.insert(cur.orientations, o)

    lastCt = ct
    lastOr = o
  end
  if cur and #cur.photos>0 then table.insert(groups, cur) end
  return groups
end

local function classifyGroup(g, prefs)
  local tol = prefs.exposureTolerance or DEFAULTS.exposureTolerance
  if g.lowConfidence then
    g.type = (#g.photos > 1) and 'bracket' or 'single'
    return
  end
  local unique = {}
  for _,ev in ipairs(g.exposures) do
    local bucket = math.floor(ev / tol + 0.5)
    unique[bucket] = true
  end
  local count = 0
  for _ in pairs(unique) do count = count + 1 end
  local expected = prefs.expectedBracketSize or DEFAULTS.expectedBracketSize
  if count > 1 then
    g.type = 'bracket'
    g.confidence = math.min(count / expected, 1)
  elseif #g.photos > 1 then
    g.type = 'panorama'
    g.confidence = 1
  else
    g.type = 'single'
    g.confidence = 1
  end
end

-- merge incomplete bracket groups
local function mergeIncomplete(groups, prefs)
  local expected = prefs.expectedBracketSize or DEFAULTS.expectedBracketSize
  local merged = {}
  local i=1
  while i <= #groups do
    local g = groups[i]
    if g.type=='bracket' and #g.photos < expected and groups[i+1] and groups[i+1].type=='bracket' then
      local nxt = groups[i+1]
      if prefs.bracketDebugMode then
        Log.debug(string.format('Merging bracket groups of sizes %d and %d (expected %d)', #g.photos, #nxt.photos, expected))
      end
      for _,p in ipairs(nxt.photos) do table.insert(g.photos, p) end
      for _,ev in ipairs(nxt.exposures) do table.insert(g.exposures, ev) end
      classifyGroup(g, prefs)
      i = i + 1
    end
    table.insert(merged, g)
    i = i + 1
  end
  return merged
end

function M.analyzeBrackets(photos, prefs)
  prefs = prefs or {}
  for k,v in pairs(DEFAULTS) do if prefs[k] == nil then prefs[k] = v end end
  Log.info('Analyzing brackets for '..#photos..' photos')
  if prefs.bracketDebugMode then
    Log.debug('Bracket debug mode enabled')
    if prefs.expectedBracketSize ~= DEFAULTS.expectedBracketSize then
      Log.debug('Bracket size override preference: '..tostring(prefs.expectedBracketSize))
    end
  end
  local groups = groupByTime(photos, prefs)
  for _,g in ipairs(groups) do classifyGroup(g, prefs) end
  groups = mergeIncomplete(groups, prefs)
  local expected = prefs.expectedBracketSize or DEFAULTS.expectedBracketSize
  for idx,g in ipairs(groups) do
    classifyGroup(g, prefs)
    if g.type=='bracket' then

      local idxTop=1
      local minDiff=nil
      for i,ev in ipairs(g.exposures) do
        local diff = math.abs(ev)
        if not minDiff or diff < minDiff then
          minDiff = diff
          idxTop = i

      if g.lowConfidence then
        g.top = g.photos[1]
      else
        local idx=1
        local minDiff=nil
        for i,ev in ipairs(g.exposures) do
          local diff = math.abs(ev)
          if not minDiff or diff < minDiff then
            minDiff = diff
            idx = i
          end

        end
        g.top = g.photos[idx]
      end
      g.top = g.photos[idxTop]

    else
      g.top = g.photos[1]
    end
    if prefs.bracketDebugMode then
      Log.debug(string.format('Group %d exposures: %s', idx, formatExposures(g.exposures)))
      if g.type == 'bracket' and #g.photos ~= expected then
        Log.debug(string.format('Bracket size override: expected %d got %d', expected, #g.photos))
      end
      Log.debug(string.format('Group %d classified as %s (confidence %.2f)', idx, g.type, g.confidence or 0))
    end
  end
  Log.info('Bracket analysis produced '..#groups..' groups')
  return groups
end

function M.applyStacks(groups, prefs)
  prefs = prefs or {}
  for k,v in pairs(DEFAULTS) do if prefs[k] == nil then prefs[k] = v end end
  Log.info('Applying stacks for '..#groups..' groups')
  local catalog = LrApplication.activeCatalog()
  catalog:withWriteAccessDo('WildlifeAI Bracket Stacking', function()
    for _,g in ipairs(groups) do
      if g.photos and #g.photos > 1 then
        for _,p in ipairs(g.photos) do
          if p:getRawMetadata('isInStackInFolder') then
            p:removeFromStack()
          end
        end
        local top = g.top or g.photos[1]
        for _,p in ipairs(g.photos) do
          if p ~= top then top:addToStack(p) end
        end
        if prefs.collapseStacks then
          top:setStackCollapsed(true)
        end
      end
    end
  end)
  Log.info('Stacking complete')
end

function M.analyze()
  local catalog = LrApplication.activeCatalog()
  local photos = catalog:getTargetPhotos()
  if #photos == 0 then
    LrDialogs.message('WildlifeAI', 'No photos selected')
    return
  end
  local prefs = LrPrefs.prefsForPlugin()
  lastAnalysis = M.analyzeBrackets(photos, prefs)
  LrPrefs.prefsForPlugin().bracketAnalysisDone = true
  local low = 0
  for _,g in ipairs(lastAnalysis) do if g.lowConfidence then low = low + 1 end end
  local msg = 'Bracket analysis complete.'
  if low > 0 then
    msg = msg .. '\n' .. low .. ' group(s) lacked exposure or orientation data. Time gaps were used and results may be less accurate.'
  end
  LrDialogs.message('WildlifeAI', msg)
end

function M.hasAnalysis()
  local prefs = LrPrefs.prefsForPlugin()
  return prefs.bracketAnalysisDone == true and lastAnalysis ~= nil
end

function M.stack()
  if not M.hasAnalysis() then
    LrDialogs.message('WildlifeAI', 'Analyze brackets before stacking.')
    return
  end
  M.applyStacks(lastAnalysis)
  LrDialogs.message('WildlifeAI', 'Bracket stacking complete.')
end

function M.clear()
  lastAnalysis = nil
  LrPrefs.prefsForPlugin().bracketAnalysisDone = false
  LrDialogs.message('WildlifeAI', 'Bracket analysis cleared.')
end

return M

