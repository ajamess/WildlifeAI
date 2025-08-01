-- WildlifeAI Analytics Dialog
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'
local Analytics = dofile( LrPathUtils.child(_PLUGIN.path, 'Analytics.lua') )

return function(context)
  local f = LrView.osFactory()
  local bind = LrView.bind
  
  -- Create analytics properties for live updates
  local analyticsProps = LrBinding.makePropertyTable(context)
  analyticsProps.pluginStats = nil
  analyticsProps.cameraStats = nil
  analyticsProps.refreshing = false
  
  -- Function to refresh analytics data
  local function refreshAnalytics()
    if analyticsProps.refreshing then return end
    analyticsProps.refreshing = true
    
    -- Run analytics in async task to avoid blocking UI
    LrTasks.startAsyncTask(function()
      local pluginStats = Analytics.calculatePluginStatistics()
      local cameraStats = Analytics.calculateCameraStatistics()
      
      analyticsProps.pluginStats = pluginStats
      analyticsProps.cameraStats = cameraStats
      analyticsProps.refreshing = false
    end)
  end
  
  -- Function to export plugin statistics
  local function exportPluginStats()
    local filePath = LrDialogs.runSavePanel {
      title = 'Export Plugin Statistics',
      canChooseFiles = false,
      canChooseDirectories = false,
      canCreateDirectories = true,
      allowsMultipleSelection = false,
      fileTypes = 'csv',
      initialPath = LrPathUtils.getStandardFilePath('desktop')
    }
    
    if filePath then
      if not string.match(filePath, '%.csv$') then
        filePath = filePath .. '.csv'
      end
      
      local success, err = Analytics.exportPluginStatisticsCSV(filePath)
      if success then
        LrDialogs.message('Export Complete', 'Plugin statistics exported to:\n' .. filePath, 'info')
      else
        LrDialogs.message('Export Failed', 'Failed to export statistics:\n' .. tostring(err), 'error')
      end
    end
  end
  
  -- Function to export camera statistics
  local function exportCameraStats()
    local filePath = LrDialogs.runSavePanel {
      title = 'Export Camera Performance',
      canChooseFiles = false,
      canChooseDirectories = false,
      canCreateDirectories = true,
      allowsMultipleSelection = false,
      fileTypes = 'csv',
      initialPath = LrPathUtils.getStandardFilePath('desktop')
    }
    
    if filePath then
      if not string.match(filePath, '%.csv$') then
        filePath = filePath .. '.csv'
      end
      
      local success, err = Analytics.exportCameraStatisticsCSV(filePath)
      if success then
        LrDialogs.message('Export Complete', 'Camera performance exported to:\n' .. filePath, 'info')
      else
        LrDialogs.message('Export Failed', 'Failed to export camera performance:\n' .. tostring(err), 'error')
      end
    end
  end

  -- Plugin Statistics Tab
  local pluginStatsTab = f:column {
    spacing = f:control_spacing(),
    
    f:row {
      f:static_text { 
        title = 'Plugin Statistics', 
        font = '<system/bold>',
        fill_horizontal = 1 
      },
      f:push_button {
        title = 'Refresh',
        action = function() refreshAnalytics() end
      },
      f:push_button {
        title = 'Export CSV',
        action = function() exportPluginStats() end
      }
    },
    
    f:spacer { height = 10 },
    
    -- Summary Statistics
    f:group_box {
      title = 'Summary Statistics',
      fill_horizontal = 1,
      
      f:column {
        f:static_text {
          title = bind {
            key = 'pluginStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats then return 'Click Refresh to load statistics...' end
              return string.format('Total Photos Processed: %d', stats.total_photos)
            end
          }
        },
        f:static_text {
          title = bind {
            key = 'pluginStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats then return '' end
              return string.format('Unique Species Detected: %d', stats.unique_species_count or 0)
            end
          }
        },
        f:static_text {
          title = bind {
            key = 'pluginStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.processing_time_average then return '' end
              return string.format('Average Processing Time: %.2f seconds', stats.processing_time_average)
            end
          }
        },
        f:static_text {
          title = bind {
            key = 'pluginStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.processing_time_total then return '' end
              return string.format('Total Processing Time: %.2f seconds', stats.processing_time_total)
            end
          }
        }
      }
    },
    
    f:spacer { height = 10 },
    
    -- Quality Statistics
    f:group_box {
      title = 'Quality Statistics (0-100)',
      fill_horizontal = 1,
      
      f:column {
        f:static_text {
          title = bind {
            key = 'pluginStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.quality_stats or stats.quality_stats.count == 0 then return 'No quality data available' end
              local qs = stats.quality_stats
              return string.format('Average: %.2f | Min: %.2f | Max: %.2f | Median: %.2f', 
                qs.average, qs.min, qs.max, qs.median)
            end
          }
        },
        f:static_text {
          title = bind {
            key = 'pluginStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.quality_stats or stats.quality_stats.count == 0 then return '' end
              return string.format('Standard Deviation: %.2f | Sample Count: %d', 
                stats.quality_stats.std_dev, stats.quality_stats.count)
            end
          }
        }
      }
    },
    
    f:spacer { height = 10 },
    
    -- Species Statistics
    f:group_box {
      title = 'Species Detection',
      fill_horizontal = 1,
      
      f:column {
        f:static_text {
          title = bind {
            key = 'pluginStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.most_common_species then return 'No species data available' end
              return string.format('Most Common: %s (%d photos)', 
                stats.most_common_species.species, stats.most_common_species.count)
            end
          }
        },
        f:static_text {
          title = bind {
            key = 'pluginStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.least_common_species then return '' end
              return string.format('Least Common: %s (%d photos)', 
                stats.least_common_species.species, stats.least_common_species.count)
            end
          }
        }
      }
    },
    
    f:spacer { height = 10 },
    
    -- Advanced Statistics
    f:group_box {
      title = 'Advanced Metrics',
      fill_horizontal = 1,
      
      f:column {
        f:static_text {
          title = bind {
            key = 'pluginStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.confidence_stats or stats.confidence_stats.count == 0 then return 'Species Confidence: No data' end
              local cs = stats.confidence_stats
              return string.format('Species Confidence Avg: %.2f%% (σ=%.2f)', cs.average, cs.std_dev)
            end
          }
        },
        f:static_text {
          title = bind {
            key = 'pluginStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.feature_similarity_stats or stats.feature_similarity_stats.count == 0 then return 'Feature Similarity: No data' end
              local fs = stats.feature_similarity_stats
              return string.format('Feature Similarity Avg: %.2f%% (σ=%.2f)', fs.average, fs.std_dev)
            end
          }
        },
        f:static_text {
          title = bind {
            key = 'pluginStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.color_confidence_stats or stats.color_confidence_stats.count == 0 then return 'Color Confidence: No data' end
              local cc = stats.color_confidence_stats
              return string.format('Color Confidence Avg: %.2f%% (σ=%.2f)', cc.average, cc.std_dev)
            end
          }
        }
      }
    }
  }
  
  -- Camera Performance Tab
  local cameraStatsTab = f:column {
    spacing = f:control_spacing(),
    
    f:row {
      f:static_text { 
        title = 'Camera Performance Analysis', 
        font = '<system/bold>',
        fill_horizontal = 1 
      },
      f:push_button {
        title = 'Refresh',
        action = function() refreshAnalytics() end
      },
      f:push_button {
        title = 'Export CSV',
        action = function() exportCameraStats() end
      }
    },
    
    f:spacer { height = 10 },
    
    -- Camera Performance
    f:group_box {
      title = 'Top Performing Cameras (by average quality)',
      fill_horizontal = 1,
      
      f:column {
        f:static_text {
          title = bind {
            key = 'cameraStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.camera then return 'Click Refresh to load camera statistics...' end
              
              -- Get top 3 cameras
              local cameras = {}
              for camera, data in pairs(stats.camera) do
                table.insert(cameras, {camera = camera, data = data})
              end
              table.sort(cameras, function(a, b) return a.data.average_quality > b.data.average_quality end)
              
              local result = {}
              for i = 1, math.min(3, #cameras) do
                local cam = cameras[i]
                table.insert(result, string.format('%d. %s: %.2f avg (n=%d)', 
                  i, cam.camera, cam.data.average_quality, cam.data.count))
              end
              
              return #result > 0 and table.concat(result, '\n') or 'No camera data available'
            end
          }
        }
      }
    },
    
    f:spacer { height = 10 },
    
    -- Lens Performance
    f:group_box {
      title = 'Top Performing Lenses',
      fill_horizontal = 1,
      
      f:column {
        f:static_text {
          title = bind {
            key = 'cameraStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.lens then return 'No lens data available' end
              
              -- Get top 3 lenses
              local lenses = {}
              for lens, data in pairs(stats.lens) do
                if data.count >= 5 then -- Only show lenses with 5+ photos
                  table.insert(lenses, {lens = lens, data = data})
                end
              end
              table.sort(lenses, function(a, b) return a.data.average_quality > b.data.average_quality end)
              
              local result = {}
              for i = 1, math.min(3, #lenses) do
                local lens = lenses[i]
                local shortLens = string.len(lens.lens) > 40 and string.sub(lens.lens, 1, 37) .. '...' or lens.lens
                table.insert(result, string.format('%d. %s: %.2f avg (n=%d)', 
                  i, shortLens, lens.data.average_quality, lens.data.count))
              end
              
              return #result > 0 and table.concat(result, '\n') or 'No lens data available (need 5+ photos per lens)'
            end
          }
        }
      }
    },
    
    f:spacer { height = 10 },
    
    -- Aperture Performance
    f:group_box {
      title = 'Aperture Performance',
      fill_horizontal = 1,
      
      f:column {
        f:static_text {
          title = bind {
            key = 'cameraStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.aperture then return 'No aperture data available' end
              
              -- Get top 5 apertures
              local apertures = {}
              for aperture, data in pairs(stats.aperture) do
                if data.count >= 3 then -- Only show apertures with 3+ photos
                  table.insert(apertures, {aperture = aperture, data = data})
                end
              end
              table.sort(apertures, function(a, b) return a.data.average_quality > b.data.average_quality end)
              
              local result = {}
              for i = 1, math.min(5, #apertures) do
                local ap = apertures[i]
                table.insert(result, string.format('%s: %.2f avg (n=%d)', 
                  ap.aperture, ap.data.average_quality, ap.data.count))
              end
              
              return #result > 0 and table.concat(result, ' | ') or 'No aperture data available'
            end
          }
        }
      }
    },
    
    f:spacer { height = 10 },
    
    -- ISO Performance
    f:group_box {
      title = 'ISO Performance',
      fill_horizontal = 1,
      
      f:column {
        f:static_text {
          title = bind {
            key = 'cameraStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.iso then return 'No ISO data available' end
              
              -- Get top 5 ISOs
              local isos = {}
              for iso, data in pairs(stats.iso) do
                if data.count >= 3 then -- Only show ISOs with 3+ photos
                  table.insert(isos, {iso = iso, data = data})
                end
              end
              table.sort(isos, function(a, b) return a.data.average_quality > b.data.average_quality end)
              
              local result = {}
              for i = 1, math.min(5, #isos) do
                local iso = isos[i]
                table.insert(result, string.format('%s: %.2f avg (n=%d)', 
                  iso.iso, iso.data.average_quality, iso.data.count))
              end
              
              return #result > 0 and table.concat(result, ' | ') or 'No ISO data available'
            end
          }
        }
      }
    },
    
    f:spacer { height = 10 },
    
    -- Exposure Value Performance
    f:group_box {
      title = 'Best Exposure Values (EV)',
      fill_horizontal = 1,
      
      f:column {
        f:static_text {
          title = bind {
            key = 'cameraStats',
            object = analyticsProps,
            transform = function(stats)
              if not stats or not stats.ev then return 'No EV data available' end
              
              -- Get top 5 EVs
              local evs = {}
              for ev, data in pairs(stats.ev) do
                if data.count >= 3 and ev ~= 'Unknown' then
                  table.insert(evs, {ev = ev, data = data})
                end
              end
              table.sort(evs, function(a, b) return a.data.average_quality > b.data.average_quality end)
              
              local result = {}
              for i = 1, math.min(5, #evs) do
                local ev = evs[i]
                table.insert(result, string.format('EV %s: %.2f avg (n=%d)', 
                  ev.ev, ev.data.average_quality, ev.data.count))
              end
              
              return #result > 0 and table.concat(result, ' | ') or 'No EV data available'
            end
          }
        }
      }
    }
  }
  
  -- Create tabbed interface
  local tabView = f:tab_view {
    f:tab_view_item {
      title = 'Plugin Statistics',
      pluginStatsTab
    },
    f:tab_view_item {
      title = 'Camera Performance',
      cameraStatsTab
    }
  }
  
  -- Main dialog content
  local c = f:column {
    spacing = f:control_spacing(),
    
    f:static_text { 
      title = 'WildlifeAI Statistics & Analytics', 
      font = '<system/bold>',
      fill_horizontal = 1 
    },
    
    f:spacer { height = 10 },
    
    tabView
  }
  
  -- Initial analytics refresh
  refreshAnalytics()
  
  local result = LrDialogs.presentModalDialog { 
    title = 'WildlifeAI Statistics & Analytics', 
    contents = c,
    actionVerb = 'Close',
    save_frame = 'WildlifeAI_AnalyticsDialog'
  }
  
  return result
end
