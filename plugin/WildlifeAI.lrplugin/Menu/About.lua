local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrFunctionContext = import 'LrFunctionContext'

local helpText = [[
Detection Workflow:
- Select photos and run 'WildlifeAI: Analyze Selected Photos'.
- For bracketed sequences run 'WildlifeAI: Analyze Brackets' then use 'WildlifeAI: Stack Brackets'.
- Enable 'Show preview before stacking' to inspect results in the Bracket Preview dialog.

Configuration Options:
- Open 'WildlifeAI: Configure…' to set runner paths, logging, and performance settings such as Max Workers and preview delay.
- Toggle logging or debug mode from the plugin menu for diagnostics.

Troubleshooting:
- Use 'WildlifeAI: Open Log Folder' to view logs and confirm runner paths.
- Rerun 'Analyze Brackets' or check the Bracket Preview if stacking groups seem incorrect.

Best Practices for Bracketed Panoramas:
- Shoot on a tripod with manual exposure, consistent white balance, and 30–50% overlap.
- Keep bracket groups in order and avoid movement between frames.

Performance Tips:
- Match Max Workers to available CPU cores.
- Disable preview or shorten its delay for faster stacking.
- Close other intensive applications during large analyses.
]]

LrFunctionContext.callWithContext('WAI_About', function(context)
  local f = LrView.osFactory()
  LrDialogs.presentModalDialog {
    title = 'WildlifeAI Help',
    contents = f:scrolled_view {
      width = 500,
      height = 400,
      horizontal_scroller = false,
      vertical_scroller = true,
      f:static_text { title = helpText }
    }
  }
end)

