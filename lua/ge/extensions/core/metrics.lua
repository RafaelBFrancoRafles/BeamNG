-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {"ui_imgui", "ui_visibility"}
M.currentMode = 0 -- 0 disabled, 1 small, 2 full

local im = ui_imgui
local pos = im.ImVec2(0, 0)
local padding = im.ImVec2(10, 0)
local sizeMin = im.ImVec2(0, 0)
local sizeMax = im.ImVec2(-1, -1)

local function toggle()
  M.currentMode = (M.currentMode+1) % 4
  if M.currentMode == 0 then
    extensions.unload(M)
  end
end

local function getConsoleNumber(varName)
  local result = getConsoleVariable(varName)
  return result == "" and -1 or result
end
local function onUpdate(dtReal, dtSim, dtRaw)
  if M.currentMode == 0 then return end
  local win = im.GetMainViewport()
  local imguiVisible = ui_visibility.getImgui()
  local lines = imguiVisible or {}

  -- set position
  local posX = 14
  local posY = 44
  pos.x = win.Pos.x + posX
  pos.y = win.Pos.y + posY
  im.SetNextWindowPos(pos, im.ImGuiCond_Always)

  -- limit size
  sizeMax.x = win.Size.x - posX
  sizeMax.y = win.Size.y - posY
  if M.currentMode == 1 then
    sizeMax.y = 15
  end
  im.SetNextWindowSizeConstraints(sizeMin, sizeMax)

  -- reduce padding and set bg
  im.PushStyleVar2(im.StyleVar_WindowPadding, padding)
  im.SetNextWindowBgAlpha(0.85)

  -- draw panel window
  if im.Begin("##metricsWindow", nil, im.WindowFlags_AlwaysAutoResize+im.WindowFlags_NoResize+im.WindowFlags_NoMove+im.WindowFlags_NoCollapse+im.WindowFlags_NoDocking+im.WindowFlags_NoTitleBar) then
    local lineTexts = imguiVisible or {}
    local lineText
    local rnd = settings.getValue("FPSLimiterEnabled") and settings.getValue("FPSLimiterRandomness") or 0
    im.SetCursorPosY(-4)
    -- minimum stats
    if M.currentMode == 1 then
      lineText = string.format("FPS: %5.1f [Avg %5.1f | Min %5.1f | Max %5.1f%s]", getConsoleNumber("fps::instantaneous"), getConsoleNumber("fps::avg"), getConsoleNumber("fps::min"), getConsoleNumber("fps::max"), rnd == 0 and "" or ", randomness "..rnd.."%")
      im.TextUnformatted(lineText)
      if not imguiVisible then table.insert(lines, lineText) end
    end
    -- simple stats
    if M.currentMode > 1 then
      local nCols = 14
      local columnText
      if im.BeginTable("##metricsSimpleTable", nCols, tableFlags) then
        im.TableNextColumn()
        columnText = string.format("FPS:")
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("%5.1f fps [Unmanaged: %5.1f fps]", getConsoleNumber("fps::instantaneous"), getConsoleNumber("fps::instantaneousUncap"))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("Avg")
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("%5.1f fps", getConsoleNumber("fps::avg"))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("10%% Below")
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("%5.1f fps",getConsoleNumber("fps::p90"))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("5%% Below")
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("%5.1f fps", getConsoleNumber("fps::p95"))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("1%% Below")
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("%5.1f fps", getConsoleNumber("fps::p99"))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("Min")
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("%5.1f fps", getConsoleNumber("fps::min"))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("Max")
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("%5.1f fps", getConsoleNumber("fps::max"))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        if not imguiVisible then table.insert(lines, table.concat(lineTexts, "  ")) end
        lineTexts = imguiVisible or {}
        -- second row
        im.TableNextColumn()
        columnText = string.format("DT:")
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        columnText = string.format("%5.2f ms [Unmanaged: %5.1f ms]", 1000 / getConsoleNumber("fps::instantaneous"), 1000 / getConsoleNumber("fps::instantaneousUncap"))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        im.TableNextColumn()
        columnText = string.format("%5.2f ms", 1000 / (getConsoleNumber("fps::avg")))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        im.TableNextColumn()
        columnText = string.format("%5.2f ms", 1000 / (getConsoleNumber("fps::p90")))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        im.TableNextColumn()
        columnText = string.format("%5.2f ms", 1000 / (getConsoleNumber("fps::p95")))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        im.TableNextColumn()
        columnText = string.format("%5.2f ms", 1000 / (getConsoleNumber("fps::p99")))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        im.TableNextColumn()
        columnText = string.format("%5.2f ms", 1000 / (getConsoleNumber("fps::min")))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        im.TableNextColumn()
        im.TableNextColumn()
        columnText = string.format("%5.2f ms", 1000 / (getConsoleNumber("fps::max")))
        if not imguiVisible then table.insert(lineTexts, columnText) end
        im.TextUnformatted(columnText)
        if not imguiVisible then table.insert(lines, table.concat(lineTexts, "  ")) end
        lineTexts = imguiVisible or {}
      im.EndTable()
      end

      lineText = string.format("WaitforGPU: %4.2f ms%s", getConsoleNumber("fps::waitForGPU"), rnd == 0 and "" or ", WARNING: RANDOMNESS="..rnd.."%")
      local managers = {}
      if render_openxr and render_openxr.isSessionRunning() then
        table.insert(managers, "OpenXR")
      else
        if settings.getValue("FPSLimiterEnabled") then table.insert(managers, "FPS limiter (normal)") end
        if settings.getValue("vsync") then table.insert(managers, "Vertical sync") end
        if not scenetree.MissionGroup then table.insert(managers, "FPS limiter (menu)") end
        if settings.getValue("SleepInBackground") and not Engine.isProgramFocused() then table.insert(managers, "FPS limiter (background)") end
      end
      if not next(managers) then
        table.insert(managers, "<none>")
      end
      lineText = lineText.."  Framerate Managed: "..table.concat(managers, ", ")
      im.TextUnformatted(lineText)
      if not imguiVisible then table.insert(lines, lineText) end

      im.SameLine()
      im.PushStyleColor2(im.Col_Button, im.GetStyleColorVec4(im.Col_ButtonHovered))
      if im.Button("Open Performance Graph ") then
        togglePerformanceGraph()
      end
      if im.IsItemHovered() then
        im.BeginTooltip()
        im.TextUnformatted("Also open with CTRL+SHIFT+F")
        im.EndTooltip()
      end
      im.PopStyleColor()

    end

    im.PushStyleColor2(im.Col_Text, im.ImVec4(1, 1, 1, 0.5))
    -- full stats
    if M.currentMode > 2 then
      lineText = string.format("GFX:  PolyCount: %d DrawCalls: %d  StateChanges: %d  RTChanges: %d",
        getConsoleNumber("$GFXDeviceStatistics::polyCount"), getConsoleNumber("$GFXDeviceStatistics::drawCalls"), getConsoleNumber("$GFXDeviceStatistics::drawStateChanges"), getConsoleNumber("$GFXDeviceStatistics::renderTargetChanges"))
      im.TextUnformatted(lineText)
      if not imguiVisible then table.insert(lines, lineText) end

      lineText = string.format("Terrain:  Cells: %d  Override Cells: %d  DrawCalls: %d",
      getConsoleNumber("$TerrainBlock::cellsRendered"), getConsoleNumber("$TerrainBlock::overrideCells"), getConsoleNumber("$TerrainBlock::drawCalls"))
      im.TextUnformatted(lineText)
      if not imguiVisible then table.insert(lines, lineText) end

      lineText = string.format("GroundCover:  Cells: %d  Billboards: %d  Batches: %d  Shapes: %d",
      getConsoleNumber("$GroundCover::renderedCells"), getConsoleNumber("$GroundCover::renderedBillboards"), getConsoleNumber("$GroundCover::renderedBatches"), getConsoleNumber("GroundCover::renderedShapes"))
      im.TextUnformatted(lineText)
      if not imguiVisible then table.insert(lines, lineText) end

      lineText = string.format("Forest:  Cells: %d  Cells Meshed: %d  Cells Billboarded: %d  Meshes: %d  Billboards: %d",
      getConsoleNumber("$Forest::totalCells"), getConsoleNumber("$Forest::cellsRendered"), getConsoleNumber("$Forest::cellsBatched"), getConsoleNumber("$Forest::cellItemsRendered"), getConsoleNumber("$Forest::cellItemsBatched"))
      im.TextUnformatted(lineText)
      if not imguiVisible then table.insert(lines, lineText) end

      lineText = string.format("Shadow:  Active: %d  Updated: %d  PolyCount: %d  DrawCalls: %d  StateChanges: %d  RTChanges: %d",
      getConsoleNumber("$ShadowStats::activeMaps"), getConsoleNumber("$ShadowStats::updatedMaps"), getConsoleNumber("$ShadowStats::polyCount"), getConsoleNumber("$ShadowStats::drawCalls"), getConsoleNumber("$ShadowStats::drawStateChanges"), getConsoleNumber("$ShadowStats::rtChanges"))
      im.TextUnformatted(lineText)
      if not imguiVisible then table.insert(lines, lineText) end

      lineText = string.format("LightManager:  Active: %d  Updated: %d  Elapsed Ms: %5.2f",
      getConsoleNumber("$BasicLightManagerStats::activePlugins"), getConsoleNumber("$BasicLightManagerStats::shadowsUpdated"), getConsoleNumber("$BasicLightManagerStats::elapsedUpdateTime") * 1000)
      im.TextUnformatted(lineText)
      if not imguiVisible then table.insert(lines, lineText) end

      lineText = string.format("Deferred Lights:  Active: %d  Culled: %d",
      getConsoleNumber("$lightMetrics::activeLights"), getConsoleNumber("$lightMetrics::culledLights"))
      im.TextUnformatted(lineText)
      if not imguiVisible then table.insert(lines, lineText) end
    end
    im.PopStyleColor()
  end
  im.End() --Begin
  im.PopStyleVar()
  if not imguiVisible then
    local pos = vec3(0, posY+36, 0)
    local fg = ColorF(0.9, 0.9, 0.9, 1)
    local bg = ColorI(64, 64, 64, 0.9*255)
    for i,line in ipairs(lines) do
      debugDrawer:drawTextAdvanced(pos, line, fg, true, true, bg)
      pos.y = pos.y + 19
    end
  end
end

local function onInit()
  setExtensionUnloadMode(M, "manual")
end

local function onSerialize()
  return { currentMode = M.currentMode }
end

local function onDeserialized(d)
  M.currrentMode = d.currentMode
end

M.onInit = onInit
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onUpdate = onUpdate

M.toggle = toggle

return M
