-- Register a new Flowgraph node called "ListReplays"
registerNodeType("ListReplays", {
  -- Define what inputs the node takes
  inputs = {
    folderPath = { type = "string", default = "C:/Users/rafae/AppData/Local/BeamNG.drive/0.34/replays/autoReplay" }, -- You can override this path in Flowgraph
    trigger = { type = "flow" }, -- Trigger input to activate the node
  },

  -- Define the outputs this node will generate
  outputs = {
    replayNames = { type = "table" },  -- List of replay folder names
    count = { type = "number" },       -- How many replays were found
    onDone = { type = "flow" },        -- Flow output to continue execution
  },

  -- This function runs when the node is triggered
  onTrigger = function(self)
    local path = self.pinIn.folderPath.value
    local replayList = {} -- Will hold names of replay folders
    local lfs = require("lfs") -- LuaFileSystem for directory access
    local count = 0

    -- Iterate through items in the given directory
    for folder in lfs.dir(path) do
      if folder ~= "." and folder ~= ".." then
        local infoPath = path .. "/" .. folder .. "/info.json"
        -- Check if the replay folder contains an info.json file (valid replay)
        if lfs.attributes(infoPath, "mode") == "file" then
          table.insert(replayList, folder)
          count = count + 1
        end
      end
    end

    -- Output the results to the Flowgraph system
    self.pinOut.replayNames.value = replayList
    self.pinOut.count.value = count

    -- Activate the next flow pin
    self:activateOutput("onDone")
  end
})
