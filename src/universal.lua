local VibeUI, Tabs = ...
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local env = getgenv()
env.ESPEnabled = false
env.ESPNamesEnabled = true

-- ── Persistent connection tracking ──────────────────────────
local espConnections = {}

local function GetPlayerNames()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    return names
end

local function removePlayerESP(player)
    if player.Character then
        local highlight = player.Character:FindFirstChild("BloxxerHighlight")
        if highlight then highlight:Destroy() end

        local head = player.Character:FindFirstChild("Head")
        if head then
            local nameTag = head:FindFirstChild("BloxxerName")
            if nameTag then nameTag:Destroy() end
        end
    end
end

local function createESP(player)
    if player == LocalPlayer or not env.ESPEnabled then return end

    local char = player.Character
    if not char then return end

    local head = char:FindFirstChild("Head")
    if not head then 
        head = char:WaitForChild("Head", 2)
        if not head then return end
    end

    -- Prevent duplicate highlights
    if not char:FindFirstChild("BloxxerHighlight") then
        local highlight = Instance.new("Highlight")
        highlight.Name = "BloxxerHighlight"
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Parent = char
    end

    if env.ESPNamesEnabled then
        if not head:FindFirstChild("BloxxerName") then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "BloxxerName"
            billboard.Size = UDim2.new(0, 75, 0, 18)
            billboard.StudsOffset = Vector3.new(0, 2, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = head

            local label = Instance.new("TextLabel")
            label.Size = UDim2.fromScale(1, 1)
            label.BackgroundTransparency = 1
            label.Text = player.DisplayName
            label.TextSize = 12
            label.Font = Enum.Font.SourceSansBold
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            label.TextStrokeTransparency = 0
            label.Parent = billboard
        end
    end
end

local function unhookPlayer(player)
    if espConnections[player] then
        espConnections[player]:Disconnect()
        espConnections[player] = nil
    end
    removePlayerESP(player)
end

local function hookPlayer(player)
    if player == LocalPlayer then return end
    unhookPlayer(player)

    espConnections[player] = player.CharacterAdded:Connect(function(char)
        if not env.ESPEnabled then return end
        task.wait(0.4) -- Safe delay for character assets to replicate
        createESP(player)
    end)
end

local function EnableESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            hookPlayer(player)
            if player.Character then
                task.spawn(createESP, player)
            end
        end
    end
end

local function DisableESP()
    for player, _ in pairs(espConnections) do
        unhookPlayer(player)
    end
    table.clear(espConnections)
    
    -- Cleanup any leftover instances globally
    for _, player in ipairs(Players:GetPlayers()) do
        removePlayerESP(player)
    end
end

-- ═════════════════════════════════════════════════════════════
--  UI SECTIONS
-- ═════════════════════════════════════════════════════════════
local CharSection = Tabs.Main:Section({ Name = "Character", Side = 1 })
local TpSection   = Tabs.Main:Section({ Name = "Teleport", Side = 1 })
local ESPSection  = Tabs.Main:Section({ Name = "ESP", Side = 2 })

-- ═════════════════════════════════════════════════════════════
--  CHARACTER CONTROLS
-- ═════════════════════════════════════════════════════════════
local WalkspeedSlider = CharSection:Slider({
    Name = "Walkspeed",
    Flag = "Walkspeed",
    Default = 16,
    Min = 0,
    Max = 1000,
    Decimals = 1,
    Callback = function(Value)
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = Value
        end
    end
})

local JumpPowerSlider = CharSection:Slider({
    Name = "JumpPower",
    Flag = "JumpPower",
    Default = 50,
    Min = 0,
    Max = 1000,
    Decimals = 1,
    Callback = function(Value)
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.JumpPower = Value
        end
    end
})

local killRow = CharSection:Button()
killRow:Add("Kill Character", function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.Health = 0
    end
end)

-- ═════════════════════════════════════════════════════════════
--  TELEPORT CONTROLS
-- ═════════════════════════════════════════════════════════════
local TeleportDropDown = TpSection:Dropdown({
    Name = "Teleport to Player",
    Flag = "TpTarget",
    Items = GetPlayerNames(),
    Multi = false,
    Callback = function(Value)
        local targetPlayer = Players:FindFirstChild(Value)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local playerChar = LocalPlayer.Character
            if playerChar and playerChar:FindFirstChild("HumanoidRootPart") then
                playerChar.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
            end
        end
    end
})

local tpRow = TpSection:Button()
tpRow:Add("Random Player", function()
    local availablePlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(availablePlayers, player)
        end
    end
    if #availablePlayers == 0 then
        VibeUI:Notification({
            Title = "Teleport Error",
            Description = "No available players to teleport to!",
            Type = "error",
            Duration = 3
        })
        return
    end

    local randomPlayer = availablePlayers[math.random(1, #availablePlayers)]
    if randomPlayer and randomPlayer.Character and randomPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local playerChar = LocalPlayer.Character
        if playerChar and playerChar:FindFirstChild("HumanoidRootPart") then
            playerChar.HumanoidRootPart.CFrame = randomPlayer.Character.HumanoidRootPart.CFrame
        end
    end
end)

-- ═════════════════════════════════════════════════════════════
--  ESP CONTROLS
-- ═════════════════════════════════════════════════════════════
ESPSection:Toggle({
    Name = "ESP",
    Flag = "ESP",
    Default = false,
    Info = "Highlight all other players",
    InfoType = "tip",
    Callback = function(Value)
        env.ESPEnabled = Value
        if env.ESPEnabled then
            EnableESP()
        else
            DisableESP()
        end
    end
})

ESPSection:Toggle({
    Name = "ESP Names",
    Flag = "ESPNames",
    Default = true,
    Info = "Show player names above ESP highlights",
    InfoType = "info",
    Callback = function(Value)
        env.ESPNamesEnabled = Value
        if env.ESPEnabled then
            DisableESP()
            EnableESP()
        end
    end
})

-- ═════════════════════════════════════════════════════════════
--  EVENTS
-- ═════════════════════════════════════════════════════════════
local function RefreshDropdown()
    pcall(function()
        TeleportDropDown:Refresh(GetPlayerNames())
    end)
end

Players.PlayerAdded:Connect(function(player)
    RefreshDropdown()
    if env.ESPEnabled then
        hookPlayer(player)
        if player.Character then
            task.spawn(createESP, player)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    unhookPlayer(player)
    RefreshDropdown()
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        task.wait(0.1)
        humanoid.WalkSpeed = WalkspeedSlider.Value or humanoid.WalkSpeed
        humanoid.JumpPower = JumpPowerSlider.Value or humanoid.JumpPower
    end
end)