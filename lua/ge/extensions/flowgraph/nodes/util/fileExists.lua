-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'File Exists'
C.description = "Checks if a file exists."
C.category = 'once_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'file', description = 'Defines the file path or name to check.' },
  { dir = 'in', type = 'string', name = 'extension', hidden = true, description = '(Optional) Appends an extension to the file string input.' },
  { dir = 'out', type = 'flow', name = 'exists', description = 'If the file exists' },
  { dir = 'out', type = 'flow', name = 'missing', description = 'If the file exists' },
  { dir = 'out', type = 'bool', name = 'existsBool', description = 'If the file exists' },
  { dir = 'out', type = 'string', name = 'path', description = 'Absolute filepath' },
}

C.tags = {}

function C:workOnce()
  local fileName = self.pinIn.file.value or ""
  if self.pinIn.extension.value then
    fileName = fileName..self.pinIn.extension.value
  end
  local file, succ = self.mgr:getRelativeAbsolutePath({fileName}, true)
  self.pinOut.exists.value = succ or false
  self.pinOut.missing.value = not self.pinOut.exists.value
  self.pinOut.existsBool.value = self.pinOut.exists.value
  self.pinOut.path.value = file
end


return _flowgraph_createNode(C)
