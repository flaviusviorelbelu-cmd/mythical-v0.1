-- DataManager.lua (ServerScriptService) - Replacement ModuleScript
local Players         = game:GetService("Players")
local DataStoreService= game:GetService("DataStoreService")
local RunService      = game:GetService("RunService")

local DataManager = {}

-- DataStores
local PlayerStore     = DataStoreService:GetDataStore("PlayerData_v3")
local PetStore        = DataStoreService:GetDataStore("PetData_v3")

-- Caches
local playerDataCache = {}
local petDataCache    = {}
local saveQueue       = {}

-- Default structures
local function defaultPlayerData()
	return {
		coins        = 500,
		gems         = 5,
		level        = 1,
		experience   = 0,
		stats        = { eggsHatched = 0, legendaryHatched = 0 },
		inventory    = { seeds = {}, fertilizers = {} },
		settings     = {},
	}
end

local function defaultPetData()
	return { activePets = {nil,nil,nil}, storedPets = {}, nextPetId = 1 }
end

-- Safe DataStore call
local function safeCall(func)
	local ok, res = pcall(func)
	return ok and res or nil
end

-- Player data APIs
function DataManager.LoadPlayerData(player)
	local key = tostring(player.UserId)
	local data = safeCall(function() return PlayerStore:GetAsync(key) end) or defaultPlayerData()
	playerDataCache[key] = data
	return data
end

function DataManager.GetPlayerData(player)
	return playerDataCache[tostring(player.UserId)]
end

function DataManager.SavePlayerData(player, data)
	local key = tostring(player.UserId)
	playerDataCache[key] = data or playerDataCache[key]
	saveQueue[key] = playerDataCache[key]
end

-- Pet data APIs
function DataManager.LoadPetData(player)
	local key = tostring(player.UserId)
	local data = safeCall(function() return PetStore:GetAsync(key) end) or defaultPetData()
	petDataCache[key] = data
	return data
end

function DataManager.GetPetData(player)
	return petDataCache[tostring(player.UserId)]
end

function DataManager.SavePetData(player, data)
	local key = tostring(player.UserId)
	petDataCache[key] = data or petDataCache[key]
	spawn(function()
		pcall(function() PetStore:SetAsync(key, petDataCache[key]) end)
	end)
end

-- Currency and stats
function DataManager.AddCoins(player, amount)
	local d = DataManager.GetPlayerData(player)
	d.coins = (d.coins or 0) + amount
	DataManager.SavePlayerData(player)
end

function DataManager.AddGems(player, amount)
	local d = DataManager.GetPlayerData(player)
	d.gems = (d.gems or 0) + amount
	DataManager.SavePlayerData(player)
end

function DataManager.UpdatePlayerStats(player, stat, inc)
	local d = DataManager.GetPlayerData(player)
	d.stats[stat] = (d.stats[stat] or 0) + inc
	DataManager.SavePlayerData(player)
end

-- Periodic saving
RunService.Heartbeat:Connect(function()
	for key, data in pairs(saveQueue) do
		pcall(function() PlayerStore:SetAsync(key, data) end)
		saveQueue[key] = nil
	end
end)

Players.PlayerAdded:Connect(DataManager.LoadPlayerData)
Players.PlayerAdded:Connect(DataManager.LoadPetData)
Players.PlayerRemoving:Connect(function(player)
	DataManager.SavePlayerData(player)
	DataManager.SavePetData(player)
	playerDataCache[tostring(player.UserId)] = nil
	petDataCache[tostring(player.UserId)]    = nil
end)

return DataManager