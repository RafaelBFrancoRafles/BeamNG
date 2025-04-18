-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M ={}
local logTag = 'spawn.lua'
M.settingsFilePath = 'settings/cloud/game-state.json'

--[[
this function save selected spawnpoint into settings/cloud/game-state.json
@param defaultSPName :string represent spawnpoint name (Editor name)
@param levelName :string stores level name
]]
local function setDefaultSP(defaultSPName, levelName)
  levelName = levelName:lower() or core_levels.getLevelName(getMissionFilename()) -- select spawnpoint from level menu
  local data = jsonReadFile(M.settingsFilePath) or {}
  data.lastLevelName = levelName
  data.levels = data.levels or {}
  data.levels[levelName] = data.levels[levelName] or {}
  data.levels[levelName].defaultSpawnPointName = defaultSPName
  local res = jsonWriteFile(M.settingsFilePath, data, true)
  if not res then
    log('W', "setDefaultSP ", "unable to save default spawnPoint")
  end
end

--[[
this function returns defaultSpawnPointName if exist otherwise return empty string
]]
local function loadDefaultSpawnpoint(levelName)
  local levelName = levelName or core_levels.getLevelName(getMissionFilename())
  local levelInfo = jsonReadFile(path.getPathLevelInfo(levelName))
  if not levelInfo then
    log('E', 'spawnpoint', 'unable to read mission info: ' .. tostring(levelname))
    return ''
  end

  levelInfo.spawnPoints = levelInfo.spawnPoints or {}
  local data = jsonReadFile(M.settingsFilePath) or {}
  data.levels = data.levels or {}
  data.levels[levelName] = data.levels[levelName] or {}

  local dataLevel = data.levels[levelName]
  for k, v in ipairs(levelInfo.spawnPoints) do
    if v.objectname == dataLevel.defaultSpawnPointName then
      local SP=scenetree.findObject(dataLevel.defaultSpawnPointName)
      if SP then
        return dataLevel.defaultSpawnPointName
      else
          log('W', logTag, tostring(dataLevel.defaultSpawnPointName)..' not in the mission file spawn vehicle in the default position')
      end
    end
  end

  return levelInfo.defaultSpawnPointName or ''
end

local function getLastLevelName()
  return (jsonReadFile(M.settingsFilePath) or {}).lastLevelName
end

M.setDefaultSP = setDefaultSP
M.loadDefaultSpawnpoint = loadDefaultSpawnpoint
M.getLastLevelName = getLastLevelName
return M
