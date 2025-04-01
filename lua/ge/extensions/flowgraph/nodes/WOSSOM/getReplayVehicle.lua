local im = ui_imgui

local C = {}

C.name = 'Get Vehicle ID by Name'
C.description = 'Finds a vehicle in the SceneTree by object name (e.g., "clone") and returns its ID.'
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'objectName', description = 'Name of the object in the SceneTree (e.g., "clone")' },
  { dir = 'out', type = 'number', name = 'vehId', description = 'Vehicle ID or -1 if not found.' },
  { dir = 'out', type = 'bool', name = 'exists', description = 'True if the object was found.' },
}

function C:init()
end

function C:work()
  local name = self.pinIn.objectName.value
  local pinConnected = self.pinIn.objectName.pinConnected

  local searchOrder = {}

  -- If input is connected or manually provided, override search
  if pinConnected or (name and name ~= "") then
    table.insert(searchOrder, name)
  else
    -- Default search order
    searchOrder = {
      "clone",
      "SpawnedVehicles.clone",
      "playerVehicle",
      "SpawnedVehicles.playerVehicle"
    }
  end

  local found = false
  for _, searchName in ipairs(searchOrder) do
    local obj = scenetree.findObject(searchName)
    if obj and obj.getID then
      self.pinOut.vehId.value = obj:getID()
      self.pinOut.exists.value = true
      found = true
      break
    end
  end

  if not found then
    log("E", "GetVehicleIDByName", "Object not found in default search paths or manual name: " .. tostring(name))
    self.pinOut.vehId.value = -1
    self.pinOut.exists.value = false
  end
end

return _flowgraph_createNode(C)
