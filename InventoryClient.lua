-- InventoryClient.lua (StarterPlayerScripts) - CORRECTED VERSION
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[InventoryClient] Initializing inventory system...")

-- Wait for remote events and functions
local remoteEvents = {}
local remoteFunctions = {}

-- Initialize variables BEFORE using them
local inventoryGui = nil
local isInventoryOpen = false

-- Sample data structures (will be updated from server)
local inventoryData = {
	seeds = {
		basic_seed = {count = 0, name = "Magic Wheat", icon = "??"},
		stellar_seed = {count = 0, name = "Stellar Corn", icon = "??"},
		cosmic_seed = {count = 0, name = "Cosmic Berries", icon = "??"}
	},
	crops = {
		magic_wheat = {count = 0, name = "Magic Wheat", sellPrice = 15, icon = "??"},
		stellar_corn = {count = 0, name = "Stellar Corn", sellPrice = 80, icon = "??"},
		cosmic_berries = {count = 0, name = "Cosmic Berries", sellPrice = 350, icon = "??"}
	},
	pets = {}
}

-- DECLARE FUNCTIONS WITH LOCAL FIRST
local setupInventoryListener
local updateInventoryFromServer
local createInventoryUI

-- Setup inventory data listener
setupInventoryListener = function()
	print("[InventoryClient] Setting up inventory data listener...")

	-- Listen for manual inventory updates
	if remoteEvents.RequestInventoryUpdate then
		remoteEvents.RequestInventoryUpdate.OnClientEvent:Connect(function(data)
			print("[InventoryClient] Received inventory update event:", data)
			updateInventoryFromServer()
		end)
	end
end

-- Update inventory data from server
updateInventoryFromServer = function()
	print("[InventoryClient] Updating inventory from server...")

	if not remoteFunctions.GetPlayerStats then
		print("[InventoryClient] ERROR: GetPlayerStats not available")
		return
	end

	spawn(function()
		local success, stats = pcall(function()
			return remoteFunctions.GetPlayerStats:InvokeServer()
		end)

		if success and stats then
			print("[InventoryClient] Received stats from server")
			print("[InventoryClient] Stats:", stats)

			if stats.inventory and stats.inventory.seeds then
				print("[InventoryClient] Updating seed inventory:")

				for seedType, count in pairs(stats.inventory.seeds) do
					if inventoryData.seeds[seedType] then
						inventoryData.seeds[seedType].count = count
						print("[InventoryClient]   ", seedType, "=", count)
					end
				end

				print("[InventoryClient] Inventory updated successfully!")

				-- Refresh UI if inventory is open
				if isInventoryOpen then
					print("[InventoryClient] Refreshing open inventory UI")
					createInventoryUI() -- Refresh the display
				end
			else
				print("[InventoryClient] No inventory data in server response")
			end
		else
			print("[InventoryClient] Failed to get stats from server:", stats)
		end
	end)
end

-- Create inventory UI
createInventoryUI = function()
	if inventoryGui then inventoryGui:Destroy() end

	-- Main inventory GUI
	inventoryGui = Instance.new("ScreenGui")
	inventoryGui.Name = "InventoryGui"
	inventoryGui.Parent = playerGui

	-- Background frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "InventoryFrame"
	mainFrame.Size = UDim2.new(0, 900, 0, 700)
	mainFrame.Position = UDim2.new(0.5, -450, 0.5, -350)
	mainFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = inventoryGui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 15)
	frameCorner.Parent = mainFrame

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 60)
	titleBar.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 15)
	titleCorner.Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -120, 1, 0)
	titleLabel.Position = UDim2.new(0, 20, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "?? My Inventory"
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = titleBar

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 80, 1, -10)
	closeButton.Position = UDim2.new(1, -90, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	closeButton.Text = "? Close"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.BorderSizePixel = 0
	closeButton.Parent = titleBar

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		_G.InventoryClient.ToggleInventory()
	end)

	-- Content frame for seeds
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Size = UDim2.new(1, -20, 1, -80)
	contentFrame.Position = UDim2.new(0, 10, 0, 70)
	contentFrame.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
	contentFrame.BorderSizePixel = 0
	contentFrame.ScrollBarThickness = 8
	contentFrame.Parent = mainFrame

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 12)
	contentCorner.Parent = contentFrame

	-- Create seed display
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.Parent = contentFrame

	print("[InventoryClient] Creating seed display...")
	for seedType, seedData in pairs(inventoryData.seeds) do
		local itemFrame = Instance.new("Frame")
		itemFrame.Size = UDim2.new(1, -20, 0, 80)
		itemFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
		itemFrame.BorderSizePixel = 0
		itemFrame.Parent = contentFrame

		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 12)
		itemCorner.Parent = itemFrame

		-- Item icon
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(0, 60, 1, 0)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = seedData.icon
		iconLabel.TextScaled = true
		iconLabel.Parent = itemFrame

		-- Item name and count
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -70, 1, 0)
		nameLabel.Position = UDim2.new(0, 70, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = seedData.name .. " (x" .. seedData.count .. ")"
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = itemFrame

		-- Highlight if player has seeds
		if seedData.count > 0 then
			itemFrame.BackgroundColor3 = Color3.fromRGB(46, 204, 113)

			local glowEffect = Instance.new("UIStroke")
			glowEffect.Color = Color3.fromRGB(46, 204, 113)
			glowEffect.Thickness = 2
			glowEffect.Parent = itemFrame
		end

		print("[InventoryClient] Created display for:", seedType, "count:", seedData.count)
	end

	contentFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
end

-- Wait for RemoteEvents and Functions
spawn(function()
	print("[InventoryClient] Waiting for RemoteEvents...")

	-- Wait for RemoteEvents
	remoteEvents.RequestInventoryUpdate = ReplicatedStorage:WaitForChild("RequestInventoryUpdate", 10)
	remoteEvents.SellPlantEvent = ReplicatedStorage:WaitForChild("SellPlantEvent", 10)
	remoteEvents.ShowFeedback = ReplicatedStorage:WaitForChild("ShowFeedback", 10)

	-- Wait for RemoteFunctions
	remoteFunctions.GetPlayerStats = ReplicatedStorage:WaitForChild("GetPlayerStats", 10)

	if remoteFunctions.GetPlayerStats then
		print("[InventoryClient] Remote connections established successfully!")
		setupInventoryListener()
	else
		print("[InventoryClient] ERROR: Failed to connect to GetPlayerStats")
		return
	end
end)

-- === PUBLIC FUNCTIONS ===
_G.InventoryClient = {
	ToggleInventory = function()
		if isInventoryOpen then
			-- Close inventory
			if inventoryGui then
				local mainFrame = inventoryGui:FindFirstChild("InventoryFrame")
				if mainFrame then
					local closeTween = TweenService:Create(
						mainFrame,
						TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
						{Position = UDim2.new(0.5, -450, 1, 0)}
					)
					closeTween:Play()
					closeTween.Completed:Connect(function()
						inventoryGui:Destroy()
						inventoryGui = nil
					end)
				end
			end
			isInventoryOpen = false
			print("[InventoryClient] Inventory closed")
		else
			-- Open inventory
			updateInventoryFromServer() -- Refresh data from server
			createInventoryUI()
			isInventoryOpen = true
			print("[InventoryClient] Inventory opened")
		end
	end,

	-- Update inventory data
	UpdateInventory = function(newData)
		inventoryData = newData or inventoryData
		print("[InventoryClient] Inventory data updated")
	end,

	-- Get current inventory
	GetInventory = function()
		return inventoryData
	end
}

print("[InventoryClient] Inventory system initialized!")
