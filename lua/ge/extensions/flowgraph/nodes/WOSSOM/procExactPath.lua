-- Load the ImGui module for Flowgraph node UI
local im = ui_imgui

local C = {}

C.name = 'Procedural Exact CamPath'
C.description = "Creates a cam path that travels directly and precisely between two positions, then starts it immediately."
C.category = 'once_p_duration'
C.tags = {}
C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera

C.pinSchema = {
    { dir = 'in',  type = 'number',  name = 'duration',       description = 'Total duration (seconds)', default = 5 },
    { dir = 'in',  type = 'bool',    name = 'loop',           description = 'Whether the path should loop.', default = false },

    { dir = 'in',  type = 'vec3',    name = 'startPosition',  description = 'Optional input for start position (overrides UI value)' },
    { dir = 'in',  type = 'quat',    name = 'startRotation',  description = 'Optional input for start rotation (overrides UI value)' },
    { dir = 'in',  type = 'vec3',    name = 'endPosition',    description = 'Optional input for end position (overrides UI value)' },
    { dir = 'in',  type = 'quat',    name = 'endRotation',    description = 'Optional input for end rotation (overrides UI value)' },
    { dir = 'in',  type = 'number',  name = 'startFOV',       description = 'Optional input for start FOV (default 65)' },
    { dir = 'in',  type = 'number',  name = 'endFOV',         description = 'Optional input for end FOV (default 65)' },

    { dir = 'out', type = 'string',  name = 'pathName',       description = 'Name of the camera path.' },
    { dir = 'out', type = 'number',  name = 'id',             description = 'Path ID that was activated.' },
    { dir = 'out', type = 'flow',    name = 'activated',      description = 'Triggered when the path is activated.' },
    { dir = 'out', type = 'flow',    name = 'inactive',       description = 'Fired when path finishes (future use).' },
    { dir = 'out', type = 'number',  name = 'playDuration',   description = 'Duration used to play the path.' },
}

function C:init()
  self.positionStart = vec3(0,0,0)
  self.positionEnd = vec3(0,0,0)
  self.rotationStart = quat(0,0,0,1)
  self.rotationEnd = quat(0,0,0,1)
  self.fovStart = 65
  self.fovEnd = 65
end

function C:drawCustomProperties()
  im.Text("Start Position")
  local posA = im.ArrayFloat(3)
  posA[0], posA[1], posA[2] = self.positionStart.x, self.positionStart.y, self.positionStart.z
  if im.DragFloat3("##StartPos"..self.id, posA, 0.5) then
    self.positionStart:set(posA[0], posA[1], posA[2])
  end
  if im.Button("Set Start Pos from Camera") then
    self.positionStart = vec3(core_camera.getPosition())
  end
  im.SameLine()
  if im.Button("Preview Start") then
    core_camera.setPosRot(0, self.positionStart.x, self.positionStart.y, self.positionStart.z, self.rotationStart.x, self.rotationStart.y, self.rotationStart.z, self.rotationStart.w)
    core_camera.setFOV(0, self.fovStart)
  end

  im.Separator()
  im.Text("Start Rotation")
  local rotA = im.ArrayFloat(4)
  rotA[0], rotA[1], rotA[2], rotA[3] = self.rotationStart.x, self.rotationStart.y, self.rotationStart.z, self.rotationStart.w
  if im.DragFloat4("##StartRot"..self.id, rotA, 0.05) then
    self.rotationStart = quat(rotA[0], rotA[1], rotA[2], rotA[3]):normalized()
  end
  if im.Button("Set Start Rot from Camera") then
    self.rotationStart = core_camera.getQuat()
  end

  im.Separator()
  im.Text("Start FOV")
  local fovA = im.FloatPtr(self.fovStart or 65)
  if im.DragFloat("##StartFOV"..self.id, fovA, 0.1, 1, 179) then
    self.fovStart = fovA[0]
  end
  if im.Button("Set Start FOV from Camera") then
    self.fovStart = core_camera.getFovDeg()
  end

  im.Separator()
  im.Text("End Position")
  local posB = im.ArrayFloat(3)
  posB[0], posB[1], posB[2] = self.positionEnd.x, self.positionEnd.y, self.positionEnd.z
  if im.DragFloat3("##EndPos"..self.id, posB, 0.5) then
    self.positionEnd:set(posB[0], posB[1], posB[2])
  end
  if im.Button("Set End Pos from Camera") then
    self.positionEnd = vec3(core_camera.getPosition())
  end
  im.SameLine()
  if im.Button("Preview End") then
    core_camera.setPosRot(0, self.positionEnd.x, self.positionEnd.y, self.positionEnd.z, self.rotationEnd.x, self.rotationEnd.y, self.rotationEnd.z, self.rotationEnd.w)
    core_camera.setFOV(0, self.fovEnd)
  end

  im.Separator()
  im.Text("End Rotation")
  local rotB = im.ArrayFloat(4)
  rotB[0], rotB[1], rotB[2], rotB[3] = self.rotationEnd.x, self.rotationEnd.y, self.rotationEnd.z, self.rotationEnd.w
  if im.DragFloat4("##EndRot"..self.id, rotB, 0.05) then
    self.rotationEnd = quat(rotB[0], rotB[1], rotB[2], rotB[3]):normalized()
  end
  if im.Button("Set End Rot from Camera") then
    self.rotationEnd = core_camera.getQuat()
  end

  im.Separator()
  im.Text("End FOV")
  local fovB = im.FloatPtr(self.fovEnd or 65)
  if im.DragFloat("##EndFOV"..self.id, fovB, 0.1, 1, 179) then
    self.fovEnd = fovB[0]
  end
  if im.Button("Set End FOV from Camera") then
    self.fovEnd = core_camera.getFovDeg()
  end
end

function C:workOnce()
  local m = {
    fov = 60,
    movingEnd = true,
    movingStart = true,
    pos = {},
    rot = {},
    time = 0,
    trackPosition = false
  }

  local duration = self.pinIn.duration.value or 5
  local loop = self.pinIn.loop.value or false

  local posStart = self.pinIn.startPosition.value or self.positionStart
  local posEnd = self.pinIn.endPosition.value or self.positionEnd
  local rotStart = self.pinIn.startRotation.value or self.rotationStart
  local rotEnd = self.pinIn.endRotation.value or self.rotationEnd
  local fovStart = self.pinIn.startFOV.value or self.fovStart or 65
  local fovEnd = self.pinIn.endFOV.value or self.fovEnd or 65

  local start = deepcopy(m)
  start.pos = posStart
  start.rot = rotStart
  start.time = 0
  start.fov = fovStart
  start.movingStart = false

  local mid = deepcopy(m)
  mid.pos = (posStart + posEnd) * 0.5
  mid.rot = rotStart:slerp(rotEnd, 0.5)
  mid.fov = (fovStart + fovEnd) * 0.5
  mid.time = duration * 0.5

  local stop = deepcopy(m)
  stop.pos = posEnd
  stop.rot = rotEnd
  stop.time = duration
  stop.fov = fovEnd
  stop.movingEnd = false

  local path = {
    looped = loop,
    manualFov = true,
    markers = { start, mid, stop }
  }

  local fallbackId = tostring(math.random(100000,999999))
  local baseName = ((self.id and tostring(self.id)) or fallbackId) .. "_exactPath"
  local name = self.mgr.modules.camera:getUniqueName(baseName) or ("defaultPath_" .. fallbackId)

  self.mgr.modules.camera:addCustomPath(name, path, true)
  self.pinOut.pathName.value = name

  local id = self.mgr.modules.camera:findPath(name)
  self.mgr.modules.camera:startPath(id, false)
  self.pinOut.id.value = id
  self.pinOut.activated.value = true
  self.pinOut.playDuration.value = duration
  self.activatedFlag = true
  self:setDurationState('started')
end

function C:_onSerialize(res)
  res.posA = {self.positionStart.x, self.positionStart.y, self.positionStart.z}
  res.posB = {self.positionEnd.x, self.positionEnd.y, self.positionEnd.z}
  res.rotA = {self.rotationStart.x, self.rotationStart.y, self.rotationStart.z, self.rotationStart.w}
  res.rotB = {self.rotationEnd.x, self.rotationEnd.y, self.rotationEnd.z, self.rotationEnd.w}
  res.fovA = self.fovStart
  res.fovB = self.fovEnd
end

function C:_onDeserialized(nodeData)
  if nodeData.posA then self.positionStart = vec3(unpack(nodeData.posA)) end
  if nodeData.posB then self.positionEnd = vec3(unpack(nodeData.posB)) end
  if nodeData.rotA then self.rotationStart = quat(unpack(nodeData.rotA)) end
  if nodeData.rotB then self.rotationEnd = quat(unpack(nodeData.rotB)) end
  if nodeData.fovA then self.fovStart = nodeData.fovA end
  if nodeData.fovB then self.fovEnd = nodeData.fovB end
end

return _flowgraph_createNode(C)
