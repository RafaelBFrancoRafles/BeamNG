-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

C.name = 'Replay: Toggle Play (Once)'
C.description = 'Toggles replay play/pause ONCE when flow is received.'
C.category = 'once_instant'

C.color = ui_flowgraph_editor.nodeColors.replay
C.icon = ui_flowgraph_editor.nodeIcons.replay

function C:workOnce()
  extensions.core_replay.togglePlay()
end

return _flowgraph_createNode(C)
