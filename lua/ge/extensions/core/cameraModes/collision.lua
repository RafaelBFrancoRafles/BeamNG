-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C
local safetyDistance = 0.1 -- camera will move this distance closer to the target, to help against stuff clipping into view from behind the camera

-- These are the assumed dimensions of the nearClip plane. TODO these could also be calculated using nearClip, window size and fov
local nearClipHalfWidth = 0.2
local nearClipHalfHeight = 0.1

local smoother
local upVec = vec3(0, 0, 1)
local fwdVec = vec3(0, 1, 0)
local lastDistance
local lastNearClipCenter
local useRaycast = true
local collidingCamDist

function C:init()
  lastDistance = nil
  lastNearClipCenter = nil
  useRaycast = true
  self.isFilter = true
  self.hidden = true
  smoother = nil
  collidingCamDist = nil
end

local dirTemp = vec3()
local function isObstacleInFrontOfCam(rayDestinations)
  -- Test if we passed through a wall completely in one frame
  if lastNearClipCenter then
    dirTemp:setSub2(rayDestinations[1], lastNearClipCenter)
    local rayDist = dirTemp:length()
    if castRayStatic(lastNearClipCenter, dirTemp, rayDist) < rayDist then
      return true
    end
  end
  -- Test for geometry intersecting with the near clip plane
  for i, cornerPos in ipairs(rayDestinations) do
    local rayDest = rayDestinations[(i % 4) + 1]
    dirTemp:setSub2(rayDest, cornerPos)
    local dirLength = dirTemp:length()
    local distHit = castRayStatic(cornerPos, dirTemp, dirLength)
    if distHit < dirLength then
      return true
    end
  end
  return false
end

local rayDestinations = {vec3(), vec3(), vec3(), vec3()}
local camDir, camRight, camUp, dir, nearClipCenter, rayStart, newCamPos = vec3(), vec3(), vec3(), vec3(), vec3(), vec3(), vec3()
function C:update(data)
  if not settings.getValue('cameraCollision', true) then return end
  local assumedNearClipDist = data.res.nearClip - safetyDistance
  camDir:setRotate(data.res.rot, fwdVec)
  camUp:setRotate(data.res.rot, upVec)
  camDir:normalize()
  camUp:resize(nearClipHalfHeight)
  camRight:setCross(camDir, camUp)
  camRight:resize(nearClipHalfWidth)

  dir:set(push3(data.res.pos) - data.res.targetPos)
  local dirLength = dir:length()

  -- Calculate nearClip dimensions
  nearClipCenter:set(push3(data.res.targetPos) + push3(dir) * ((dirLength - assumedNearClipDist) / dirLength))

  -- set the ray destinations
  rayDestinations[1]:set(nearClipCenter); rayDestinations[1]:setAdd(camUp); rayDestinations[1]:setAdd(camRight)
  rayDestinations[2]:set(nearClipCenter); rayDestinations[2]:setSub(camUp); rayDestinations[2]:setAdd(camRight)
  rayDestinations[3]:set(nearClipCenter); rayDestinations[3]:setSub(camUp); rayDestinations[3]:setSub(camRight)
  rayDestinations[4]:set(nearClipCenter); rayDestinations[4]:setAdd(camUp); rayDestinations[4]:setSub(camRight)

  if not useRaycast and isObstacleInFrontOfCam(rayDestinations) then
    useRaycast = true
  end

  local closestHit = dirLength
  local hitRegistered
  if useRaycast then
    -- Make 4 parallel raycasts from the targetPos to the camera pos and position the camera based on the closest hit
    for i, cornerPos in ipairs(rayDestinations) do
      rayStart:setSub2(cornerPos, dir)
      local distHit = castRayStatic(rayStart, dir, closestHit)
      if distHit < closestHit then
        closestHit = distHit
        hitRegistered = rayStart
      end
    end
    closestHit = math.max(closestHit, 0.5)
  end

  if not hitRegistered then
    useRaycast = false
  end

  if not smoother then
    smoother = newTemporalSmoothingNonLinear(1, 7, 0)
    smoother:set(closestHit)
  end

  local smoothedDistance = closestHit
  if lastDistance then
    local camDestDiff = (closestHit - lastDistance)
    if camDestDiff >= 0 then
      smoothedDistance = smoother:get(closestHit, data.dtReal)
    else
      smoother:set(smoothedDistance)
    end
  end

  lastDistance = smoothedDistance
  lastNearClipCenter = lastNearClipCenter or vec3()
  lastNearClipCenter:set(nearClipCenter)
  newCamPos:set(push3(data.res.targetPos) + push3(dir):normalized() * (smoothedDistance + assumedNearClipDist))
  if useRaycast then
    collidingCamDist = newCamPos:distance(data.res.targetPos)
  else
    collidingCamDist = nil
  end
  data.res.pos = newCamPos
end

function C:onVehicleSwitched()
  self:init()
end

function C:collidingCamDistance()
  return collidingCamDist
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
