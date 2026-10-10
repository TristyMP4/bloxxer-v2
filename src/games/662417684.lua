local VibeUI, Tabs = ...
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- LUCKY BLOCK BATTLE GROUNDS --

local SpawningSection = Tabs.Game:Section({ Name = "Block Spawning", Side = 1 })
local CombatSection   = Tabs.Game:Section({ Name = "Combat", Side = 2 })
local TeleportSection = Tabs.Game:Section({ Name = "Teleport", Side = 2 })

local spawnGalaxyBtn = SpawningSection:Button()
spawnGalaxyBtn:Add("Spawn Galaxy Block", function()
    ReplicatedStorage.SpawnGalaxyBlock:FireServer()
end)

local spawnRainbowBtn = SpawningSection:Button()
spawnRainbowBtn:Add("Spawn Rainbow Block", function()
    ReplicatedStorage.SpawnRainbowBlock:FireServer()
end)

local SpawnGalaxyBlocks = SpawningSection:Textbox({
    Name = "Spawn Multiple Galaxy Blocks",
    Flag = "SpawnGalaxyBlocks",
    Placeholder = "1000",
    Numeric = true, -- Only allows numbers
    Finished = true, -- Only calls callback when you press enter
    Callback = function(Value)
        Value = tonumber(Value)
        if Value and Value > 0 then
            for i = 1, Value do
                ReplicatedStorage.SpawnGalaxyBlock:FireServer()
            end
        end
    end
})

local SpawnRainbowBlocks = SpawningSection:Textbox({
    Name = "Spawn Multiple Rainbow Blocks",
    Flag = "SpawnRainbowBlocks",
    Placeholder = "1000",
    Numeric = true, -- Only allows numbers
    Finished = true, -- Only calls callback when you press enter
    Callback = function(Value)
        Value = tonumber(Value)
        if Value and Value > 0 then
            for i = 1, Value do
                ReplicatedStorage.SpawnRainbowBlock:FireServer()
            end
        end
    end
})

CombatSection:Label("Requires to be holding Hex Spitter Gun to use!")
local killAllBtn = CombatSection:Button()
killAllBtn:Add("Kill All", function()
    local HexSpitter = Players.LocalPlayer.Character.HexSpitter
    local ServerControl = HexSpitter.Remotes.ServerControl

    VibeUI:Notification({
        Title = "BloxxerHub",
        Description = "Killing everyone - This may take a while!",
        Type = "info",
        Duration = 3
    })

    for _ = 1, 20 do
        for _, Child in next, Players:GetPlayers() do
            if Child ~= Players.LocalPlayer then
                ServerControl:InvokeServer('RayHit', {['Position'] = Vector3.new(0, 0, 0), ["Hit"] = Child.Character.Head})
            end
        end
    end

    VibeUI:Notification({
        Title = "BloxxerHub",
        Description = "Killed everyone successfully!",
        Type = "info",
        Duration = 3
    })
end)

local tpCenterBtn = TeleportSection:Button()
tpCenterBtn:Add("Teleport to Center", function()
    local char = getCharacter(Players.LocalPlayer.Name)
    char.HumanoidRootPart.CFrame = workspace.CenterBlocks.Givers.VoidGiver.ColoredParts.Center.CFrame
end)

local tpBaseBtn = TeleportSection:Button()
tpBaseBtn:Add("Teleport to Base", function()
    local char = getCharacter(Players.LocalPlayer.Name)
    for i, part in workspace:GetDescendants() do
        if part:IsA("StringValue") then
            if part.Value == Players.LocalPlayer.Name then
                char.HumanoidRootPart.CFrame = part.Parent:FindFirstChild("SpawnLocation").CFrame
            end
        end
    end
end)