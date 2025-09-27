-- RemoteEventHandler.lua (ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[RemoteEventHandler] Starting RemoteEventHandler...")

-- Import required modules with error handling
local DataManager
local success = pcall(function()
	DataManager = require(script.Parent.DataManager)
end)

if not success or not DataManager then
	print("[RemoteEventHandler] ERROR: DataManager not found, creating dummy functions")
	DataManager = {
		GetPlayerData = function(player)
			return {
				coins = 500,
				gems = 5,
				level = 1,
				experience = 0,
				inventory = {
					seeds = {stellar_seed = 0, basic_seed = 0, cosmic_seed = 0},
					crops = {},
					eggs = {}
				}
			}
		end,
		SavePlayerData = function(player, data)
			print("[DataManager] Dummy save for:", player.Name)
		end
	}
end

-- Create RemoteEvents and RemoteFunctions
local remoteEvents = {}
local remoteFunctions = {}

-- Pet System Events
local petEventNames = {
	"BuyEgg", "EquipPet", "UnequipPet", "SellPet", "FusePets", "ShowFeedback"
}

-- Garden System Events  
local gardenEventNames = {
	"BuySeedEvent", "PlantSeedEvent", "HarvestPlantEvent", "SellPlantEvent", 
	"RequestInventoryUpdate", "PlotDataChanged", "ShowPlotOptionsEvent"  -- <- ADD ShowPlotOptionsEvent
}

-- Create Pet Events
for _, eventName in ipairs(petEventNames) do
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = eventName
	remoteEvent.Parent = ReplicatedStorage
	remoteEvents[eventName] = remoteEvent
	print("Event Created", eventName)
end

-- Create Garden Events
for _, eventName in ipairs(gardenEventNames) do
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = eventName
	remoteEvent.Parent = ReplicatedStorage
	remoteEvents[eventName] = remoteEvent
	print("Event Created", eventName)
end

-- Create RemoteFunctions
local remoteFunctionNames = {
	"GetPetData", "GetPlayerStats", "GetShopData", "GetGardenPlots"
}

for _, funcName in ipairs(remoteFunctionNames) do
	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = funcName
	remoteFunction.Parent = ReplicatedStorage
	remoteFunctions[funcName] = remoteFunction
	print("Function Created", funcName)
end

-- === IMPLEMENT GetPlayerStats FUNCTION ===
-- In RemoteEventHandler.lua, replace the GetPlayerStats function:
remoteFunctions.GetPlayerStats.OnServerInvoke = function(player)
	print("[RemoteEventHandler] GetPlayerStats called for:", player.Name)

	local playerData = DataManager.GetPlayerData(player)
	if not playerData then
		print("[RemoteEventHandler] No player data, returning defaults")
		return {
			coins = 500,
			gems = 5,
			level = 1,
			experience = 0,
			inventory = {
				seeds = {stellar_seed = 0, basic_seed = 0, cosmic_seed = 0},
				crops = {},
				eggs = {}
			}
		}
	end

	-- Make sure inventory structure exists
	if not playerData.inventory then
		playerData.inventory = {seeds = {}, crops = {}, eggs = {}}
	end
	if not playerData.inventory.seeds then
		playerData.inventory.seeds = {}
	end

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
			crops = playerData.inventory.crops or {},
			eggs = playerData.inventory.eggs or {}
		}
	}

	-- CRITICAL: Print the actual seed counts being sent
	print("[RemoteEventHandler] Sending seed counts:")
	print("  stellar_seed:", stats.inventory.seeds.stellar_seed)
	print("  basic_seed:", stats.inventory.seeds.basic_seed) 
	print("  cosmic_seed:", stats.inventory.seeds.cosmic_seed)

	return stats
end


-- === IMPLEMENT BuySeedEvent ===
remoteEvents.BuySeedEvent.OnServerEvent:Connect(function(player, seedType, quantity)
	print("[RemoteEventHandler] BuySeedEvent:", player.Name, seedType, quantity)

	local playerData = DataManager.GetPlayerData(player)
	if not playerData then
		print("[RemoteEventHandler] No player data for seed purchase")
		return
	end

	-- Seed prices
	local seedPrices = {
		basic_seed = 10,
		stellar_seed = 50,
		cosmic_seed = 150
	}

	local price = seedPrices[seedType] or 10
	local totalCost = price * (quantity or 1)

	if playerData.coins >= totalCost then
		-- Deduct coins
		playerData.coins = playerData.coins - totalCost

		-- Add seeds to inventory
		if not playerData.inventory then
			playerData.inventory = {seeds = {}, crops = {}, eggs = {}}
		end
		if not playerData.inventory.seeds then
			playerData.inventory.seeds = {}
		end

		playerData.inventory.seeds[seedType] = (playerData.inventory.seeds[seedType] or 0) + (quantity or 1)

		-- Save data
		DataManager.SavePlayerData(player, playerData)

		print("[RemoteEventHandler] Seed purchase successful:", seedType, "x" .. (quantity or 1))

		-- Send feedback
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Bought " .. (quantity or 1) .. " " .. seedType .. "!", "success")
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

	local playerData = DataManager.GetPlayerData(player)
	if not playerData or not playerData.inventory or not playerData.inventory.seeds then
		print("[RemoteEventHandler] No seeds available for planting")
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

	-- Use one seed
	playerData.inventory.seeds[seedType] = seedCount - 1

	-- Save data
	DataManager.SavePlayerData(player, playerData)

	print("[RemoteEventHandler] Successfully planted", seedType, "in plot", plotNumber)

	if remoteEvents.ShowFeedback then
		remoteEvents.ShowFeedback:FireClient(player, "Planted " .. seedType .. "!", "success")
	end
end)

-- Create dummy implementations for other functions
remoteFunctions.GetShopData.OnServerInvoke = function(player)
	return {
		seeds = {
			{id = "basic_seed", name = "Magic Wheat", price = 10, icon = "??"},
			{id = "stellar_seed", name = "Stellar Corn", price = 50, icon = "??"},
			{id = "cosmic_seed", name = "Cosmic Berries", price = 150, icon = "??"}
		},
		eggs = {
			{id = "basic_egg", name = "Common Egg", price = 100, icon = "??"},
			{id = "rare_egg", name = "Rare Egg", price = 500, icon = "??"},
			{id = "legendary_egg", name = "Legendary Egg", price = 1000, icon = "??"}
		}
	}
end

remoteFunctions.GetGardenPlots.OnServerInvoke = function(player)
	return {} -- Empty plots for now
end

remoteFunctions.GetPetData.OnServerInvoke = function(player)
	return {} -- Empty pets for now
end

print("[RemoteEventHandler] All remote events and functions initialized!")
