-- FixedRemoteEventHandler_v3.lua (ServerScriptService)
-- Enhanced with proper Garden System integration

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("[RemoteEventHandler] Starting RemoteEventHandler v3.0...")

-- Wait for systems with timeout and fallbacks
local DataManager
local GardenSystem

local function waitForSystems()
	local attempts = 0
	local maxAttempts = 30
	
	-- Wait for DataManager
	while not DataManager and attempts < maxAttempts do
		local success, result = pcall(function()
			return require(script.Parent:WaitForChild("DataManager", 1))
		end)
		
		if success and result then
			DataManager = result
			print("[RemoteEventHandler] DataManager loaded successfully")
			break
		end
		
		attempts = attempts + 1
		wait(1)
	end
	
	-- Wait for GardenSystem
	attempts = 0
	while not GardenSystem and attempts < maxAttempts do
		local success, result = pcall(function()
			return require(script.Parent:WaitForChild("GardenSystem", 1))
		end)
		
		if success and result then
			GardenSystem = result
			print("[RemoteEventHandler] GardenSystem loaded successfully")
			break
		end
		
		attempts = attempts + 1
		wait(1)
	end
	
	-- Create fallbacks if systems failed to load
	if not DataManager then
		warn("[RemoteEventHandler] Failed to load DataManager, using fallback")
		DataManager = {
			GetPlayerData = function(player)
				return {
					coins = 500, gems = 5, level = 1, experience = 0,
					inventory = {seeds = {stellar_seed = 0, basic_seed = 0, cosmic_seed = 0}, crops = {}, eggs = {}}
				}
			end,
			SavePlayerData = function(player, data)
				print("[DataManager] Fallback save for:", player.Name)
			end
		}
	end
	
	if not GardenSystem then
		warn("[RemoteEventHandler] Failed to load GardenSystem, using fallback")
		GardenSystem = {
			InitializePlayerGarden = function(player)
				print("[GardenSystem] Fallback garden creation for:", player.Name)
			end,
			PlantSeed = function(player, plotId, seedType)
				return false, "Garden system not available"
			end,
			GetPlayerPlots = function(player)
				return {}
			end
		}
	end
end

-- Initialize systems
spawn(waitForSystems)

-- Create RemoteEvents and RemoteFunctions with error handling
local remoteEvents = {}
local remoteFunctions = {}

-- Helper function to create remote events safely
local function createRemoteEvent(name)
	-- Check if it already exists
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		remoteEvents[name] = existing
		print("[RemoteEventHandler] Using existing RemoteEvent:", name)
		return existing
	elseif existing then
		existing:Destroy()
		print("[RemoteEventHandler] Destroyed conflicting object:", name)
	end
	
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = ReplicatedStorage
	remoteEvents[name] = remoteEvent
	print("[RemoteEventHandler] Created RemoteEvent:", name)
	return remoteEvent
end

-- Helper function to create remote functions safely
local function createRemoteFunction(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		remoteFunctions[name] = existing
		print("[RemoteEventHandler] Using existing RemoteFunction:", name)
		return existing
	elseif existing then
		existing:Destroy()
		print("[RemoteEventHandler] Destroyed conflicting object:", name)
	end
	
	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = name
	remoteFunction.Parent = ReplicatedStorage
	remoteFunctions[name] = remoteFunction
	print("[RemoteEventHandler] Created RemoteFunction:", name)
	return remoteFunction
end

-- Create all remote events
local allEventNames = {
	-- Pet System Events
	"BuyEgg", "EquipPet", "UnequipPet", "SellPet", "FusePets", "ShowFeedback",
	-- Garden System Events  
	"BuySeedEvent", "PlantSeedEvent", "HarvestPlantEvent", "SellPlantEvent", 
	"RequestInventoryUpdate", "PlotDataChanged", "ShowPlotOptionsEvent"
}

for _, eventName in ipairs(allEventNames) do
	createRemoteEvent(eventName)
end

-- Create all remote functions
local allFunctionNames = {
	"GetPetData", "GetPlayerStats", "GetShopData", "GetGardenPlots"
}

for _, funcName in ipairs(allFunctionNames) do
	createRemoteFunction(funcName)
end

-- Wait for systems before setting up handlers
spawn(function()
	while not DataManager or not GardenSystem do
		wait(0.1)
	end
	
	print("[RemoteEventHandler] Setting up event handlers...")
	
	-- === IMPLEMENT GetPlayerStats FUNCTION ===
	remoteFunctions.GetPlayerStats.OnServerInvoke = function(player)
		print("[RemoteEventHandler] GetPlayerStats called for:", player.Name)
		
		local success, playerData = pcall(function()
			return DataManager.GetPlayerData(player)
		end)
		
		if not success or not playerData then
			print("[RemoteEventHandler] Error getting player data, returning defaults")
			return {
				coins = 500, gems = 5, level = 1, experience = 0,
				inventory = {
					seeds = {stellar_seed = 0, basic_seed = 0, cosmic_seed = 0},
					crops = {}, eggs = {}
				}
			}
		end

		-- Ensure inventory structure exists
		playerData.inventory = playerData.inventory or {}
		playerData.inventory.seeds = playerData.inventory.seeds or {}
		playerData.inventory.crops = playerData.inventory.crops or {}
		playerData.inventory.eggs = playerData.inventory.eggs or {}

		local stats = {
			coins = playerData.coins or 500,
			gems = playerData.gems or 5,
			level = playerData.level or 1,
			experience = playerData.experience or 0,
			inventory = {
				seeds = {
					stellar_seed = playerData.inventory.seeds.stellar_seed or 0,
					basic_seed = playerData.inventory.seeds.basic_seed or 0,
					cosmic_seed = playerData.inventory.seeds.cosmic_seed or 0
				},
				crops = playerData.inventory.crops,
				eggs = playerData.inventory.eggs
			}
		}

		print("[RemoteEventHandler] Sending stats - Coins:", stats.coins, "Seeds: stellar=" .. stats.inventory.seeds.stellar_seed)
		return stats
	end

	-- === IMPLEMENT GetGardenPlots FUNCTION ===
	remoteFunctions.GetGardenPlots.OnServerInvoke = function(player)
		print("[RemoteEventHandler] GetGardenPlots called for:", player.Name)
		
		local success, plotsData = pcall(function()
			return GardenSystem.GetPlayerPlots(player)
		end)
		
		if success and plotsData then
			print("[RemoteEventHandler] Returning garden plots data for:", player.Name)
			return plotsData
		else
			warn("[RemoteEventHandler] Failed to get garden plots for:", player.Name, plotsData)
			return {}
		end
	end

	-- === IMPLEMENT BuySeedEvent ===
	remoteEvents.BuySeedEvent.OnServerEvent:Connect(function(player, seedType, quantity)
		print("[RemoteEventHandler] BuySeedEvent:", player.Name, seedType, quantity)

		local success, playerData = pcall(function()
			return DataManager.GetPlayerData(player)
		end)
		
		if not success or not playerData then
			print("[RemoteEventHandler] No player data for seed purchase")
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "Error loading player data!", "error")
			end
			return
		end

		-- Seed prices
		local seedPrices = {basic_seed = 10, stellar_seed = 50, cosmic_seed = 150}
		local price = seedPrices[seedType] or 10
		local totalCost = price * (quantity or 1)

		if (playerData.coins or 0) >= totalCost then
			-- Deduct coins
			playerData.coins = (playerData.coins or 0) - totalCost

			-- Add seeds to inventory
			playerData.inventory = playerData.inventory or {}
			playerData.inventory.seeds = playerData.inventory.seeds or {}
			playerData.inventory.seeds[seedType] = (playerData.inventory.seeds[seedType] or 0) + (quantity or 1)

			-- Save data with error handling
			local saveSuccess = pcall(function()
				DataManager.SavePlayerData(player, playerData)
			end)
			
			if saveSuccess then
				print("[RemoteEventHandler] Seed purchase successful:", seedType, "x" .. (quantity or 1))
				if remoteEvents.ShowFeedback then
					remoteEvents.ShowFeedback:FireClient(player, "Bought " .. (quantity or 1) .. " " .. seedType .. "!", "success")
				end
			else
				print("[RemoteEventHandler] Failed to save data after seed purchase")
				if remoteEvents.ShowFeedback then
					remoteEvents.ShowFeedback:FireClient(player, "Purchase failed - data save error!", "error")
				end
			end
		else
			print("[RemoteEventHandler] Not enough coins for seed purchase")
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "Not enough coins!", "error")
			end
		end
	end)

	-- === IMPLEMENT PlantSeedEvent ===
	remoteEvents.PlantSeedEvent.OnServerEvent:Connect(function(player, plotNumber, seedType)
		print("[RemoteEventHandler] PlantSeedEvent:", player.Name, "plot", plotNumber, "seed", seedType)

		-- Check if player has the seed
		local success, playerData = pcall(function()
			return DataManager.GetPlayerData(player)
		end)
		
		if not success or not playerData or not playerData.inventory or not playerData.inventory.seeds then
			print("[RemoteEventHandler] No seeds available for planting")
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "Error: No seed data available!", "error")
			end
			return
		end

		local seedCount = playerData.inventory.seeds[seedType] or 0
		if seedCount <= 0 then
			print("[RemoteEventHandler] Player doesn't have", seedType)
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "No " .. seedType .. " available!", "error")
			end
			return
		end

		-- Try to plant the seed using GardenSystem
		local plantSuccess, plantMessage = pcall(function()
			return GardenSystem.PlantSeed(player, plotNumber, seedType)
		end)
		
		if plantSuccess and plantMessage then
			-- Successfully planted, now consume the seed from inventory
			playerData.inventory.seeds[seedType] = seedCount - 1

			-- Save data with error handling
			local saveSuccess = pcall(function()
				DataManager.SavePlayerData(player, playerData)
			end)
			
			if saveSuccess then
				print("[RemoteEventHandler] Successfully planted", seedType, "in plot", plotNumber)
				if remoteEvents.ShowFeedback then
					remoteEvents.ShowFeedback:FireClient(player, "Planted " .. seedType .. "!", "success")
				end
			else
				print("[RemoteEventHandler] Failed to save data after planting")
				if remoteEvents.ShowFeedback then
					remoteEvents.ShowFeedback:FireClient(player, "Planting failed - data save error!", "error")
				end
			end
		else
			print("[RemoteEventHandler] Failed to plant seed:", plantMessage or "Unknown error")
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "Failed to plant: " .. (plantMessage or "Unknown error"), "error")
			end
		end
	end)

	-- === IMPLEMENT HarvestPlantEvent ===
	remoteEvents.HarvestPlantEvent.OnServerEvent:Connect(function(player, plotNumber)
		print("[RemoteEventHandler] HarvestPlantEvent:", player.Name, "plot", plotNumber)

		local success, harvestSuccess, cropType, quantity, message = pcall(function()
			return GardenSystem.Harvest(player, plotNumber)
		end)
		
		if success and harvestSuccess then
			print("[RemoteEventHandler] Successfully harvested", cropType, "x" .. quantity, "from plot", plotNumber)
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "Harvested " .. cropType .. " x" .. quantity .. "!", "success")
			end
		else
			local errorMsg = message or "Unknown error"
			print("[RemoteEventHandler] Failed to harvest from plot", plotNumber, ":", errorMsg)
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "Failed to harvest: " .. errorMsg, "error")
			end
		end
	end)

	-- Other remote function implementations
	remoteFunctions.GetShopData.OnServerInvoke = function(player)
		return {
			seeds = {
				{id = "basic_seed", name = "Magic Wheat", price = 10, icon = "🌾"},
				{id = "stellar_seed", name = "Stellar Corn", price = 50, icon = "⭐"},
				{id = "cosmic_seed", name = "Cosmic Berries", price = 150, icon = "🌌"}
			},
			eggs = {
				{id = "basic_egg", name = "Common Egg", price = 100, icon = "🥚"},
				{id = "rare_egg", name = "Rare Egg", price = 500, icon = "✨"},
				{id = "legendary_egg", name = "Legendary Egg", price = 1000, icon = "💎"}
			}
		}
	end

	remoteFunctions.GetPetData.OnServerInvoke = function(player)
		return {} -- Empty pets for now
	end

	print("[RemoteEventHandler] All handlers initialized successfully!")
end)

-- Auto-create gardens for existing players
spawn(function()
	wait(5) -- Give time for systems to load
	
	print("[RemoteEventHandler] Auto-creating gardens for existing players...")
	for _, player in pairs(Players:GetPlayers()) do
		if GardenSystem then
			spawn(function()
				GardenSystem.InitializePlayerGarden(player)
				print("[RemoteEventHandler] Auto-created garden for:", player.Name)
			end)
		end
	end
end)

-- Auto-create gardens for new players
Players.PlayerAdded:Connect(function(player)
	spawn(function()
		wait(3) -- Give time for player to fully load
		if GardenSystem then
			GardenSystem.InitializePlayerGarden(player)
			print("[RemoteEventHandler] Auto-created garden for new player:", player.Name)
		end
	end)
end)

print("[RemoteEventHandler] Enhanced RemoteEventHandler v3 setup complete!")