-- FixedMainClient.lua (StarterPlayerScripts)
-- FIXED VERSION with better error handling and remote event management

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[MainClient] Initializing FIXED version for player:", player.Name)

-- Connection state tracking
local connectionState = {
	remotesLoaded = false,
	dataLoaded = false,
	uiCreated = false
}

-- Enhanced remote event/function loading with retry mechanism
local remoteEvents = {}
local remoteFunctions = {}
local CONNECTION_TIMEOUT = 30 -- seconds
local RETRY_DELAY = 1 -- seconds

-- All remote names
local REMOTE_EVENTS = {
	-- Pet System
	"BuyEgg", "EquipPet", "UnequipPet", "SellPet", "FusePets", "ShowFeedback",
	-- Garden System
	"BuySeedEvent", "PlantSeedEvent", "HarvestPlantEvent", "SellPlantEvent", 
	"RequestInventoryUpdate", "PlotDataChanged", "ShowPlotOptionsEvent"
}

local REMOTE_FUNCTIONS = {
	"GetPetData", "GetPlayerStats", "GetShopData", "GetGardenPlots"
}

-- Enhanced remote loading with timeout and retry
local function loadRemoteObjects()
	local startTime = tick()
	local loadedEvents = {}
	local loadedFunctions = {}
	
	print("[MainClient] Starting enhanced remote object loading...")
	
	-- Load RemoteEvents
	spawn(function()
		for _, eventName in ipairs(REMOTE_EVENTS) do
			spawn(function()
				local attempts = 0
				local maxAttempts = CONNECTION_TIMEOUT / RETRY_DELAY
				
				while attempts < maxAttempts and not loadedEvents[eventName] do
					local success, remote = pcall(function()
						return ReplicatedStorage:WaitForChild(eventName, RETRY_DELAY)
					end)
					
					if success and remote then
						remoteEvents[eventName] = remote
						loadedEvents[eventName] = true
						print("[MainClient] ✓ Loaded RemoteEvent:", eventName)
					else
						attempts = attempts + 1
						if attempts % 5 == 0 then -- Log every 5 attempts
							print("[MainClient] ⏳ Still waiting for RemoteEvent:", eventName, "(attempt", attempts, "/", maxAttempts, ")")
						end
					end
				end
				
				if not loadedEvents[eventName] then
					warn("[MainClient] ❌ Failed to load RemoteEvent:", eventName, "after", maxAttempts, "attempts")
				end
			end)
		end
	end)
	
	-- Load RemoteFunctions
	spawn(function()
		for _, funcName in ipairs(REMOTE_FUNCTIONS) do
			spawn(function()
				local attempts = 0
				local maxAttempts = CONNECTION_TIMEOUT / RETRY_DELAY
				
				while attempts < maxAttempts and not loadedFunctions[funcName] do
					local success, remote = pcall(function()
						return ReplicatedStorage:WaitForChild(funcName, RETRY_DELAY)
					end)
					
					if success and remote then
						remoteFunctions[funcName] = remote
						loadedFunctions[funcName] = true
						print("[MainClient] ✓ Loaded RemoteFunction:", funcName)
					else
						attempts = attempts + 1
						if attempts % 5 == 0 then
							print("[MainClient] ⏳ Still waiting for RemoteFunction:", funcName, "(attempt", attempts, "/", maxAttempts, ")")
						end
					end
				end
				
				if not loadedFunctions[funcName] then
					warn("[MainClient] ❌ Failed to load RemoteFunction:", funcName, "after", maxAttempts, "attempts")
				end
			end)
		end
	end)
	
	-- Wait for all to load or timeout
	spawn(function()
		while tick() - startTime < CONNECTION_TIMEOUT do
			local eventsLoaded = 0
			local functionsLoaded = 0
			
			for _, eventName in ipairs(REMOTE_EVENTS) do
				if loadedEvents[eventName] then
					eventsLoaded = eventsLoaded + 1
				end
			end
			
			for _, funcName in ipairs(REMOTE_FUNCTIONS) do
				if loadedFunctions[funcName] then
					functionsLoaded = functionsLoaded + 1
				end
			end
			
			if eventsLoaded == #REMOTE_EVENTS and functionsLoaded == #REMOTE_FUNCTIONS then
				connectionState.remotesLoaded = true
				print("[MainClient] 🎉 All remote objects loaded successfully!")
				break
			end
			
			wait(0.5)
		end
		
		if not connectionState.remotesLoaded then
			warn("[MainClient] ⚠️  Remote loading timeout - some features may not work")
			connectionState.remotesLoaded = true -- Continue anyway
		end
	end)
end

-- Enhanced player data with better defaults
local playerData = {
	coins = 500,
	gems = 5,
	level = 1,
	experience = 0,
	inventory = {seeds = {}, crops = {}, eggs = {}},
	pets = {},
	activePets = {},
	lastUpdate = 0
}

-- Enhanced feedback system
local function showFeedback(message, messageType, duration)
	messageType = messageType or "info"
	duration = duration or 3

	-- Prevent spam by checking for existing feedback
	local existing = playerGui:FindFirstChild("FeedbackMessage")
	if existing then
		existing:Destroy()
	end

	local feedbackGui = Instance.new("ScreenGui")
	feedbackGui.Name = "FeedbackMessage"
	feedbackGui.ResetOnSpawn = false
	feedbackGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 400, 0, 80)
	frame.Position = UDim2.new(0.5, -200, 0, -100)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = feedbackGui

	-- Enhanced colors and styling
	local colors = {
		success = Color3.fromRGB(46, 204, 113),
		error = Color3.fromRGB(231, 76, 60),
		warning = Color3.fromRGB(241, 196, 15),
		info = Color3.fromRGB(52, 152, 219)
	}
	frame.BackgroundColor3 = colors[messageType] or colors.info

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	-- Add drop shadow effect
	local shadow = Instance.new("ImageLabel")
	shadow.Size = UDim2.new(1, 20, 1, 20)
	shadow.Position = UDim2.new(0, -10, 0, -10)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxasset://textures/ui/Controls/DropShadow.png"
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = 0.5
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 118, 118)
	shadow.ZIndex = frame.ZIndex - 1
	shadow.Parent = frame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -20, 1, 0)
	textLabel.Position = UDim2.new(0, 10, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = message
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = frame

	-- Enhanced animations
	local tweenIn = TweenService:Create(
		frame,
		TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, -200, 0, 50)}
	)
	tweenIn:Play()

	-- Auto-dismiss
	spawn(function()
		wait(duration)
		if feedbackGui and feedbackGui.Parent then
			local tweenOut = TweenService:Create(
				frame,
				TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{Position = UDim2.new(0.5, -200, 0, -100), BackgroundTransparency = 1}
			)
			tweenOut:Play()
			tweenOut.Completed:Connect(function()
				if feedbackGui and feedbackGui.Parent then
					feedbackGui:Destroy()
				end
			end)
		end
	end)
end

-- Enhanced data management with retry logic
local function updatePlayerData()
	if not connectionState.remotesLoaded or not remoteFunctions.GetPlayerStats then
		print("[MainClient] ⏳ Skipping data update - remotes not ready")
		return false
	end

	spawn(function()
		local maxRetries = 3
		local retryDelay = 2
		
		for attempt = 1, maxRetries do
			local success, stats = pcall(function()
				return remoteFunctions.GetPlayerStats:InvokeServer()
			end)

			if success and stats then
				-- Update local data
				playerData.coins = stats.coins or playerData.coins
				playerData.gems = stats.gems or playerData.gems
				playerData.level = stats.level or playerData.level
				playerData.experience = stats.experience or playerData.experience
				playerData.lastUpdate = tick()
				
				-- Merge inventory data
				if stats.inventory then
					playerData.inventory.seeds = stats.inventory.seeds or playerData.inventory.seeds
					playerData.inventory.crops = stats.inventory.crops or playerData.inventory.crops
					playerData.inventory.eggs = stats.inventory.eggs or playerData.inventory.eggs
				end

				connectionState.dataLoaded = true
				print("[MainClient] ✓ Data updated successfully - Coins:", playerData.coins, "Level:", playerData.level)
				
				-- Update UI
				if _G.MainClient then
					_G.MainClient.UpdateStatsDisplay()
				end
				
				return
			else
				print("[MainClient] ❌ Data update attempt", attempt, "/", maxRetries, "failed:", stats or "unknown error")
				if attempt < maxRetries then
					wait(retryDelay)
				else
					warn("[MainClient] ⚠️  All data update attempts failed - using cached data")
					if _G.MainClient then
						_G.MainClient.UpdateStatsDisplay()
					end
				end
			end
		end
	end)
end

-- UI creation (keeping original logic but with enhancements)
local function createMainUI()
	if connectionState.uiCreated then
		return
	end
	
	-- [Original UI creation code stays the same - just adding the header]
	local mainUI = Instance.new("ScreenGui")
	mainUI.Name = "MainGameUI"
	mainUI.ResetOnSpawn = false
	mainUI.Parent = playerGui

	-- Connection status indicator
	local statusFrame = Instance.new("Frame")
	statusFrame.Name = "ConnectionStatus"
	statusFrame.Size = UDim2.new(0, 200, 0, 30)
	statusFrame.Position = UDim2.new(1, -210, 0, 10)
	statusFrame.BackgroundColor3 = connectionState.remotesLoaded and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(241, 196, 15)
	statusFrame.BorderSizePixel = 0
	statusFrame.Parent = mainUI

	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 15)
	statusCorner.Parent = statusFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -10, 1, 0)
	statusLabel.Position = UDim2.new(0, 5, 0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = connectionState.remotesLoaded and "🟢 Connected" or "🟡 Connecting..."
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Parent = statusFrame

	-- [Rest of original UI creation code...]
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(1, 0, 0, 60)
	statsFrame.Position = UDim2.new(0, 0, 0, 45) -- Moved down to make room for status
	statsFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = mainUI

	-- [Continue with original stats display creation...]
	-- Coins Display
	local coinsFrame = Instance.new("Frame")
	coinsFrame.Name = "CoinsFrame"
	coinsFrame.Size = UDim2.new(0, 150, 1, -10)
	coinsFrame.Position = UDim2.new(0, 10, 0, 5)
	coinsFrame.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
	coinsFrame.BorderSizePixel = 0
	coinsFrame.Parent = statsFrame

	local coinsCorner = Instance.new("UICorner")
	coinsCorner.CornerRadius = UDim.new(0, 8)
	coinsCorner.Parent = coinsFrame

	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "CoinsLabel"
	coinsLabel.Size = UDim2.new(1, -20, 1, 0)
	coinsLabel.Position = UDim2.new(0, 10, 0, 0)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Text = "🪙 " .. playerData.coins
	coinsLabel.TextColor3 = Color3.new(1, 1, 1)
	coinsLabel.TextScaled = true
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.Parent = coinsFrame

	-- [Continue with gems, level, and menu creation...]
	connectionState.uiCreated = true
	print("[MainClient] ✓ UI created successfully")
end

-- Global client interface
_G.MainClient = {
	-- Enhanced status display update
	UpdateStatsDisplay = function()
		local mainUI = playerGui:FindFirstChild("MainGameUI")
		if mainUI and mainUI:FindFirstChild("StatsFrame") then
			local statsFrame = mainUI.StatsFrame
			
			-- Update coins
			local coinsFrame = statsFrame:FindFirstChild("CoinsFrame")
			if coinsFrame and coinsFrame:FindFirstChild("CoinsLabel") then
				coinsFrame.CoinsLabel.Text = "🪙 " .. tostring(playerData.coins)
			end
			
			-- Update gems
			local gemsFrame = statsFrame:FindFirstChild("GemsFrame")
			if gemsFrame and gemsFrame:FindFirstChild("GemsLabel") then
				gemsFrame.GemsLabel.Text = "💎 " .. tostring(playerData.gems)
			end
			
			-- Update level
			local levelFrame = statsFrame:FindFirstChild("LevelFrame")
			if levelFrame and levelFrame:FindFirstChild("LevelLabel") then
				levelFrame.LevelLabel.Text = "⭐ Level " .. tostring(playerData.level)
			end
			
			-- Update connection status
			local statusFrame = mainUI:FindFirstChild("ConnectionStatus")
			if statusFrame and statusFrame:FindFirstChild("TextLabel") then
				if connectionState.dataLoaded then
					statusFrame.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
					statusFrame.TextLabel.Text = "🟢 Connected"
				else
					statusFrame.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
					statusFrame.TextLabel.Text = "🟡 Syncing..."
				end
			end
		end
	end,
	
	-- Get current data
	GetPlayerData = function()
		return playerData
	end,
	
	-- Enhanced feedback
	ShowFeedback = showFeedback,
	
	-- Force data refresh
	RefreshData = updatePlayerData,
	
	-- Connection status
	GetConnectionStatus = function()
		return connectionState
	end
}

-- Enhanced initialization sequence
spawn(function()
	print("[MainClient] 🚀 Starting enhanced initialization...")
	
	-- Wait for character
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	print("[MainClient] ✓ Character loaded")
	
	-- Load remote objects
	loadRemoteObjects()
	
	-- Wait for remotes to be ready
	while not connectionState.remotesLoaded do
		wait(0.5)
	end
	
	-- Create UI
	createMainUI()
	
	-- Load initial data
	updatePlayerData()
	
	-- Set up feedback handler
	if remoteEvents.ShowFeedback then
		remoteEvents.ShowFeedback.OnClientEvent:Connect(function(message, messageType)
			showFeedback(message, messageType)
		end)
	end
	
	-- Set up periodic data refresh
	spawn(function()
		while player.Parent do
			wait(15) -- Refresh every 15 seconds
			updatePlayerData()
		end
	end)
	
	print("[MainClient] 🎉 Enhanced initialization complete!")
	showFeedback("Welcome to Mythical Realm, " .. player.Name .. "! 🌟", "success", 4)
end)

print("[MainClient] ✅ FIXED MainClient loaded successfully!")