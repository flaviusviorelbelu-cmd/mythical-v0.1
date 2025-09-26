-- RemoteEventHandler.lua (ServerScriptService)
-- Handles all client-server communication for the pet system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

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
	"ShowPlotOptionsEvent",
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
	-- Daca vrei dupa userId:
	return GardenSystem.GetPlayerPlots(player)
	-- Sau daca vrei dupa gardenId:
	-- return GardenSystem.GetGardenPlots(gardenId)
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

-- Event Handlers

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
		-- Success message is handled by SellPet function
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
		-- Success message is handled by FusePets function
	else
		remoteEvents.ShowFeedback:FireClient(player, "Cannot fuse these pets! Must be same type.", "error")
	end
end)

-- Remote Functions

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
		pendingEggs = EggManager.GetPendingEggCount() -- Fixed function name
	}
end

-- Clean up rate limits when player leaves
Players.PlayerRemoving:Connect(function(player)
	rateLimits[player.UserId] = nil
end)

-- === Helpers pentru update UI ===
local function pushGardenUI(player)
	-- Trimite inventar de semin?e/recolte ?i statistici pentru UI
	local data = DataManager.GetPlayerData(player)
	if data then
		local inv = GardenSystem.GetInventory and GardenSystem.GetInventory(player) or {}
		remoteEvents.RequestInventoryUpdate:FireClient(player, {
			inventory = inv,
			coins = data.coins,
			experience = data.experience,
			level = data.level
		})
	end
end

local function firePlotChanged(player, plotId, extra)
	-- Notifica clientul/întreaga lume ca un plot s-a schimbat
	-- Daca vizualele sunt globale: FireAllClients; daca sunt per-jucator: FireClient
	if extra then
		remoteEvents.PlotDataChanged:FireAllClients(player.UserId, plotId, extra)
	else
		remoteEvents.PlotDataChanged:FireAllClients(player.UserId, plotId)
	end
end

-- === Garden: BuySeed ===
remoteEvents.BuySeedEvent.OnServerEvent:Connect(function(player, seedType, amount)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "BuySeedEvent") then return end

	seedType = validateAndSanitizeInput(seedType, "string")
	amount = (validateAndSanitizeInput(amount, "number") or 1)
	if not seedType or amount < 1 then
		remoteEvents.ShowFeedback:FireClient(player, "Cerere invalida pentru cumparare semin?e!", "error")
		return
	end

	if not (GardenSystem.IsValidSeed and GardenSystem.IsValidSeed(seedType)) then
		remoteEvents.ShowFeedback:FireClient(player, "Tip de samân?a invalid!", "error")
		return
	end

	local ok, msg, coinsSpent = GardenSystem.BuySeed(player, seedType, amount)
	if ok then
		remoteEvents.ShowFeedback:FireClient(player, ("Ai cumparat %d x %s."):format(amount, seedType), "success")
		pushGardenUI(player)
	else
		remoteEvents.ShowFeedback:FireClient(player, msg or "Cumparare e?uata!", "error")
	end
end)

-- === Garden: PlantSeed === (CORECTED)
remoteEvents.PlantSeedEvent.OnServerEvent:Connect(function(player, plotIndex, seedType)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "PlantSeedEvent") then return end

	plotIndex = validateAndSanitizeInput(plotIndex, "number")
	seedType = validateAndSanitizeInput(seedType, "string")

	if not plotIndex or not seedType then
		remoteEvents.ShowFeedback:FireClient(player, "Date invalide pentru plantare!", "error")
		return
	end
	if not (GardenSystem.IsValidSeed and GardenSystem.IsValidSeed(seedType)) then
		remoteEvents.ShowFeedback:FireClient(player, "Tip de samân?a invalid pentru plantare!", "error")
		return
	end

	-- FIXED: calls GardenSystem.PlantSeed with correct parameters
	local ok, msg = GardenSystem.PlantSeed(player, plotIndex, seedType)
	if ok then
		firePlotChanged(player, plotIndex)
		pushGardenUI(player)
		remoteEvents.ShowFeedback:FireClient(player, "Samân?a a fost plantata!", "success")
	else
		remoteEvents.ShowFeedback:FireClient(player, msg or "Plantare e?uata!", "error")
	end
end)

-- === Garden: HarvestPlant === (FIXED name and parameters)
remoteEvents.HarvestPlantEvent.OnServerEvent:Connect(function(player, plotIndex)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "HarvestPlantEvent") then return end

	plotIndex = validateAndSanitizeInput(plotIndex, "number")
	if not plotIndex then
		remoteEvents.ShowFeedback:FireClient(player, "Plot invalid pentru recoltare!", "error")
		return
	end

	-- FIXED: calls GardenSystem.Harvest (which delegates to PlayerGardenManager.HarvestPlant)
	local ok, cropType, qty, msg = GardenSystem.Harvest(player, plotIndex)
	if ok then
		firePlotChanged(player, plotIndex)
		pushGardenUI(player)
		remoteEvents.ShowFeedback:FireClient(player, ("Ai recoltat %d x %s."):format(qty or 1, cropType or "?"), "success")
	else
		remoteEvents.ShowFeedback:FireClient(player, msg or "Recoltare e?uata!", "error")
	end
end)

-- === Garden: SellPlant === (FIXED return format)
remoteEvents.SellPlantEvent.OnServerEvent:Connect(function(player, cropType, quantity)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "SellPlantEvent") then return end

	cropType = validateAndSanitizeInput(cropType, "string")
	quantity = validateAndSanitizeInput(quantity, "number")
	if not cropType or not quantity or quantity < 1 then
		remoteEvents.ShowFeedback:FireClient(player, "Date invalide pentru vânzare!", "error")
		return
	end
	if not (GardenSystem.IsValidCrop and GardenSystem.IsValidCrop(cropType)) then
		remoteEvents.ShowFeedback:FireClient(player, "Tip de planta invalid!", "error")
		return
	end

	-- FIXED: expects (success, coinsGained, message) return format
	local ok, coinsGained, msg = GardenSystem.SellPlant(player, cropType, quantity)
	if ok then
		pushGardenUI(player)
		remoteEvents.ShowFeedback:FireClient(player, ("Ai vândut %d x %s ?i ai câ?tigat %d monede."):format(quantity, cropType, coinsGained or 0), "success")
	else
		remoteEvents.ShowFeedback:FireClient(player, msg or "Vânzare e?uata!", "error")
	end
end)


-- === Garden: ShowPlotOptions (op?ional; pentru UI contextual) ===
remoteEvents.ShowPlotOptionsEvent.OnServerEvent:Connect(function(player, plotId)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "ShowPlotOptionsEvent") then return end

	plotId = validateAndSanitizeInput(plotId, "number")
	if not plotId then return end

	-- Recomandat: folose?te RemoteFunction daca ai nevoie sa returnezi o lista de op?iuni
	-- Ca fallback, trimite un eveniment catre client cu datele disponibile
	local options = GardenSystem.GetPlotOptions and GardenSystem.GetPlotOptions(player, plotId) or {}
	remoteEvents.RequestInventoryUpdate:FireClient(player, { plotOptions = options })
end)

-- === Garden: RequestInventoryUpdate (client -> server -> client) ===
remoteEvents.RequestInventoryUpdate.OnServerEvent:Connect(function(player)
	if not validatePlayer(player) then return end
	if not checkRateLimit(player, "RequestInventoryUpdate") then return end
	pushGardenUI(player)
end)

print("[RemoteEventHandler] Pet system remote events initialized")

return {
	Events = remoteEvents,
	Functions = {
		GetPetData = getPetDataFunc,
		GetPlayerStats = getPlayerStatsFunc,
		GetShopData = getShopDataFunc
	}
}
