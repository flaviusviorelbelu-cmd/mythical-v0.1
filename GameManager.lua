-- Main Game Manager (ServerScriptService/GameManager)
local GameManager      = {}
local Players          = game:GetService("Players")
local DataManager      = require(script.Parent.DataManager)
local GardenSystem     = require(script.Parent.GardenSystem)
local PlayerGardenManager = require(script.Parent.PlayerGardenManager)

-- Called when a player joins
function GameManager.OnPlayerAdded(player)
	-- Load player and pet data (DataManager handles all caching/first-time logic)
	DataManager.LoadPlayerData(player)
	DataManager.LoadPetData(player)

	-- Initialize their garden
	GardenSystem.InitializePlayerGarden(player)
end

-- Called when a player is leaving
function GameManager.OnPlayerRemoving(player)
	-- Ensure data is saved
	DataManager.SavePlayerData(player)
	DataManager.SavePetData(player)
end

-- Connect player events
Players.PlayerAdded:Connect(GameManager.OnPlayerAdded)
Players.PlayerRemoving:Connect(GameManager.OnPlayerRemoving)

return GameManager
