-- WildlifeAI Analytics Module
local LrApplication = import 'LrApplication'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local json = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/dkjson.lua') )
local Log = dofile( LrPathUtils.child(_PLUGIN.path, 'utils/Log.lua') )

local M = {}

-- Helper function to safely get numeric values with precision preservation
local function parseNumeric(value)
  if type(value) == 'number' then
    return value  -- Already a number, preserve full precision
  elseif type(value) == 'string' then
    -- Handle string values that might contain decimals
    local num = tonumber(value)
    return num or 0  -- tonumber preserves precision from string
  else
    return 0
  end
end

-- Helper function to format CSV field
local function csvField(value)
  if not value then return '""' end
  local str = tostring(value)
  -- Escape quotes and wrap in quotes if contains comma or quote
  if string.find(str, '[",\n\r]') then
    str = string.gsub(str, '"', '""')
    return '"' .. str .. '"'
  else
    return str
  end
end

-- Get all processed photos from the catalog
function M.getAllProcessedPhotos()
  local catalog = LrApplication.activeCatalog()
  local allPhotos = catalog:getAllPhotos()
  local processedPhotos = {}
  
  for _, photo in ipairs(allPhotos) do
    local processed = photo:getPropertyForPlugin(_PLUGIN, 'wai_processed')
    if processed == 'true' then
      table.insert(processedPhotos, photo)
    end
  end
  
  return processedPhotos
end

-- Extract WildlifeAI metadata from a photo
function M.extractWildlifeAIMetadata(photo)
  local function getPluginProperty(id)
    local value = photo:getPropertyForPlugin(_PLUGIN, id)
    return value and value ~= '' and value or nil
  end
  
  local function getNumericProperty(id)
    local value = getPluginProperty(id)
    if not value or value == 'N/A' or value == 'Not Rated' then
      return nil
    end
    return parseNumeric(value)
  end
  
  return {
    detected_species = getPluginProperty('wai_detectedSpecies'),
    species_confidence = getNumericProperty('wai_speciesConfidence'),
    quality = getNumericProperty('wai_quality'),
    rating = getNumericProperty('wai_rating'),
    scene_count = getNumericProperty('wai_sceneCount'),
    feature_similarity = getNumericProperty('wai_featureSimilarity'),
    feature_confidence = getNumericProperty('wai_featureConfidence'),
    color_similarity = getNumericProperty('wai_colorSimilarity'),
    color_confidence = getNumericProperty('wai_colorConfidence'),
    processing_time = getNumericProperty('wai_processingTime')
  }
end

-- Calculate plugin statistics
function M.calculatePluginStatistics()
  local photos = M.getAllProcessedPhotos()
  local stats = {
    total_photos = #photos,
    species_counts = {},
    quality_stats = {},
    confidence_stats = {},
    rating_stats = {},
    scene_count_stats = {},
    processing_time_total = 0,
    processing_time_samples = 0,
    feature_similarity_stats = {},
    feature_confidence_stats = {},
    color_similarity_stats = {},
    color_confidence_stats = {}
  }
  
  -- Initialize numeric stats tables
  local function initStats(t)
    t.values = {}
    t.min = nil
    t.max = nil
    t.sum = 0
    t.count = 0
  end
  
  initStats(stats.quality_stats)
  initStats(stats.confidence_stats)
  initStats(stats.rating_stats)
  initStats(stats.scene_count_stats)
  initStats(stats.feature_similarity_stats)
  initStats(stats.feature_confidence_stats)
  initStats(stats.color_similarity_stats)
  initStats(stats.color_confidence_stats)
  
  -- Process each photo
  for _, photo in ipairs(photos) do
    local metadata = M.extractWildlifeAIMetadata(photo)
    
    -- Species counting
    local species = metadata.detected_species
    if species and species ~= 'No Bird Detected' and species ~= 'Unknown' then
      stats.species_counts[species] = (stats.species_counts[species] or 0) + 1
    end
    
    -- Helper function to update numeric stats
    local function updateStats(statTable, value)
      if value and value >= 0 then
        table.insert(statTable.values, value)
        statTable.sum = statTable.sum + value
        statTable.count = statTable.count + 1
        if not statTable.min or value < statTable.min then
          statTable.min = value
        end
        if not statTable.max or value > statTable.max then
          statTable.max = value
        end
      end
    end
    
    -- Update all numeric statistics
    updateStats(stats.quality_stats, metadata.quality)
    updateStats(stats.confidence_stats, metadata.species_confidence)
    updateStats(stats.rating_stats, metadata.rating)
    updateStats(stats.scene_count_stats, metadata.scene_count)
    updateStats(stats.feature_similarity_stats, metadata.feature_similarity)
    updateStats(stats.feature_confidence_stats, metadata.feature_confidence)
    updateStats(stats.color_similarity_stats, metadata.color_similarity)
    updateStats(stats.color_confidence_stats, metadata.color_confidence)
    
    -- Processing time (special handling for totals)
    if metadata.processing_time and metadata.processing_time > 0 then
      stats.processing_time_total = stats.processing_time_total + metadata.processing_time
      stats.processing_time_samples = stats.processing_time_samples + 1
    end
  end
  
  -- Calculate averages and other derived stats
  local function finalizeStats(statTable)
    if statTable.count > 0 then
      statTable.average = statTable.sum / statTable.count
      
      -- Calculate median
      table.sort(statTable.values)
      local mid = math.floor(statTable.count / 2)
      if statTable.count % 2 == 0 and mid > 0 then
        statTable.median = (statTable.values[mid] + statTable.values[mid + 1]) / 2
      else
        statTable.median = statTable.values[mid + 1]
      end
      
      -- Calculate standard deviation
      local variance = 0
      for _, value in ipairs(statTable.values) do
        variance = variance + math.pow(value - statTable.average, 2)
      end
      statTable.std_dev = math.sqrt(variance / statTable.count)
    end
  end
  
  finalizeStats(stats.quality_stats)
  finalizeStats(stats.confidence_stats)
  finalizeStats(stats.rating_stats)
  finalizeStats(stats.scene_count_stats)
  finalizeStats(stats.feature_similarity_stats)
  finalizeStats(stats.feature_confidence_stats)
  finalizeStats(stats.color_similarity_stats)
  finalizeStats(stats.color_confidence_stats)
  
  -- Calculate processing time average
  if stats.processing_time_samples > 0 then
    stats.processing_time_average = stats.processing_time_total / stats.processing_time_samples
  end
  
  -- Find most and least common species
  local species_list = {}
  for species, count in pairs(stats.species_counts) do
    table.insert(species_list, {species = species, count = count})
  end
  table.sort(species_list, function(a, b) return a.count > b.count end)
  
  stats.most_common_species = species_list[1]
  stats.least_common_species = species_list[#species_list]
  stats.unique_species_count = #species_list
  
  return stats
end

-- Calculate camera performance statistics
function M.calculateCameraStatistics()
  local photos = M.getAllProcessedPhotos()
  local camera_stats = {}
  local lens_stats = {}
  local aperture_stats = {}
  local shutter_stats = {}
  local iso_stats = {}
  local focal_length_stats = {}
  local ev_stats = {}
  
  -- Process each photo
  for _, photo in ipairs(photos) do
    local metadata = M.extractWildlifeAIMetadata(photo)
    local quality = metadata.quality
    
    if quality and quality >= 0 then
      -- Get camera metadata
      local camera = photo:getFormattedMetadata('cameraModel') or 'Unknown'
      local lens = photo:getFormattedMetadata('lens') or 'Unknown'
      local aperture = photo:getFormattedMetadata('aperture') or 'Unknown'
      local shutter = photo:getFormattedMetadata('shutterSpeed') or 'Unknown'
      local iso = photo:getFormattedMetadata('isoSpeedRating') or 'Unknown'
      local focal_length = photo:getFormattedMetadata('focalLength') or 'Unknown'
      
      -- Calculate EV from aperture and shutter (if available)
      local ev = 'Unknown'
      local raw_aperture = photo:getRawMetadata('aperture')
      local raw_shutter = photo:getRawMetadata('shutterSpeed')
      local raw_iso = photo:getRawMetadata('isoSpeedRating')
      
      if raw_aperture and raw_shutter and raw_iso then
        -- EV = log2(aperture^2 / shutter_time) + log2(ISO/100)
        local aperture_ev = math.log(raw_aperture * raw_aperture) / math.log(2)
        local shutter_ev = -math.log(raw_shutter) / math.log(2)
        local iso_ev = math.log(raw_iso / 100) / math.log(2)
        local calculated_ev = aperture_ev + shutter_ev + iso_ev
        ev = string.format('%.1f', calculated_ev)
      end
      
      -- Helper function to update camera stats
      local function updateCameraStats(stats_table, key)
        if not stats_table[key] then
          stats_table[key] = {
            total_quality = 0,
            count = 0,
            quality_values = {}
          }
        end
        stats_table[key].total_quality = stats_table[key].total_quality + quality
        stats_table[key].count = stats_table[key].count + 1
        table.insert(stats_table[key].quality_values, quality)
      end
      
      updateCameraStats(camera_stats, camera)
      updateCameraStats(lens_stats, lens)
      updateCameraStats(aperture_stats, aperture)
      updateCameraStats(shutter_stats, shutter)
      updateCameraStats(iso_stats, iso)
      updateCameraStats(focal_length_stats, focal_length)
      updateCameraStats(ev_stats, ev)
    end
  end
  
  -- Calculate averages and additional statistics
  local function finalizeCameraStats(stats_table)
    for key, data in pairs(stats_table) do
      if data.count > 0 then
        data.average_quality = data.total_quality / data.count
        
        -- Calculate min, max, median, std dev
        table.sort(data.quality_values)
        data.min_quality = data.quality_values[1]
        data.max_quality = data.quality_values[#data.quality_values]
        
        local mid = math.floor(data.count / 2)
        if data.count % 2 == 0 and mid > 0 then
          data.median_quality = (data.quality_values[mid] + data.quality_values[mid + 1]) / 2
        else
          data.median_quality = data.quality_values[mid + 1]
        end
        
        -- Standard deviation
        local variance = 0
        for _, value in ipairs(data.quality_values) do
          variance = variance + math.pow(value - data.average_quality, 2)
        end
        data.std_dev = math.sqrt(variance / data.count)
      end
    end
  end
  
  finalizeCameraStats(camera_stats)
  finalizeCameraStats(lens_stats)
  finalizeCameraStats(aperture_stats)
  finalizeCameraStats(shutter_stats)
  finalizeCameraStats(iso_stats)
  finalizeCameraStats(focal_length_stats)
  finalizeCameraStats(ev_stats)
  
  return {
    camera = camera_stats,
    lens = lens_stats,
    aperture = aperture_stats,
    shutter_speed = shutter_stats,
    iso = iso_stats,
    focal_length = focal_length_stats,
    ev = ev_stats
  }
end

-- Export plugin statistics to CSV
function M.exportPluginStatisticsCSV(filePath)
  local stats = M.calculatePluginStatistics()
  
  local csv_lines = {}
  
  -- Header
  table.insert(csv_lines, 'WildlifeAI Plugin Statistics Report')
  table.insert(csv_lines, 'Generated: ' .. os.date('%Y-%m-%d %H:%M:%S'))
  table.insert(csv_lines, '')
  
  -- Summary statistics
  table.insert(csv_lines, 'Summary Statistics')
  table.insert(csv_lines, 'Metric,Value')
  table.insert(csv_lines, csvField('Total Photos Processed') .. ',' .. csvField(stats.total_photos))
  table.insert(csv_lines, csvField('Unique Species Detected') .. ',' .. csvField(stats.unique_species_count))
  table.insert(csv_lines, csvField('Total Processing Time (seconds)') .. ',' .. csvField(string.format('%.2f', stats.processing_time_total)))
  if stats.processing_time_average then
    table.insert(csv_lines, csvField('Average Processing Time (seconds)') .. ',' .. csvField(string.format('%.2f', stats.processing_time_average)))
  end
  table.insert(csv_lines, '')
  
  -- Quality statistics
  local function addStatsSection(title, stat_data)
    if stat_data.count > 0 then
      table.insert(csv_lines, title)
      table.insert(csv_lines, 'Metric,Value')
      table.insert(csv_lines, csvField('Count') .. ',' .. csvField(stat_data.count))
      table.insert(csv_lines, csvField('Average') .. ',' .. csvField(string.format('%.2f', stat_data.average)))
      table.insert(csv_lines, csvField('Median') .. ',' .. csvField(string.format('%.2f', stat_data.median)))
      table.insert(csv_lines, csvField('Minimum') .. ',' .. csvField(string.format('%.2f', stat_data.min)))
      table.insert(csv_lines, csvField('Maximum') .. ',' .. csvField(string.format('%.2f', stat_data.max)))
      table.insert(csv_lines, csvField('Standard Deviation') .. ',' .. csvField(string.format('%.2f', stat_data.std_dev)))
      table.insert(csv_lines, '')
    end
  end
  
  addStatsSection('Quality Statistics (0-100)', stats.quality_stats)
  addStatsSection('Species Confidence Statistics (%)', stats.confidence_stats)
  addStatsSection('Rating Statistics (0-5)', stats.rating_stats)
  addStatsSection('Scene Count Statistics', stats.scene_count_stats)
  addStatsSection('Feature Similarity Statistics (%)', stats.feature_similarity_stats)
  addStatsSection('Feature Confidence Statistics (%)', stats.feature_confidence_stats)
  addStatsSection('Color Similarity Statistics (%)', stats.color_similarity_stats)
  addStatsSection('Color Confidence Statistics (%)', stats.color_confidence_stats)
  
  -- Species breakdown
  if stats.unique_species_count > 0 then
    table.insert(csv_lines, 'Species Detection Summary')
    table.insert(csv_lines, 'Species,Count,Percentage')
    
    local species_list = {}
    for species, count in pairs(stats.species_counts) do
      table.insert(species_list, {species = species, count = count})
    end
    table.sort(species_list, function(a, b) return a.count > b.count end)
    
    for _, data in ipairs(species_list) do
      local percentage = (data.count / stats.total_photos) * 100
      table.insert(csv_lines, csvField(data.species) .. ',' .. csvField(data.count) .. ',' .. csvField(string.format('%.1f%%', percentage)))
    end
  end
  
  -- Write to file
  local content = table.concat(csv_lines, '\n')
  local success, err = pcall(function()
    local file = io.open(filePath, 'w')
    if file then
      file:write(content)
      file:close()
      return true
    else
      return false, 'Could not open file for writing'
    end
  end)
  
  return success, err
end

-- Export camera performance to CSV
function M.exportCameraStatisticsCSV(filePath)
  local stats = M.calculateCameraStatistics()
  
  local csv_lines = {}
  
  -- Header
  table.insert(csv_lines, 'WildlifeAI Camera Performance Report')
  table.insert(csv_lines, 'Generated: ' .. os.date('%Y-%m-%d %H:%M:%S'))
  table.insert(csv_lines, '')
  
  -- Helper function to export a statistics category
  local function exportCategory(title, category_data)
    table.insert(csv_lines, title)
    table.insert(csv_lines, 'Item,Count,Avg Quality,Min Quality,Max Quality,Median Quality,Std Dev')
    
    -- Sort by average quality (descending)
    local sorted_items = {}
    for item, data in pairs(category_data) do
      table.insert(sorted_items, {item = item, data = data})
    end
    table.sort(sorted_items, function(a, b) return a.data.average_quality > b.data.average_quality end)
    
    for _, entry in ipairs(sorted_items) do
      local data = entry.data
      table.insert(csv_lines, string.format('%s,%d,%.2f,%.2f,%.2f,%.2f,%.2f',
        csvField(entry.item),
        data.count,
        data.average_quality,
        data.min_quality,
        data.max_quality,
        data.median_quality,
        data.std_dev
      ))
    end
    table.insert(csv_lines, '')
  end
  
  exportCategory('Camera Performance', stats.camera)
  exportCategory('Lens Performance', stats.lens)
  exportCategory('Aperture Performance', stats.aperture)
  exportCategory('Shutter Speed Performance', stats.shutter_speed)
  exportCategory('ISO Performance', stats.iso)
  exportCategory('Focal Length Performance', stats.focal_length)
  exportCategory('Exposure Value (EV) Performance', stats.ev)
  
  -- Write to file
  local content = table.concat(csv_lines, '\n')
  local success, err = pcall(function()
    local file = io.open(filePath, 'w')
    if file then
      file:write(content)
      file:close()
      return true
    else
      return false, 'Could not open file for writing'
    end
  end)
  
  return success, err
end

return M
