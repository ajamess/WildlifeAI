-- WildlifeAI Bracket Preview Dialog
-- Shows detailed preview of bracket detection results before stacking

local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrTasks = import 'LrTasks'
local LrProgressScope = import 'LrProgressScope'
local LrPathUtils = import 'LrPathUtils'

local BracketStacking = dofile( LrPathUtils.child(_PLUGIN.path, 'BracketStacking.lua') )

local BracketPreview = {}

-- Helper function to format time duration
local function formatDuration(seconds)
  if seconds < 60 then
    return string.format("%.1fs", seconds)
  elseif seconds < 3600 then
    return string.format("%dm %.0fs", math.floor(seconds / 60), seconds % 60)
  else
    return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
  end
end

-- Helper function to format timestamp
local function formatTimestamp(timestamp)
  if timestamp and timestamp > 0 then
    return os.date("%H:%M:%S", timestamp)
  end
  return "Unknown"
end

-- Helper function to get photo name from metadata
local function getPhotoName(photoData)
  return photoData.fileName or 'Unknown'
end

-- Create summary statistics section
local function createSummarySection(f, detectionResults, props)
  local stats = detectionResults.stats
  
  return f:group_box {
    title = 'Detection Summary',
    fill_horizontal = 1,
    spacing = f:control_spacing(),
    
    f:row {
      spacing = 15,
      
      -- Left column - Basic stats
      f:column {
        spacing = f:control_spacing(),
        
        f:static_text {
          title = 'Total Photos Analyzed: ' .. stats.totalPhotos,
          font = '<system/bold>'
        },
        
        f:static_text {
          title = 'Photos in Stacks: ' .. stats.processedPhotos,
          font = '<system>'
        },
        
        f:static_text {
          title = 'Unmatched Photos: ' .. stats.unmatchedPhotos,
          font = '<system>'
        }
      },
      
      -- Middle column - Stack stats
      f:column {
        spacing = f:control_spacing(),
        
        f:static_text {
          title = 'Total Stacks: ' .. stats.totalStacks,
          font = '<system/bold>'
        },
        
        f:static_text {
          title = 'Individual Brackets: ' .. stats.individualSequences,
          font = '<system>'
        },
        
        f:static_text {
          title = 'Panorama Sequences: ' .. stats.panoramaSequences,
          font = '<system>'
        }
      },
      
      -- Right column - Quality indicators
      f:column {
        spacing = f:control_spacing(),
        
        f:static_text {
          title = bind {
            key = 'avgConfidence',
            object = props,
            transform = function(confidence)
              return string.format('Average Confidence: %.0f%%', confidence or 0)
            end
          },
          font = '<system/bold>'
        },
        
        f:static_text {
          title = bind {
            key = 'issuesFound',
            object = props,
            transform = function(issues)
              return 'Potential Issues: ' .. (issues or 0)
            end
          },
          font = '<system>',
          text_color = bind {
            key = 'issuesFound',
            object = props,
            transform = function(issues)
              return (issues and issues > 0) and LrView.kRedColor or LrView.kControlTextColor
            end
          }
        }
      }
    }
  }
end

-- Create results table section
local function createResultsTable(f, detectionResults, props)
  local tableData = {}
  
  -- Build table data from detection results
  for _, sequence in ipairs(detectionResults.sequences) do
    for bracketIndex, bracket in ipairs(sequence.brackets) do
      local firstPhoto = bracket.photos[1]
      local lastPhoto = bracket.photos[#bracket.photos]
      local timeSpan = bracket.duration
      
      -- Determine issues
      local issues = {}
      if bracket.confidence < 70 then
        table.insert(issues, 'Low confidence')
      end
      if not bracket.exposureAnalysis.valid and bracket.exposureAnalysis.reason then
        table.insert(issues, bracket.exposureAnalysis.reason)
      end
      if bracket.size < 3 then
        table.insert(issues, 'Small bracket')
      end
      
      local issueText = #issues > 0 and table.concat(issues, ', ') or 'None'
      
      -- Color coding
      local rowColor = LrView.kControlBackgroundColor
      if bracket.type == 'panorama' then
        rowColor = { red = 0.9, green = 0.95, blue = 1.0, alpha = 1.0 } -- Light blue
      elseif #issues > 0 then
        rowColor = { red = 1.0, green = 0.95, blue = 0.9, alpha = 1.0 } -- Light orange
      end
      
      table.insert(tableData, {
        stackType = string.upper(string.sub(bracket.type, 1, 1)) .. string.sub(bracket.type, 2),
        imageCount = bracket.size,
        firstImage = getPhotoName(firstPhoto),
        lastImage = getPhotoName(lastPhoto),
        timeSpan = formatDuration(timeSpan),
        confidence = string.format('%d%%', bracket.confidence),
        issues = issueText,
        color = rowColor,
        bracket = bracket -- Keep reference for actions
      })
    end
  end
  
  -- Create scrollable table view
  local tableRows = {}
  
  -- Header row
  table.insert(tableRows, f:row {
    spacing = 5,
    
    f:static_text { title = 'Type', width = 80, font = '<system/bold>' },
    f:static_text { title = 'Count', width = 50, font = '<system/bold>' },
    f:static_text { title = 'First Image', width = 150, font = '<system/bold>' },
    f:static_text { title = 'Last Image', width = 150, font = '<system/bold>' },
    f:static_text { title = 'Time Span', width = 80, font = '<system/bold>' },
    f:static_text { title = 'Confidence', width = 80, font = '<system/bold>' },
    f:static_text { title = 'Issues', width = 200, font = '<system/bold>' }
  })
  
  -- Data rows
  for i, rowData in ipairs(tableData) do
    table.insert(tableRows, f:row {
      spacing = 5,
      
      f:static_text { 
        title = rowData.stackType, 
        width = 80,
        text_color = rowData.bracket.type == 'panorama' and LrView.kBlueColor or LrView.kControlTextColor
      },
      f:static_text { title = tostring(rowData.imageCount), width = 50 },
      f:static_text { title = rowData.firstImage, width = 150, truncation = 'middle' },
      f:static_text { title = rowData.lastImage, width = 150, truncation = 'middle' },
      f:static_text { title = rowData.timeSpan, width = 80 },
      f:static_text { 
        title = rowData.confidence, 
        width = 80,
        text_color = rowData.bracket.confidence < 70 and LrView.kRedColor or LrView.kControlTextColor
      },
      f:static_text { 
        title = rowData.issues, 
        width = 200, 
        truncation = 'tail',
        text_color = rowData.issues ~= 'None' and LrView.kRedColor or LrView.kControlTextColor
      }
    })
  end
  
  return f:group_box {
    title = 'Detected Bracket Stacks (' .. #tableData .. ' stacks)',
    fill_horizontal = 1,
    fill_vertical = 1,
    spacing = f:control_spacing(),
    
    f:scrolled_view {
      horizontal_scroller = false,
      vertical_scroller = true,
      width = 800,
      height = 300,
      
      f:column {
        spacing = 2,
        tableRows
      }
    }
  }
end

-- Calculate preview statistics
local function calculatePreviewStats(detectionResults)
  local totalConfidence = 0
  local confidenceCount = 0
  local issuesFound = 0
  
  for _, sequence in ipairs(detectionResults.sequences) do
    for _, bracket in ipairs(sequence.brackets) do
      totalConfidence = totalConfidence + bracket.confidence
      confidenceCount = confidenceCount + 1
      
      -- Count issues
      if bracket.confidence < 70 then
        issuesFound = issuesFound + 1
      end
      if not bracket.exposureAnalysis.valid then
        issuesFound = issuesFound + 1
      end
      if bracket.size < 3 then
        issuesFound = issuesFound + 1
      end
    end
  end
  
  return {
    avgConfidence = confidenceCount > 0 and (totalConfidence / confidenceCount) or 0,
    issuesFound = issuesFound
  }
end

-- Main preview dialog function
function BracketPreview.showPreview(context, photos, detectionResults)
  local f = LrView.osFactory()
  local props = LrBinding.makePropertyTable(context)
  
  -- Calculate statistics
  local previewStats = calculatePreviewStats(detectionResults)
  props.avgConfidence = previewStats.avgConfidence
  props.issuesFound = previewStats.issuesFound
  props.processingInProgress = false
  
  -- Create dialog content
  local c = f:column {
    spacing = f:control_spacing(),
    fill_horizontal = 1,
    fill_vertical = 1,
    
    f:static_text {
      title = 'Bracket Detection Preview',
      font = '<system/bold/large>',
      fill_horizontal = 1
    },
    
    f:spacer { height = 10 },
    
    createSummarySection(f, detectionResults, props),
    
    f:spacer { height = 10 },
    
    createResultsTable(f, detectionResults, props),
    
    f:spacer { height = 10 },
    
    -- Warning section if issues found
    f:group_box {
      title = 'Recommendations',
      fill_horizontal = 1,
      visible = bind {
        key = 'issuesFound',
        object = props,
        transform = function(issues) return issues and issues > 0 end
      },
      
      f:column {
        spacing = f:control_spacing(),
        
        f:static_text {
          title = 'Some potential issues were detected in the bracket analysis:',
          font = '<system/bold>',
          text_color = LrView.kRedColor
        },
        
        f:static_text {
          title = '• Low confidence brackets may not be true bracket sequences',
          font = '<system/small>'
        },
        
        f:static_text {
          title = '• Inconsistent exposure steps may indicate mixed shooting modes',
          font = '<system/small>'
        },
        
        f:static_text {
          title = '• Small brackets (< 3 photos) may be incomplete sequences',
          font = '<system/small>'
        },
        
        f:static_text {
          title = 'Consider adjusting detection settings or manually reviewing flagged stacks.',
          font = '<system/small/italic>'
        }
      }
    },
    
    f:spacer { height = 10 },
    
    -- Progress indicator
    f:row {
      visible = bind('processingInProgress'),
      f:static_text {
        title = 'Creating stacks...',
        font = '<system/bold>'
      }
    }
  }
  
  -- Show dialog with action buttons
  local result = LrDialogs.presentModalDialog {
    title = 'Bracket Stacking Preview',
    contents = c,
    actionVerb = 'Create Stacks',
    otherVerb = 'Adjust Settings',
    cancelVerb = 'Cancel',
    save_frame = 'WildlifeAI_BracketPreview',
    resizable = true
  }
  
  return result
end

-- Note: Stack creation with progress is now handled directly in the menu files
-- This function has been removed to avoid async context issues

return BracketPreview
