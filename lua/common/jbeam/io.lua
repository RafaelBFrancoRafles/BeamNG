--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local jbeamUtils = require("jbeam/utils")
local jbeamTableSchema = require('jbeam/tableSchema')
local json = require("json")

local fileCacheOld = {}
local fileCache -- it is nil so that we don't cache everything on first load
local jbeamCache = {}
local partFileMap = {}
local partSlotMap = {}
local partNameMap = {}
local modManager = nil
local invalidatedCache = false


local function parseFile(filename)
  local content = fileCacheOld[filename] or readFile(filename)
  if fileCache then
    fileCache[filename] = content
  end
  if content then
    local ok, data = pcall(json.decode, content)
    if ok == false then
      log('E', "jbeam.parseFile","unable to decode JSON: "..tostring(filename))
      log('E', "jbeam.parseFile","JSON decoding error: "..tostring(data))
      return nil
    end
    return data
  else
    log('E', "jbeam.parseFile","unable to read file: "..tostring(filename))
  end
end

local function processSlotsV1DestructiveBackwardCompatibility(slots, newSlots)
  local addedSlots = 0
  for k, slotSectionRow in ipairs(slots) do
    if slotSectionRow[1] == "type" then goto continue end -- ignore the header

    local slot = {}

    slot.type = slotSectionRow[1]
    slot.default = slotSectionRow[2]
    slot.description = slot.type

    if #slotSectionRow > 2 and type(slotSectionRow[3]) == 'string' then
      slot.description = slotSectionRow[3]
    end
    if #slotSectionRow > 3 and type(slotSectionRow[4]) == 'table' then
      tableMerge(slot, slotSectionRow[4])
    end
    table.insert(newSlots, slot)
    addedSlots = addedSlots + 1

    ::continue::
  end
  return addedSlots
end

local function _processSlotsDestructiveLegacy(part, sourceFilename)
  if type(part.slots) ~= 'table' then return nil end

  local newSlots = {}
  if #part.slots > 0 and type(part.slots[1]) == 'table' and part.slots[1][1] ~= 'type' then
    -- backward compatibility: some parts miss the table header, which worked due to limitations before.
    log('W', 'slotSystem', 'Slot section of part ' .. tostring(part.partName) .. ' in file ' .. tostring(sourceFilename) ..' misses the table header. Adding default: ["type", "default", "description"]. Please fix.')
    table.insert(part.slots, 1, {"type", "default", "description"})
  end
  local newListSize = jbeamTableSchema.processTableWithSchemaDestructive(part.slots, newSlots)
  if newListSize < 0 then
    -- fallback: use old code for old mods with errors
    newSlots = {}
    newListSize = processSlotsV1DestructiveBackwardCompatibility(part.slots, newSlots)
    if newListSize < 0 then
      log('E', "", "Slots section in file " .. tostring(sourceFilename) .. " invalid. Unable to recover: " .. dumpsz(part.slots, 2))
    else
      log('W', "", "Slots section in file " .. tostring(sourceFilename) .. " invalid. Please fix. Partly reconstructed: " .. dumpsz(part.slots, 2))
    end
  end
  part.slots = newSlots
end

-- this function processes the slots / slots2
local function processSlotsDestructive(part, sourceFilename)
  if type(part.slots) ~= 'table' and type(part.slots2) ~= 'table' then return nil end

  if part.slots then
    _processSlotsDestructiveLegacy(part, sourceFilename)
    -- now upgrade to the new slots2 data structure
    for _, slot in ipairs(part.slots) do
      slot.name = slot.name or slot.type
      slot.allowTypes = {slot.type}
      slot.type = nil
      slot.denyTypes = {}
    end
    part.slots2 = part.slots
    part.slots = nil
  elseif part.slots2 then
    -- slots 2
    -- ["name", "allowTypes", "denyTypes", "default", "description"],
    local newSlots2 = {}
    local newListSize = jbeamTableSchema.processTableWithSchemaDestructive(part.slots2, newSlots2)
    if newListSize < 0 then
      log('E', "", "Slots section in file " .. tostring(sourceFilename) .. " invalid. Unable to recover: " .. dumpsz(part.slots2, 2))
    end
    part.slots2 = newSlots2
  end
  -- from here on we only have slots2 available
end


-- this filters the data we send to the UI as there is a lot of additonal data in there that we do not want
local function getSlotInfoDataForUi(slots)
  local res = table.new(0, #slots)
  for _, slot in ipairs(slots) do
    local s = {}
    s.name = slot.name or slot.type -- slots2 - new feature for uniquely identifying slots
    s.type = slot.type -- slots1, replaced by allowTypes and denyTypes
    --s.default = slot.default,
    s.allowTypes = slot.allowTypes -- slots2
    s.denyTypes = slot.denyTypes  -- slots2
    s.description = slot.description
    s.coreSlot = slot.coreSlot
    res[slot.name or slot.type] = s
  end
  return res    
end

local function loadJBeamFile(dir, filename, addToCache)
  local fileContent = parseFile(filename)
  if not fileContent then
    log('E', "jbeam.loadJBeamFile", "cannot read file: "..tostring(filename))
    return nil
  end
  jbeamCache[filename] = fileContent
  local partCount = 0
  for partName, part in pairs(fileContent) do
    partCount = partCount + 1
    part.partName = partName
    
    -- this processes the slot and slot2 section
    processSlotsDestructive(part, filename)
    local slotInfoUi = getSlotInfoDataForUi(part.slots2 or {})

    if addToCache then
      if not partFileMap[dir] then
        partFileMap[dir] = {}
        partSlotMap[dir] = {}
        partNameMap[dir] = {}
      end
      if type(part.slotType) ~= 'string' and type(part.slotType) ~= 'table' then
        log('E', "jbeam.loadJBeamFile", "part does not have a slot type. Ignoring: "..tostring(filename))
        goto continue
      end
      -- support for a part that fits in the correct slottype
      local slotTypes = {}
      if type(part.slotType) == 'string' then
        table.insert(slotTypes, part.slotType)
      elseif type(part.slotType) == 'table' then
        slotTypes = part.slotType
      end
      for _, slotType in ipairs(slotTypes) do
        partSlotMap[dir][slotType] = partSlotMap[dir][slotType] or {}
        local partDesc = {
          description = part.information.name or "",
          authors = part.information.authors or "",
          isAuxiliary = part.information.isAuxiliary,
          slotInfoUi = slotInfoUi
        }
        if modManager then -- only available on the game engine side
          -- enrich the part with modName and ID
          local modName, modInfo = modManager.getModForFilename(filename)
          if modName then
            partDesc.modName = modName
            --partDesc.modID   = modInfo.modID
            --partDesc.modInfo = modInfo -- too much data
          end
        end

        if tableContains(partSlotMap[dir][slotType], partName) then
          if partFileMap[dir][partName] and tableSize(fileContent) > tableSize(jbeamCache[partFileMap[dir][partName]]) then
            partFileMap[dir][partName] = filename
            partNameMap[dir][partName] = partDesc
          end
          log('E', 'jbeam.loadJBeamFile', 'Duplicate part found: ' .. tostring(partName) .. ' from file ' .. tostring(filename))
        else
          partFileMap[dir][partName] = filename
          partNameMap[dir][partName] = partDesc
          table.insert(partSlotMap[dir][slotType], partName)
        end
      end
      ::continue::
    end
  end
  return partCount
end

local function startLoading(directories)
  profilerPushEvent('jbeam/io.startLoading')

  --log('D', "jbeam.startLoading", "*** loading jbeam files: " .. dumps(directories))

  for _, dir in ipairs(directories) do
    if not partFileMap[dir] then
      local partCountTotal = 0
      local filenames = FS:findFiles(dir, "*.jbeam", -1, false, false)
      for _, filename in ipairs(filenames) do
        local partCount = loadJBeamFile(dir, filename, true) or 0
        partCountTotal = partCountTotal + partCount
      end
      --log('D', 'jbeam.startLoading', "Loaded " .. tostring(partCountTotal) .. " parts from " .. tostring(tableSize(jbeamCache)) .. ' jbeam files in ' .. tostring(dir))
    end
  end
  profilerPopEvent() -- jbeam/io.startLoading

  return { preloadedDirs = directories }
end

local function getPart(ioCtx, partName)
  if not partName then return end
  for _, dir in ipairs(ioCtx.preloadedDirs) do
    local jbeamFilename = partFileMap[dir][partName]
    if jbeamFilename then
      if not jbeamCache[jbeamFilename] then
        local partCount = loadJBeamFile(dir, jbeamFilename)
        log('D', 'jbeam.getPart', "Loaded " .. tostring(partCount) .. " part(s) from file " .. tostring(jbeamFilename))
      end
      if jbeamCache[jbeamFilename] then
        return jbeamCache[jbeamFilename][partName], jbeamFilename
      end
    end
  end
end

local function isContextValid(ioCtx)
  return type(ioCtx.preloadedDirs) == 'table'
end

local function getMainPartName(ioCtx)
  if not isContextValid(ioCtx) then return end
  for _, dir in ipairs(ioCtx.preloadedDirs) do
    if partSlotMap[dir]['main'] then
      return partSlotMap[dir]['main'][1]
    end
  end
end

local function finishLoading()
  table.clear(jbeamCache)
  fileCacheOld = fileCache or {}
  fileCache = {}
end

local function getAvailableParts(ioCtx)
  if not isContextValid(ioCtx) then return end

  local res = {}
  local loaded = false
  for _, dir in ipairs(ioCtx.preloadedDirs) do
    if not partSlotMap[dir] then
      startLoading(ioCtx.preloadedDirs)
      loaded = true
    end
    -- merge manually to catch errors
    for partName, partDesc in pairs(partNameMap[dir]) do
      if res[partName] then
        log('E', "jbeam.getAvailableParts", "parts names are duplicate: " .. tostring(partName) .. ' in folders: ' .. dumps(ioCtx.preloadedDirs))
      end
      res[partName] = partDesc
    end
  end
  if loaded then finishLoading() end
  return res
end

local function getAvailableSlotMap(ioCtx)
  if not isContextValid(ioCtx) then return end

  local res = {}
  local loaded = false
  for _, dir in ipairs(ioCtx.preloadedDirs) do
    if not partSlotMap[dir] then
      startLoading(ioCtx.preloadedDirs)
      loaded = true
    end
    -- merge manually to catch errors
    for slotName, partList in pairs(partSlotMap[dir]) do
      if not res[slotName] then res[slotName] = {} end
      for _, partName  in ipairs(partList) do
        for _, partName2  in ipairs(res[slotName]) do
          if partName == partName2 then
            log('E', "jbeam.getAvailableSlotMap", "parts names are duplicate: " .. tostring(partName) .. ' in folders: ' .. dumps(ioCtx.preloadedDirs))
          end
        end
        table.insert(res[slotName], partName)
      end
    end
  end
  if loaded then finishLoading() end
  return res
end


local function onFileChanged(filename, type)
  local dir = string.match(filename, "(/vehicles/[^/]*/).*$") -- yeah it's weird to have no leading slash :/
  local _, _, ext = path.split(filename)
  if ext ~= 'jbeam' then return end
  fileCacheOld[filename] = nil

  if dir and (partFileMap[dir] or partSlotMap[dir] or partNameMap[dir]) then
    log('I', 'jbeamIO.onFileChanged', 'cache reset for path: ' .. tostring(dir) .. ' due to file change: ' .. tostring(filename) .. ' (' .. tostring(type) .. ')')
    partFileMap[dir] = nil
    partSlotMap[dir] = nil
    partNameMap[dir] = nil
    if dir == "/vehicles/common/" then
      log('I', 'jbeamIO.onFileChanged', 'cache FULL reset')
      partFileMap = {}
      partSlotMap = {}
      partNameMap = {}
    end
    invalidatedCache = true
    -- jbeamCache = nil -- not needed
  end
end

local function onFileChangedEnd()
  if invalidatedCache then
    invalidatedCache = false
    guihooks.trigger("VehicleJbeamIoChanged") --propagate change to partmgmt UI
  end
end

local function onExtensionLoaded()
  modManager = extensions.core_modmanager
end

M.onExtensionLoaded = onExtensionLoaded
M.onFileChanged = onFileChanged
M.onFileChangedEnd = onFileChangedEnd

M.startLoading = startLoading
M.finishLoading = finishLoading
M.getPart = getPart
M.getMainPartName = getMainPartName

M.getAvailableParts = getAvailableParts
M.getAvailableSlotMap = getAvailableSlotMap

return M