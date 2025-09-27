-- MainClient.lua (StarterPlayerScripts)
-- Main client controller for the Mythical Pet & Garden Game

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[MainClient] Initializing for player:", player.Name)

-- Wait for RemoteEvents to be created by server
local remoteEvents = {}
local remoteFunctions = {}

-- Pet System Events
local petEvents = {
    "BuyEgg", "EquipPet", "UnequipPet", "SellPet", "FusePets", "ShowFeedback"
}

-- Garden System Events  
local gardenEvents = {
    "BuySeedEvent", "PlantSeedEvent", "HarvestPlantEvent", "SellPlantEvent", 
    "RequestInventoryUpdate", "PlotDataChanged"
}

-- Remote Functions
local remoteFunctionNames = {
    "GetPetData", "GetPlayerStats", "GetShopData", "GetGardenPlots"
}

-- Load all remote events
spawn(function()
    for _, eventName in ipairs(petEvents) do
        remoteEvents[eventName] = ReplicatedStorage:WaitForChild(eventName)
        print("[MainClient] Loaded remote event:", eventName)
    end
    
    for _, eventName in ipairs(gardenEvents) do
        remoteEvents[eventName] = ReplicatedStorage:WaitForChild(eventName)
        print("[MainClient] Loaded remote event:", eventName)
    end
    
    for _, funcName in ipairs(remoteFunctionNames) do
        remoteFunctions[funcName] = ReplicatedStorage:WaitForChild(funcName)
        print("[MainClient] Loaded remote function:", funcName)
    end
    
    print("[MainClient] All remote connections established!")
end)

-- === PLAYER DATA ===
local playerData = {
    coins = 500,  -- Default starting coins
    gems = 5,     -- Default starting gems
    level = 1,
    experience = 0,
    inventory = {seeds = {}, crops = {}},
    pets = {},
    activePets = {}
}

-- === FEEDBACK SYSTEM ===
local function showFeedback(message, messageType)
    messageType = messageType or "info"
    
    -- Create feedback GUI
    local feedbackGui = Instance.new("ScreenGui")
    feedbackGui.Name = "FeedbackMessage"
    feedbackGui.Parent = playerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 80)
    frame.Position = UDim2.new(0.5, -200, 0, -100)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = feedbackGui
    
    -- Color based on message type
    if messageType == "success" then
        frame.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    elseif messageType == "error" then
        frame.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    else
        frame.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
    end
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    
    -- Message text
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -20, 1, 0)
    textLabel.Position = UDim2.new(0, 10, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = message
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Parent = frame
    
    -- Animate in
    local tweenIn = TweenService:Create(
        frame,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -200, 0, 50)}
    )
    tweenIn:Play()
    
    -- Auto-dismiss after 3 seconds
    spawn(function()
        wait(3)
        
        local tweenOut = TweenService:Create(
            frame,
            TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -200, 0, -100)}
        )
        tweenOut:Play()
        
        tweenOut.Completed:Connect(function()
            feedbackGui:Destroy()
        end)
    end)
end

-- Handle feedback from server
spawn(function()
    local showFeedbackEvent = ReplicatedStorage:WaitForChild("ShowFeedback")
    showFeedbackEvent.OnClientEvent:Connect(showFeedback)
end)

-- === DATA MANAGEMENT === (SINGLE FUNCTION - NO DUPLICATES)
local function updatePlayerData()
    spawn(function()
        if remoteFunctions.GetPlayerStats then
            local success, stats = pcall(function()
                return remoteFunctions.GetPlayerStats:InvokeServer()
            end)
            
            if success and stats then
                print("[MainClient] Received stats:", stats.coins, stats.gems, stats.level)
                
                -- Update local data
                playerData.coins = stats.coins or 500
                playerData.gems = stats.gems or 5
                playerData.level = stats.level or 1
                playerData.experience = stats.experience or 0
                
                -- Update UI immediately
                if _G.MainClient then
                    _G.MainClient.UpdateStatsDisplay()
                end
                
                print("[MainClient] Updated UI with:", playerData.coins, playerData.gems, playerData.level)
            else
                print("[MainClient] Failed to get stats from server")
                -- Use default values and update UI
                if _G.MainClient then
                    _G.MainClient.UpdateStatsDisplay()
                end
            end
        else
            print("[MainClient] GetPlayerStats function not available yet")
        end
    end)
end

-- === UI CREATION ===
local function createMainUI()
    -- Main UI Container
    local mainUI = Instance.new("ScreenGui")
    mainUI.Name = "MainGameUI"
    mainUI.ResetOnSpawn = false
    mainUI.Parent = playerGui
    
    -- Top Stats Bar
    local statsFrame = Instance.new("Frame")
    statsFrame.Name = "StatsFrame"
    statsFrame.Size = UDim2.new(1, 0, 0, 60)
    statsFrame.Position = UDim2.new(0, 0, 0, 0)
    statsFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
    statsFrame.BorderSizePixel = 0
    statsFrame.Parent = mainUI
    
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
    coinsLabel.Text = "💰 " .. playerData.coins
    coinsLabel.TextColor3 = Color3.new(1, 1, 1)
    coinsLabel.TextScaled = true
    coinsLabel.Font = Enum.Font.GothamBold
    coinsLabel.Parent = coinsFrame
    
    -- Gems Display
    local gemsFrame = Instance.new("Frame")
    gemsFrame.Name = "GemsFrame"
    gemsFrame.Size = UDim2.new(0, 150, 1, -10)
    gemsFrame.Position = UDim2.new(0, 170, 0, 5)
    gemsFrame.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
    gemsFrame.BorderSizePixel = 0
    gemsFrame.Parent = statsFrame
    
    local gemsCorner = Instance.new("UICorner")
    gemsCorner.CornerRadius = UDim.new(0, 8)
    gemsCorner.Parent = gemsFrame
    
    local gemsLabel = Instance.new("TextLabel")
    gemsLabel.Name = "GemsLabel"
    gemsLabel.Size = UDim2.new(1, -20, 1, 0)
    gemsLabel.Position = UDim2.new(0, 10, 0, 0)
    gemsLabel.BackgroundTransparency = 1
    gemsLabel.Text = "💎 " .. playerData.gems
    gemsLabel.TextColor3 = Color3.new(1, 1, 1)
    gemsLabel.TextScaled = true
    gemsLabel.Font = Enum.Font.GothamBold
    gemsLabel.Parent = gemsFrame
    
    -- Level Display
    local levelFrame = Instance.new("Frame")
    levelFrame.Name = "LevelFrame"
    levelFrame.Size = UDim2.new(0, 120, 1, -10)
    levelFrame.Position = UDim2.new(0, 330, 0, 5)
    levelFrame.BackgroundColor3 = Color3.fromRGB(26, 188, 156)
    levelFrame.BorderSizePixel = 0
    levelFrame.Parent = statsFrame
    
    local levelCorner = Instance.new("UICorner")
    levelCorner.CornerRadius = UDim.new(0, 8)
    levelCorner.Parent = levelFrame
    
    local levelLabel = Instance.new("TextLabel")
    levelLabel.Name = "LevelLabel"
    levelLabel.Size = UDim2.new(1, -20, 1, 0)
    levelLabel.Position = UDim2.new(0, 10, 0, 0)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Text = "⭐ Level " .. playerData.level
    levelLabel.TextColor3 = Color3.new(1, 1, 1)
    levelLabel.TextScaled = true
    levelLabel.Font = Enum.Font.GothamBold
    levelLabel.Parent = levelFrame
    
    -- Bottom Menu Buttons
    local menuFrame = Instance.new("Frame")
    menuFrame.Name = "MenuFrame"
    menuFrame.Size = UDim2.new(1, 0, 0, 80)
    menuFrame.Position = UDim2.new(0, 0, 1, -80)
    menuFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
    menuFrame.BorderSizePixel = 0
    menuFrame.Parent = mainUI
    
    -- Menu buttons
    local buttons = {
        {name = "Shop", color = Color3.fromRGB(46, 204, 113), icon = "🛒"},
        {name = "Inventory", color = Color3.fromRGB(52, 152, 219), icon = "🎒"},
        {name = "Pets", color = Color3.fromRGB(155, 89, 182), icon = "🐾"},
        {name = "Garden", color = Color3.fromRGB(230, 126, 34), icon = "🌱"}
    }
    
    for i, buttonData in ipairs(buttons) do
        local button = Instance.new("TextButton")
        button.Name = buttonData.name .. "Button"
        button.Size = UDim2.new(0.25, -10, 1, -10)
        button.Position = UDim2.new((i-1) * 0.25, 5, 0, 5)
        button.BackgroundColor3 = buttonData.color
        button.BorderSizePixel = 0
        button.Text = buttonData.icon .. " " .. buttonData.name
        button.TextColor3 = Color3.new(1, 1, 1)
        button.TextScaled = true
        button.Font = Enum.Font.GothamBold
        button.Parent = menuFrame
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = button
        
        -- Button click handlers
        button.MouseButton1Click:Connect(function()
            print("[MainClient] " .. buttonData.name .. " button clicked!")
            if _G.MainClient then
                _G.MainClient.ToggleMenu(buttonData.name)
            end
        end)
    end
    
    return mainUI
end

-- === PUBLIC FUNCTIONS ===
_G.MainClient = {
    -- Update stats display
    UpdateStatsDisplay = function()
        local mainUI = playerGui:FindFirstChild("MainGameUI")
        if mainUI then
            local statsFrame = mainUI:FindFirstChild("StatsFrame")
            if statsFrame then
                -- Update coins
                local coinsFrame = statsFrame:FindFirstChild("CoinsFrame")
                if coinsFrame then
                    local coinsLabel = coinsFrame:FindFirstChild("CoinsLabel")
                    if coinsLabel then
                        coinsLabel.Text = "💰 " .. tostring(playerData.coins)
                    end
                end
                
                -- Update gems
                local gemsFrame = statsFrame:FindFirstChild("GemsFrame")
                if gemsFrame then
                    local gemsLabel = gemsFrame:FindFirstChild("GemsLabel")
                    if gemsLabel then
                        gemsLabel.Text = "💎 " .. tostring(playerData.gems)
                    end
                end
                
                -- Update level
                local levelFrame = statsFrame:FindFirstChild("LevelFrame")
                if levelFrame then
                    local levelLabel = levelFrame:FindFirstChild("LevelLabel")
                    if levelLabel then
                        levelLabel.Text = "⭐ Level " .. tostring(playerData.level)
                    end
                end
                
                print("[MainClient] UI updated - Coins:", playerData.coins, "Gems:", playerData.gems, "Level:", playerData.level)
            end
        end
    end,
    
    -- Toggle menu visibility
    ToggleMenu = function(menuName)
        print("[MainClient] Toggling", menuName, "menu")
        
        if menuName == "Shop" then
            if _G.ShopClient then
                _G.ShopClient.ToggleShop()
            end
        elseif menuName == "Inventory" then
            if _G.InventoryClient then
                _G.InventoryClient.ToggleInventory()
            end
        elseif menuName == "Pets" then
            if _G.PetClient then
                _G.PetClient.TogglePetMenu()
            end
        elseif menuName == "Garden" then
            if _G.GardenClient then
                _G.GardenClient.ToggleGardenMenu()
            end
        end
    end,
    
    -- Get current player data
    GetPlayerData = function()
        return playerData
    end,
    
    -- Show feedback message
    ShowFeedback = showFeedback,
    
    -- Update data from server
    RefreshData = updatePlayerData
}

-- === INITIALIZATION ===
spawn(function()
    -- Wait for character to spawn
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    
    wait(3) -- Give time for server to initialize
    
    -- Create main UI
    createMainUI()
    
    -- Wait for remote functions to be available
    spawn(function()
        while not remoteFunctions.GetPlayerStats do
            wait(1)
            print("[MainClient] Waiting for GetPlayerStats...")
        end
        
        -- Load initial data
        updatePlayerData()
        
        -- Set up periodic data refresh
        spawn(function()
            while player.Parent do
                wait(10) -- Refresh every 10 seconds to avoid throttling
                updatePlayerData()
            end
        end)
    end)
    
    print("[MainClient] Initialization complete!")
    showFeedback("Welcome to Mythical Realm, " .. player.Name .. "!", "success")
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == player then
        print("[MainClient] Player leaving, cleaning up...")
    end
end)

return _G.MainClient
