-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local triggerTypeNames = {"Box", "Sphere"}

local C = {}

C.name = 'WOSSOM Trigger'
C.color = ui_flowgraph_editor.nodeColors.event
C.icon = ui_flowgraph_editor.nodeIcons.event
C.description = 'Creates a trigger for the time of the execution of the project.'
C.category = 'repeat_instant'

C.todo = "Maybe this should be merged with the onBeamNGTrigger node. Currently only works when a vehicle ID is supplied."
C.pinSchema = {
  {dir = 'in', type = 'vec3', name = 'position', description = "The position of this trigger."},
  {dir = 'in', type = 'quat', name = 'rotation', description = "The orientation of this trigger (if box)"},
  {dir = 'in', type = {'number','vec3'}, name = 'scale', description = "The scale of this trigger."},
  {dir = 'in', type = 'number', name = 'vehId', description = "The ID of the target vehicle; works for exactly one vehicle at a time."},
  {dir = 'out', type = 'flow', name = 'enter', description = "Triggers once when the vehicle enters the trigger.", impulse = true},
  {dir = 'out', type = 'flow', name = 'inside', description = "Gives flow as long as the vehicle is inside the trigger."},
  {dir = 'out', type = 'flow', name = 'outside', description = "Gives flow as long as the vehicle is outside the trigger."},
  {dir = 'out', type = 'flow', name = 'exit', description = "Triggers once when the vehicle exits the trigger.", impulse = true},
  {dir = 'out', type = 'number', name = 'vehId', description = "The vehicle this trigger is for."},
  {dir = 'out', type = 'flow', name = 'vehicleLeftContinuous', description = "Gives flow as long as the vehicle is outside the trigger after entering once."}, -- New continuous pin
}
C.legacyPins = {
  _in = {
    vehicleId = 'vehId'
  },
  out = {
    vehicleId = 'vehId'
  }
}

C.tags = {}

function C:init(mgr, ...)
  self.enterFlag = false
  self.exitFlag = false
  self.hasEntered = false -- New flag to track if the vehicle has entered
  self.vehInside = false
  self.oldPos = nil
  self.oldScl = nil
  self.triggerType = triggerTypeNames[1]
  self.data.highPrecision = false
  self.data.debug = false
end

function C:_executionStarted()
  self.enterFlag = false
  self.exitFlag = false
  self.hasEntered = false -- Reset the flag
  self.vehInside = false
  self.dirty = true
  self.points = nil
end

function C:_executionStopped()
  self.oldPos = nil
  self.oldScl = nil
  self.points = nil
end

function C:checkIntersections()
  local inside = false
  for _, pos in ipairs(self.points) do
    if self.trigger.type == 'Box' then
      inside = inside or containsOBB_point(self.trigger.pos, self.trigger.x, self.trigger.y, self.trigger.z, pos)
    else
      inside = inside or containsEllipsoid_Point(self.trigger.pos, self.trigger.x, self.trigger.y, self.trigger.z, pos)
    end
    if inside then break end
  end

  self.enterFlag = false
  self.exitFlag = false

  if not self.vehInside and inside then
    self.enterFlag = true
    self.hasEntered = true -- Set the flag when the vehicle enters
  end
  if self.vehInside and not inside then
    self.exitFlag = true
  end
  self.vehInside = inside
end

function C:work(args)
  if self.pinIn.position.value and self.oldPos and self.pinIn.position.value ~= self.oldPos then
    self.dirty = true
  end
  if self.pinIn.scale.value and self.oldScl and self.pinIn.scale.value ~= self.oldScl then
    self.dirty = true
  end
  if self.pinIn.rotation.value and self.oldRot and self.pinIn.rotation.value ~= self.oldRot then
    self.dirty = true
  end

  if self.dirty then
    local trigger = {
      pos = vec3(self.pinIn.position.value or {0,0,0}),
      rot = quat(self.pinIn.rotation.value or {0,0,0,0})
    }
    local scl = self.pinIn.scale.value or 1
    if type(scl) == 'table' then
      trigger.scl = vec3(self.pinIn.scale.value)
    else
      trigger.scl = vec3(self.pinIn.scale.value, self.pinIn.scale.value, self.pinIn.scale.value)
    end
    trigger.type = self.triggerType
    trigger.x = trigger.rot * vec3(trigger.scl.x,0,0)
    trigger.y = trigger.rot * vec3(0,trigger.scl.y,0)
    trigger.z = trigger.rot * vec3(0,0,trigger.scl.z)
    self.oldPos = self.pinIn.position.value
    self.oldRot = self.pinIn.rotation.value
    self.oldScl = self.pinIn.scale.value
    self.dirty = false
    self.trigger = trigger
  end

  local vehId = self.pinIn.vehId.value or be:getPlayerVehicleID(0)
  local noData = false
  if vehId and be:getObjectByID(vehId) then
    local veh = be:getObjectByID(vehId)

    if veh then
      if self.data.highPrecision then
        if not self.points then
          self.points = {vec3(), vec3(), vec3(), vec3()}
          self.zOffset = vec3()
          self.bbPoints = {0, 3, 7, 4}
        end
        local oobb = veh:getSpawnWorldOOBB()
        self.zOffset:set(veh:getDirectionVectorUp() * oobb:getHalfExtents().z) -- vertical midpoint of vehicle
        for i, v in ipairs(self.bbPoints) do
          self.points[i]:set(oobb:getPoint(v) + self.zOffset)
        end
      else
        if not self.points then
          self.points = {vec3()}
        end
        self.points[1]:set(veh:getPosition())
      end
      self:checkIntersections()
    else
      self.points = nil
      noData = true
    end
  else
    self.points = nil
    noData = true
  end

  self.pinOut.inside.value = self.vehInside
  self.pinOut.outside.value = not self.vehInside
  self.pinOut.enter.value = self.enterFlag
  self.pinOut.exit.value = self.exitFlag
  self.pinOut.vehId.value = vehId
  self.pinOut.vehicleLeftContinuous.value = self.hasEntered and not self.vehInside -- Set new pin value
  if noData then
    for _, p in pairs(self.pinOut) do p.value = nil end
  end
  if self.trigger and self.data.debug then
    if self.trigger.type == 'Box' then
      self:drawAxisBox(self.trigger.pos - (self.trigger.x + self.trigger.y + self.trigger.z), self.trigger.x*2, self.trigger.y*2, self.trigger.z*2, color(255, 128, 128, 64))
    elseif self.trigger.type == 'Sphere' then
      debugDrawer:drawSphere(self.trigger.pos, self.trigger.x:length(), ColorF(1,0.5,0.5,0.25))
    end
  end
end

function C:drawAxisBox(corner, x, y, z, clr)
  -- draw all faces in a loop
  for _, face in ipairs({{x,y,z},{x,z,y},{y,z,x}}) do
    local a,b,c = face[1],face[2],face[3]
    -- spokes
    debugDrawer:drawLine((corner    ), (corner+c    ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+a  ), (corner+c+a  ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+b  ), (corner+c+b  ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+a+b), (corner+c+a+b), ColorF(0,0,0,0.75))
    -- first side
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+a  ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner+b  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    -- back of first side
    debugDrawer:drawTriSolid(
      vec3(corner+a  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+b  ),
      vec3(corner+a+b),
      clr)
    -- other side
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+a  ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner+b  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    -- back of other side
    debugDrawer:drawTriSolid(
      vec3(c+corner+a  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+b  ),
      vec3(c+corner+a+b),
      clr)
  end
end

function C:drawCustomProperties()
  local reason = nil
  im.PushID1("LAYOUT_COLUMNS")
  im.Columns(2, "layoutColumns")
  im.Text("Status")
  im.NextColumn()
  if im.BeginCombo("##triggerType", self.triggerType) then
    for _,triggerType in ipairs(triggerTypeNames) do
      if im.Selectable1(triggerType, triggerType == self.triggerType) then
        self.triggerType = triggerType
        reason = "Changed Trigger Type to " .. triggerType
      end
    end
    im.EndCombo()
  end
  im.Columns(1)
  im.PopID()
  return reason
end

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:_onSerialize(res)
  res.triggerType = self.triggerType
end

function C:_onDeserialized(res)
  if res.triggerType then
    self.triggerType = res.triggerType
  end
end

return _flowgraph_createNode(C)