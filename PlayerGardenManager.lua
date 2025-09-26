--PlayerGardenManager.lua
-- PlayerGardenManager Module (ServerScriptService)
-- Enhanced with debugging, proper garden assignment, and plot management
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DEBUG_MODE         = true


-- Wait for environment initialization
local envEvent = ReplicatedStorage:WaitForChild("EnvironmentInitialized", 30)
if envEvent then
	envEvent.Event:Wait()
else
	warn("EnvironmentInitialized event missing ? proceeding anyway")
end

-- Ensure MapGenerator API exists
assert(_G.MapGenerator and _G.MapGenerator.plantSeed and _G.MapGenerator.harvestPlant and _G.MapGenerator.getAllPlots,
	"MapGenerator API missing in PlayerGardenManager")

-- Debug logging
local function debugLog(message, level)
	level = level or "INFO"
	if DEBUG_MODE then
		print("[PlayerGardenManager] [" .. level .. "] " .. message)
	end
end

-- Get workspace and Gardens folder
local workspace       = game:GetService("Workspace")
local gardensFolder = workspace:FindFirstChild("Gardens")
if not gardensFolder then
	-- Try to find gardens directly in workspace
	gardensFolder = workspace
	debugLog("Using workspace as gardens folder (Gardens folder not found)", "WARN")
end



local PlayerGardenManager = {}

-- Safe require
local function safeRequire(moduleName)
	local ok, mod = pcall(function()
		return require(game.ServerScriptService:WaitForChild(moduleName, 10))
	end)
	if not ok then
		debugLog("Module not available: " .. moduleName, "WARN")
		return nil
	end
	return mod
end

local DataManager = safeRequire("DataManager")

-- Track assignments
local gardenAssignments = {}  -- gardenId -> userId
local playerGardens      = {}  -- userId   -> gardenId

-- Configuration
local GARDEN_CONFIG = {
	maxGardens      = 8,
	plotsPerGarden  = 9,
	plotGrowthTime  = 180,
	maxGrowthStages = 3,
}

-- Assign garden to player
function PlayerGardenManager.AssignGarden(player)
	if not player or not player.UserId then
		debugLog("Invalid player for assignment", "ERROR")
		return nil
	end
	debugLog("Assigning garden to " .. player.Name)
	if playerGardens[player.UserId] then
		return playerGardens[player.UserId]
	end
	if DataManager then
		local pdata = DataManager.GetPlayerData(player)
		if pdata and pdata.assignedGarden and pdata.assignedGarden > 0 then
			local gid = pdata.assignedGarden
			if not gardenAssignments[gid] or gardenAssignments[gid] == player.UserId then
				gardenAssignments[gid]  = player.UserId
				playerGardens[player.UserId] = gid
				local gf = gardensFolder:FindFirstChild("Garden" .. gid)
				if gf then
					gf:SetAttribute("OwnerId", player.UserId)
					gf:SetAttribute("OwnerName", player.Name)
				end
				return gid
			end
		end
	end
	for gid = 1, GARDEN_CONFIG.maxGardens do
		if not gardenAssignments[gid] then
			local gf = gardensFolder:FindFirstChild("Garden" .. gid)
			if gf then
				gardenAssignments[gid]      = player.UserId
				playerGardens[player.UserId] = gid
				gf:SetAttribute("OwnerId", player.UserId)
				gf:SetAttribute("OwnerName", player.Name)
				if DataManager then
					local pdata = DataManager.GetPlayerData(player)
					if pdata then
						pdata.assignedGarden = gid
						DataManager.SavePlayerData(player, pdata)
					end
				end
				debugLog("Assigned garden " .. gid .. " to " .. player.Name)
				return gid
			else
				debugLog("Garden folder missing: " .. gid, "WARN")
			end
		end
	end
	debugLog("No gardens available", "ERROR")
	return nil
end

-- Get or assign garden
function PlayerGardenManager.GetPlayerGarden(player)
	if not player or not player.UserId then return nil end
	return playerGardens[player.UserId] or PlayerGardenManager.AssignGarden(player)
end

-- Plant seed
function PlayerGardenManager.PlantSeed(player, plotIndex, seedType)
	if not player or not plotIndex or not seedType then
		debugLog("Invalid PlantSeed params", "ERROR")
		return false, "Invalid parameters"
	end
	local gid = PlayerGardenManager.GetPlayerGarden(player)
	if not gid then
		return false, "No garden assigned"
	end
	if DataManager then
		local pdata = DataManager.GetPlayerData(player)
		if not pdata or not pdata.seeds or (pdata.seeds[seedType] or 0) <= 0 then
			return false, "No seeds"
		end
		local key = gid .. "_" .. plotIndex
		local ok = _G.MapGenerator.plantSeed(key, seedType, player.UserId)
		if ok then
			pdata.seeds[seedType] = pdata.seeds[seedType] - 1
			DataManager.SavePlayerData(player, pdata)
			return true, "Planted"
		else
			return false, "Plot unavailable"
		end
	end
	return false, "Data unavailable"
end

-- Harvest plant
function PlayerGardenManager.HarvestPlant(player, plotIndex)
	if not player or not plotIndex then
		return false, "Invalid parameters"
	end
	local gid = PlayerGardenManager.GetPlayerGarden(player)
	if not gid then
		return false, "No garden assigned"
	end
	local key = gid .. "_" .. plotIndex
	local htype = _G.MapGenerator.harvestPlant(key)
	if htype and DataManager then
		local pdata = DataManager.GetPlayerData(player)
		pdata.harvest = pdata.harvest or {}
		pdata.harvest[htype] = (pdata.harvest[htype] or 0) + 1
		DataManager.SavePlayerData(player, pdata)
		return true, htype
	end
	return false, "Plot not ready"
end

-- Get all plots for player
function PlayerGardenManager.GetPlayerPlots(player)
	local gid = PlayerGardenManager.GetPlayerGarden(player)
	if not gid then return {} end
	local all = _G.MapGenerator.getAllPlots()
	local out = {}
	for k,v in pairs(all) do
		if k:match("^" .. gid .. "_") then
			out[k] = v
		end
	end
	return out
end

-- Cleanup on leave
function PlayerGardenManager.CleanupPlayer(player)
	playerGardens[player.UserId] = nil
end
Players.PlayerRemoving:Connect(PlayerGardenManager.CleanupPlayer)

-- Export API
_G.PlayerGardenManager = PlayerGardenManager
debugLog("PlayerGardenManager loaded")

-- Add this to the bottom of PlayerGardenManager.lua
Players.PlayerAdded:Connect(function(player)
	task.wait(2) -- Wait for everything to load

	local gardenId = PlayerGardenManager.AssignGarden(player)
	if gardenId then
		debugLog("Auto-assigned garden "..gardenId.." to "..player.Name.." on join")

		-- Trigger UI update
		local updateEvent = ReplicatedStorage:FindFirstChild("UpdatePlayerData")
		if updateEvent and DataManager then
			local playerData = DataManager.GetPlayerData(player)
			if playerData then
				updateEvent:FireClient(player, playerData)
			end
		end
	else
		debugLog("Failed to assign garden to "..player.Name, "ERROR")
	end
end)

return PlayerGardenManager
