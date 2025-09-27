-- RemoteEventHandler.lua (ServerScriptService)
-- Handles all client-server communication for the pet and garden systems

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for modules to load
local EggManager = require(script.Parent:WaitForChild("EggManager"))
local PetInventoryManager = require(script.Parent:WaitForChild("PetInventoryManager"))
local PetVisualSystem = require(script.Parent:WaitForChild("PetVisualSystem"))
local PetAbilityManager = require(script.Parent:WaitForChild("PetAbilityManager"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local EggConfig = require(script.Parent:WaitForChild("EggConfig"))
local GardenSystem = require(script.Parent:WaitForChild("GardenSystem"))

-- Create RemoteEvents
local remoteEvents = {}

local function createRemoteEvent(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	remoteEvents[name] = event
	return event
end

local function createRemoteFunction(name)
	local func = Instance.new("RemoteFunction")
	func.Name = name
	func.Parent = ReplicatedStorage
	return func
end

-- Initialize Pet RemoteEvents
local petSystemEvents = {
	"BuyEgg",
	"EquipPet", 
	"UnequipPet",
	"SellPet",
	"FusePets",
	"GetPetInventory",
	"ShowFeedback"
}

-- Initialize Garden RemoteEvents
local gardenSystemEvents = {
	"BuySeedEvent",
	"HarvestPlantEvent",
	"PlantSeedEvent",
	"PlotDataChanged",
	"RequestInventoryUpdate",
	"ShowPlotOptionsEvent",
	"SellPlantEvent",
	"PlayerGardenSystem"
}

for _, eventName in ipairs(petSystemEvents) do
	createRemoteEvent(eventName)
	print("Event Created ", eventName)
end

for _, eventName in ipairs(gardenSystemEvents) do
	createRemoteEvent(eventName)
	print("Event Created ", eventName)
end

-- Remote Functions
local getPetDataFunc = createRemoteFunction("GetPetData")
local getPlayerStatsFunc = createRemoteFunction("GetPlayerStats")
local getShopDataFunc = createRemoteFunction("GetShopData")
local getGardenPlots = createRemoteFunction("GetGardenPlots")

getGardenPlots.OnServerInvoke = function(player, userIdOrGardenId)
	return GardenSystem.GetPlayerPlots(player)
end

-- Validation functions
local function validatePlayer(player)
	return player and player.Parent and Players:FindFirstChild(player.Name)
end

local function validateAndSanitizeInput(input, inputType)
	if inputType == "string" then
		return type(input) == "string" and string.len(input) <= 50 and input
	elseif inputType == "number" then
		return type(input) == "number" and input >= 0 and input <= 1000000 and input
	elseif inputType == "boolean" then
		return type(input) == "boolean" and input
	end
	return nil
end

-- Rate limiting
local rateLimits = {}
local RATE_LIMIT_TIME = 1 -- seconds
local MAX_REQUESTS = 10 -- per time window

local function checkRateLimit(player, action)
	local userId = player.UserId
	local currentTime = tick()

	if not rateLimits[userId] then
		rateLimits[userId] = {}
	end

	if not rateLimits[userId][action] then
		rateLimits[userId][action] = {count = 0, resetTime = currentTime + RATE_LIMIT_TIME}
	end

	local limitData = rateLimits[userId][action]

	if currentTime > limitData.resetTime then
		limitData.count = 0
		limitData.resetTime = currentTime + RATE_LIMIT_TIME
	end

	if limitData.count >= MAX_REQUESTS then
		return false -- Rate limited
	end

	limitData.count = limitData.count + 1
	return true
end

-- === PET SYSTEM EVENT HANDLERS ===

-- Buy Egg Handler
remoteEvents.BuyEgg.OnServerEvent:Connect(function(player, eggType)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "BuyEgg") then return end

	eggType = validateAndSanitizeInput(eggType, "string")
	if not eggType or not EggConfig.IsValidEggType(eggType) then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid egg type!", "error")
		return
	end

	local success = EggManager.BuyEgg(player, eggType)
	if success then
		local config = EggConfig.GetEggConfig(eggType)
		remoteEvents.ShowFeedback:FireClient(player, 
			string.format("Purchased %s! It will hatch in %d seconds.", config.name, config.hatchTime), 
			"success")
	else
		remoteEvents.ShowFeedback:FireClient(player, "Not enough coins or egg limit reached!", "error")
	end
end)

-- Equip Pet Handler
remoteEvents.EquipPet.OnServerEvent:Connect(function(player, petId, slot)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "EquipPet") then return end

	petId = validateAndSanitizeInput(petId, "number")
	slot = validateAndSanitizeInput(slot, "number")

	if not petId or not slot or slot < 1 or slot > 3 then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid pet or slot!", "error")
		return
	end

	local success = PetInventoryManager.EquipPet(player, petId, slot)
	if success then
		PetAbilityManager.UpdatePlayerAbilities(player)
		PetVisualSystem.UpdatePlayerPets(player)
		remoteEvents.ShowFeedback:FireClient(player, "Pet equipped!", "success")
	else
		remoteEvents.ShowFeedback:FireClient(player, "Failed to equip pet!", "error")
	end
end)

-- Unequip Pet Handler  
remoteEvents.UnequipPet.OnServerEvent:Connect(function(player, slot)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "UnequipPet") then return end

	slot = validateAndSanitizeInput(slot, "number")
	if not slot or slot < 1 or slot > 3 then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid slot!", "error")
		return
	end

	local success = PetInventoryManager.UnequipPet(player, slot)
	if success then
		PetAbilityManager.UpdatePlayerAbilities(player)
		PetVisualSystem.UpdatePlayerPets(player)
		remoteEvents.ShowFeedback:FireClient(player, "Pet unequipped!", "info")
	else
		remoteEvents.ShowFeedback:FireClient(player, "Failed to unequip pet!", "error")
	end
end)

-- Sell Pet Handler
remoteEvents.SellPet.OnServerEvent:Connect(function(player, petId)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "SellPet") then return end

	petId = validateAndSanitizeInput(petId, "number")
	if not petId then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid pet ID!", "error")
		return
	end

	local success = PetInventoryManager.SellPet(player, petId)
	if success then
		PetAbilityManager.UpdatePlayerAbilities(player)
		PetVisualSystem.UpdatePlayerPets(player)
	else
		remoteEvents.ShowFeedback:FireClient(player, "Failed to sell pet!", "error")
	end
end)

-- Fuse Pets Handler
remoteEvents.FusePets.OnServerEvent:Connect(function(player, petId1, petId2)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "FusePets") then return end

	petId1 = validateAndSanitizeInput(petId1, "number")
	petId2 = validateAndSanitizeInput(petId2, "number")

	if not petId1 or not petId2 or petId1 == petId2 then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid pet selection for fusion!", "error")
		return
	end

	local fusedPetId = PetInventoryManager.FusePets(player, petId1, petId2)
	if fusedPetId then
		PetAbilityManager.UpdatePlayerAbilities(player)
		PetVisualSystem.UpdatePlayerPets(player)
	else
		remoteEvents.ShowFeedback:FireClient(player, "Cannot fuse these pets! Must be same type.", "error")
	end
end)

-- === GARDEN SYSTEM EVENT HANDLERS ===

-- Helper functions for garden UI updates
local function pushGardenUI(player)
	local data = DataManager.GetPlayerData(player)
	if data then
		local inv = GardenSystem.GetInventory(player)
		remoteEvents.RequestInventoryUpdate:FireClient(player, {
			inventory = inv,
			coins = data.coins,
			experience = data.experience,
			level = data.level
		})
	end
end

local function firePlotChanged(player, plotId, extra)
	if extra then
		remoteEvents.PlotDataChanged:FireAllClients(player.UserId, plotId, extra)
	else
		remoteEvents.PlotDataChanged:FireAllClients(player.UserId, plotId)
	end
end

-- Buy Seed Handler
remoteEvents.BuySeedEvent.OnServerEvent:Connect(function(player, seedType, amount)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "BuySeedEvent") then return end

	seedType = validateAndSanitizeInput(seedType, "string")
	amount = (validateAndSanitizeInput(amount, "number") or 1)
	if not seedType or amount < 1 then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid seed purchase request!", "error")
		return
	end

	if not GardenSystem.IsValidSeed(seedType) then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid seed type!", "error")
		return
	end

	local ok, msg, coinsSpent = GardenSystem.BuySeed(player, seedType, amount)
	if ok then
		remoteEvents.ShowFeedback:FireClient(player, ("Purchased %d x %s."):format(amount, seedType), "success")
		pushGardenUI(player)
	else
		remoteEvents.ShowFeedback:FireClient(player, msg or "Purchase failed!", "error")
	end
end)

-- Plant Seed Handler
remoteEvents.PlantSeedEvent.OnServerEvent:Connect(function(player, plotIndex, seedType)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "PlantSeedEvent") then return end

	plotIndex = validateAndSanitizeInput(plotIndex, "number")
	seedType = validateAndSanitizeInput(seedType, "string")

	if not plotIndex or not seedType then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid planting data!", "error")
		return
	end
	
	if not GardenSystem.IsValidSeed(seedType) then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid seed type!", "error")
		return
	end

	local ok, msg = GardenSystem.PlantSeed(player, plotIndex, seedType)
	if ok then
		firePlotChanged(player, plotIndex)
		pushGardenUI(player)
		remoteEvents.ShowFeedback:FireClient(player, "Seed planted!", "success")
	else
		remoteEvents.ShowFeedback:FireClient(player, msg or "Planting failed!", "error")
	end
end)

-- Harvest Plant Handler
remoteEvents.HarvestPlantEvent.OnServerEvent:Connect(function(player, plotIndex)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "HarvestPlantEvent") then return end

	plotIndex = validateAndSanitizeInput(plotIndex, "number")
	if not plotIndex then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid plot for harvest!", "error")
		return
	end

	local ok, cropType, qty, msg = GardenSystem.Harvest(player, plotIndex)
	if ok then
		firePlotChanged(player, plotIndex)
		pushGardenUI(player)
		remoteEvents.ShowFeedback:FireClient(player, ("Harvested %d x %s."):format(qty or 1, cropType or "?"), "success")
	else
		remoteEvents.ShowFeedback:FireClient(player, msg or "Harvest failed!", "error")
	end
end)

-- Sell Plant Handler
remoteEvents.SellPlantEvent.OnServerEvent:Connect(function(player, cropType, quantity)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "SellPlantEvent") then return end

	cropType = validateAndSanitizeInput(cropType, "string")
	quantity = validateAndSanitizeInput(quantity, "number")
	if not cropType or not quantity or quantity < 1 then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid sell data!", "error")
		return
	end
	
	if not GardenSystem.IsValidCrop(cropType) then
		remoteEvents.ShowFeedback:FireClient(player, "Invalid crop type!", "error")
		return
	end

	local ok, coinsGained, msg = GardenSystem.SellPlant(player, cropType, quantity)
	if ok then
		pushGardenUI(player)
		remoteEvents.ShowFeedback:FireClient(player, ("Sold %d x %s and gained %d coins."):format(quantity, cropType, coinsGained or 0), "success")
	else
		remoteEvents.ShowFeedback:FireClient(player, msg or "Sale failed!", "error")
	end
end)

-- Request Inventory Update Handler
remoteEvents.RequestInventoryUpdate.OnServerEvent:Connect(function(player)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "RequestInventoryUpdate") then return end
	pushGardenUI(player)
end)

-- === REMOTE FUNCTIONS ===

-- Get Pet Data Function
getPetDataFunc.OnServerInvoke = function(player)
	if not validatePlayer(player) then return nil end

	return {
		pets = PetInventoryManager.GetPlayerPets(player),
		stats = PetInventoryManager.GetInventoryStats(player),
		activePets = PetInventoryManager.GetActivePets(player)
	}
end

-- Get Player Stats Function
getPlayerStatsFunc.OnServerInvoke = function(player)
	if not validatePlayer(player) then return nil end

	local playerData = DataManager.GetPlayerData(player)
	if not playerData then return nil end

	return {
		coins = playerData.coins,
		gems = playerData.gems,
		level = playerData.level,
		experience = playerData.experience,
		stats = playerData.stats
	}
end

-- Shop Data Handler
getShopDataFunc.OnServerInvoke = function(player)
	if not validatePlayer(player) then return nil end

	return {
		eggs = EggConfig.GetShopDisplayData(),
		playerCoins = DataManager.GetPlayerData(player).coins or 0,
		pendingEggs = EggManager.GetPendingEggCount()
	}
end

-- Clean up rate limits when player leaves
Players.PlayerRemoving:Connect(function(player)
	rateLimits[player.UserId] = nil
end)

print("[RemoteEventHandler] Pet and garden system remote events initialized")

return {
	Events = remoteEvents,
	Functions = {
		GetPetData = getPetDataFunc,
		GetPlayerStats = getPlayerStatsFunc,
		GetShopData = getShopDataFunc,
		GetGardenPlots = getGardenPlots
	}
}