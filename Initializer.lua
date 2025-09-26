-- ServerScriptService/Initializer (Script)
local MagicalRealm = require(game.ServerScriptService.MagicalRealm)
local GardenSystem = require(game.ServerScriptService.GardenSystem)

-- Generate the environment first
MagicalRealm.CreateWorld()

-- Now garden system will spawn per player
