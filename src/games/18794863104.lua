local Fluent, Tabs = ...
-- ═══════════════════════════════════════════════════════════════
--  Demonology -- Juniper Road
--  Scrapes client-side ghost data, auto-detects evidence,
--  cross-references the ghost type database, and provides
--  ESP + hunt monitoring.
-- ═══════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Tab = Tabs.Game

-- ── Safe references ─────────────────────────────────────────
local Ghost = workspace:WaitForChild("Ghost", 10)
local MapRooms = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Rooms")
local Modules = RepStorage:FindFirstChild("Modules")

if not Ghost then
    Tab:AddParagraph({ Title = "Error", Content = "Ghost not found." })
    return
end

-- ── Evidence database ───────────────────────────────────────
local EvidenceTypes = require(Modules:WaitForChild("EvidenceTypes"))
local GhostTypesFolder = Modules:WaitForChild("GhostTypes")

local IdToEvidence = {}
for name, id in pairs(EvidenceTypes) do
    IdToEvidence[id] = name
end

local PrettyEvidence = {
    EMFLevel5            = "EMF Level 5",
    SpiritBox            = "Spirit Box",
    GhostWriting         = "Inscription",
    FreezingTemperatures = "Freezing Temps",
    GhostOrb             = "Ghost Orb",
    Handprints           = "Prints",
    LaserProjector       = "Laser Projector",
    Wither               = "Wither",
}

local GhostDB = {}
for _, mod in pairs(GhostTypesFolder:GetChildren()) do
    if mod:IsA("ModuleScript") then
        local ok, data = pcall(require, mod)
        if ok and data and data.Evidence then
            local pretty = {}
            for _, eid in ipairs(data.Evidence) do
                local raw = IdToEvidence[eid] or "?"
                table.insert(pretty, PrettyEvidence[raw] or raw)
            end
            GhostDB[data.Name or mod.Name] = {
                Ids    = data.Evidence,
                Pretty = pretty,
            }
        end
    end
end

-- ═════════════════════════════════════════════════════════════
--  STATE
-- ═════════════════════════════════════════════════════════════
local _espHighlight     = nil
local _orbHighlight     = nil
local _orbBillboard     = nil
local _autoScan         = false
local _connections       = {}
local _lastWalkSpeed    = 0
local _notifiedGhost    = nil

-- ═════════════════════════════════════════════════════════════
--  SECTION 1 — Ghost Information
-- ═════════════════════════════════════════════════════════════
Tab:AddSection("Ghost Information")

local ProfileLabel = Tab:AddParagraph({
    Title   = "Ghost Profile",
    Content = "...",
})

local RoomLabel = Tab:AddParagraph({
    Title   = "Room Tracking",
    Content = "...",
})

local PositionLabel = Tab:AddParagraph({
    Title   = "Position / Distance",
    Content = "...",
})

local HuntLabel = Tab:AddParagraph({
    Title   = "Hunt Status",
    Content = "Idle",
})

-- ═════════════════════════════════════════════════════════════
--  SECTION 2 — Evidence Scanner
-- ═════════════════════════════════════════════════════════════
Tab:AddSection("Evidence Scanner")

local EvidenceLabel = Tab:AddParagraph({
    Title   = "Detected Evidence",
    Content = "Press Scan...",
})

local PredictionLabel = Tab:AddParagraph({
    Title   = "Ghost Prediction",
    Content = "Waiting for evidence...",
})

-- ═════════════════════════════════════════════════════════════
--  SECTION 3 — Room Temperatures
-- ═════════════════════════════════════════════════════════════
Tab:AddSection("Room Temperatures")

local TempLabel = Tab:AddParagraph({
    Title   = "All Rooms",
    Content = "...",
})

-- ═════════════════════════════════════════════════════════════
--  SECTION 4 — ESP & Tools
-- ═════════════════════════════════════════════════════════════
Tab:AddSection("ESP & Tools")

-- ═════════════════════════════════════════════════════════════
--  CORE LOGIC
-- ═════════════════════════════════════════════════════════════

-- ── Update ghost profile & rooms ────────────────────────────
local function updateGhostInfo()
    if not Ghost or not Ghost.Parent then
        Ghost = workspace:FindFirstChild("Ghost")
        if not Ghost then return end
    end

    local age    = Ghost:GetAttribute("Age")          or "?"
    local gender = Ghost:GetAttribute("Gender")       or "?"
    local model  = Ghost:GetAttribute("VisualModel")  or "?"

    ProfileLabel:SetDesc(string.format(
        "Age: %s  |  Gender: %s  |  Skin: %s",
        tostring(age), tostring(gender), tostring(model)
    ))

    local fav = Ghost:GetAttribute("FavoriteRoom") or "?"
    local cur = Ghost:GetAttribute("CurrentRoom")  or "?"
    RoomLabel:SetDesc(string.format("⭐ Favourite: %s\n📍  Current:    %s", fav, cur))

    -- distance
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart")
       and Ghost:FindFirstChild("HumanoidRootPart") then
        local dist = (char.HumanoidRootPart.Position
                    - Ghost.HumanoidRootPart.Position).Magnitude
        local pos  = Ghost.HumanoidRootPart.Position
        PositionLabel:SetDesc(string.format(
            "%.1f studs away\nX: %.0f  Y: %.0f  Z: %.0f",
            dist, pos.X, pos.Y, pos.Z
        ))
    end

    -- hunt detection (walk‐speed spike)
    local hum = Ghost:FindFirstChild("Humanoid")
    if hum then
        local ws = hum.WalkSpeed
        if ws > 14 then
            HuntLabel:SetDesc("🔴  HUNTING!  (Speed: " .. tostring(ws) .. ")")
        elseif ws > 11 then
            HuntLabel:SetDesc("🟡  Ghost agitated  (Speed: " .. tostring(ws) .. ")")
        else
            HuntLabel:SetDesc("🟢  Idle  (Speed: " .. tostring(ws) .. ")")
        end
        _lastWalkSpeed = ws
    end
end

-- ── Update room temperatures ────────────────────────────────
local function updateTemperatures()
    if not MapRooms then return end
    local lines = {}
    for _, room in pairs(MapRooms:GetChildren()) do
        if room:IsA("Folder") then
            local temp = room:GetAttribute("Temperature")
            if temp then
                local icon = temp < 1 and "🥶"
                          or temp < 5  and "❄️"
                          or "🌡️"
                table.insert(lines, string.format(
                    "%s  %s: %.1f°C", icon, room.Name, temp
                ))
            end
        end
    end
    table.sort(lines)
    if #lines > 0 then
        TempLabel:SetDesc(table.concat(lines, "\n"))
    end
end

-- ── Scan for world evidence ─────────────────────────────────
local function scanEvidence()
    local found = {}   -- EvidenceType id → true
    local lines = {}
    local behavioural = {}

    -- 1) Ghost Orb
    if workspace:FindFirstChild("GhostOrb") then
        found[EvidenceTypes.GhostOrb] = true
        table.insert(lines, "✅  Ghost Orb  (object in workspace)")
    end

    -- 2) Freezing Temperatures
    if Ghost and MapRooms then
        local favRoom = Ghost:GetAttribute("FavoriteRoom")
        if favRoom then
            local room = MapRooms:FindFirstChild(favRoom)
            if room then
                local temp = room:GetAttribute("Temperature")
                if temp and temp < 3 then
                    found[EvidenceTypes.FreezingTemperatures] = true
                    table.insert(lines, string.format(
                        "✅  Freezing Temps  (%.1f°C in %s)", temp, favRoom
                    ))
                end
            end
        end
    end

    -- 3) Handprints
    local hp = workspace:FindFirstChild("Handprints")
    if hp and #hp:GetChildren() > 0 then
        found[EvidenceTypes.Handprints] = true
        table.insert(lines, "✅  Handprints  (" .. #hp:GetChildren() .. " found)")
    end

    -- 4) Ghost Writing  (spirit book text or wall scratches)
    for _, desc in pairs(workspace:GetDescendants()) do
        local n = desc.Name
        if n == "SpiritBookWriting" or n == "WallScratch"
           or n == "GhostWriting"   or n == "WallWriting" then
            found[EvidenceTypes.GhostWriting] = true
            table.insert(lines, "✅  Ghost Writing  (" .. n .. ")")
            break
        end
    end

    -- 5) Wither  (Distortion decals on paintings become visible)
    local witherDetected = false
    for _, desc in pairs(workspace:GetDescendants()) do
        if desc:IsA("Decal") and desc.Name == "Distortion" then
            if desc.Transparency < 0.9 then
                witherDetected = true
                break
            end
        end
    end
    if not witherDetected then
        -- also check for withered plants (color shift towards brown)
        local inter = workspace:FindFirstChild("Interactables")
        if inter then
            for _, child in pairs(inter:GetChildren()) do
                if string.find(string.lower(child.Name), "plant") then
                    for _, part in pairs(child:GetDescendants()) do
                        if part:IsA("BasePart") and string.find(string.lower(part.Name), "grass") then
                            -- healthy green is ~(0.29, 0.59, 0.29); brown shift means wither
                            if part.Color.G < 0.35 then
                                witherDetected = true
                            end
                        end
                    end
                end
            end
        end
    end
    if witherDetected then
        found[EvidenceTypes.Wither] = true
        table.insert(lines, "✅  Wither  (distortion / plant decay)")
    end

    -- 6) Broken Glass  (Banshee behavioural flag)
    local bg = workspace:FindFirstChild("BrokenGlass")
    if bg and #bg:GetDescendants() > 10 then
        behavioural.BrokenGlass = true
        table.insert(lines, "⚠️  Broken Glass  (Banshee behaviour)")
    end

    -- 7) Laser visibility  (rules out Vex when visible)
    if Ghost then
        local lv = Ghost:GetAttribute("LaserVisible")
        if lv == true then
            behavioural.LaserVisible = true
            table.insert(lines, "ℹ️  Visible on LIDAR  (rules out Vex)")
        elseif lv == false then
            behavioural.LaserInvisible = true
            table.insert(lines, "⚠️  Invisible on LIDAR  (Vex indicator)")
        end
    end

    -- 8) Fuse box state
    local fuseBox = workspace.Map:FindFirstChild("FuseBox")
    if fuseBox then
        local enabled = fuseBox:GetAttribute("Enabled")
        if enabled == false then
            table.insert(lines, "ℹ️  Fuse Box OFF  (ghost may have tripped it)")
        end
    end

    return found, lines, behavioural
end

-- ── Cross-reference ghost DB ────────────────────────────────
local function predictGhost(foundIds, behavioural)
    local possible = {}

    for ghostName, data in pairs(GhostDB) do
        local valid = true

        -- every confirmed evidence must exist in this ghost's set
        for eid, _ in pairs(foundIds) do
            if not table.find(data.Ids, eid) then
                valid = false
                break
            end
        end

        -- behavioural: laser-visible rules out Vex
        if valid and behavioural.LaserVisible and ghostName == "Vex" then
            valid = false
        end

        if valid then
            table.insert(possible, {
                Name     = ghostName,
                Evidence = table.concat(data.Pretty, "  |  "),
            })
        end
    end

    table.sort(possible, function(a, b) return a.Name < b.Name end)
    return possible
end

-- ── Combined scan + predict ─────────────────────────────────
local function scanAndPredict()
    local foundIds, lines, behavioural = scanEvidence()

    EvidenceLabel:SetDesc(
        #lines > 0
            and table.concat(lines, "\n")
            or  "No evidence detected yet."
    )

    local possible = predictGhost(foundIds, behavioural)
    local pLines   = {}
    for _, g in ipairs(possible) do
        table.insert(pLines, g.Name .. "  →  " .. g.Evidence)
    end

    local total = 0
    for _ in pairs(GhostDB) do total += 1 end

    if #possible == 1 then
        PredictionLabel:SetTitle("🎯 Ghost Identified!")
        PredictionLabel:SetDesc(pLines[1])

        -- Fire notification only once per unique identification
        if _notifiedGhost ~= possible[1].Name then
            _notifiedGhost = possible[1].Name
            Fluent:Notify({
                Title    = "BloxxerHub - Ghost Identified! 👻",
                Content  = possible[1].Name .. "\n" .. possible[1].Evidence,
                Duration = 8,
            })
        end
    elseif #possible > 0 and #possible <= 5 then
        PredictionLabel:SetTitle("Narrowed Down  (" .. #possible .. "/" .. total .. ")")
        PredictionLabel:SetDesc(table.concat(pLines, "\n"))
        _notifiedGhost = nil  -- reset so it re-notifies if it narrows to 1 later
    elseif #possible > 5 then
        PredictionLabel:SetTitle("Possible Ghosts  (" .. #possible .. "/" .. total .. ")")
        PredictionLabel:SetDesc("Collect more evidence to narrow it down.\n\n"
            .. table.concat(pLines, "\n"))
        _notifiedGhost = nil
    else
        PredictionLabel:SetTitle("Ghost Prediction")
        PredictionLabel:SetDesc("No matches — evidence may conflict.")
        _notifiedGhost = nil
    end
end

-- ═════════════════════════════════════════════════════════════
--  UI CONTROLS
-- ═════════════════════════════════════════════════════════════

Tab:AddButton({
    Title       = "🔍  Scan Evidence Now",
    Description = "Check workspace for all evidence and predict the ghost",
    Callback    = scanAndPredict,
})

Tab:AddToggle("AutoScan", {
    Title   = "Auto-Scan  (every 3s)",
    Default = false,
    Callback = function(v)
        _autoScan = v
    end,
})

-- ── ESP ─────────────────────────────────────────────────────

Tab:AddToggle("GhostESP", {
    Title   = "Ghost ESP  (Highlight)",
    Default = false,
    Callback = function(enabled)
        if enabled then
            if Ghost and not _espHighlight then
                local h = Instance.new("Highlight")
                h.Adornee            = Ghost
                h.FillColor          = Color3.fromRGB(255, 40, 40)
                h.FillTransparency   = 0.6
                h.OutlineColor       = Color3.fromRGB(255, 255, 255)
                h.OutlineTransparency = 0
                h.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
                h.Parent             = Ghost
                _espHighlight = h
            end
        else
            if _espHighlight then
                _espHighlight:Destroy()
                _espHighlight = nil
            end
        end
    end,
})

Tab:AddToggle("OrbESP", {
    Title   = "Ghost Orb ESP",
    Default = false,
    Callback = function(enabled)
        if enabled then
            local orb = workspace:FindFirstChild("GhostOrb")
            if orb then
                local h = Instance.new("Highlight")
                h.Adornee            = orb
                h.FillColor          = Color3.fromRGB(180, 255, 255)
                h.FillTransparency   = 0.3
                h.OutlineColor       = Color3.fromRGB(255, 255, 255)
                h.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
                h.Parent             = orb
                _orbHighlight = h

                local bb = Instance.new("BillboardGui")
                bb.Adornee        = orb
                bb.Size           = UDim2.new(0, 120, 0, 30)
                bb.StudsOffset    = Vector3.new(0, 3, 0)
                bb.AlwaysOnTop    = true
                bb.Parent         = orb
                local lbl = Instance.new("TextLabel")
                lbl.Size             = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.TextColor3       = Color3.fromRGB(180, 255, 255)
                lbl.TextStrokeTransparency = 0
                lbl.Text             = "GHOST ORB"
                lbl.Font             = Enum.Font.GothamBold
                lbl.TextScaled       = true
                lbl.Parent           = bb
                _orbBillboard = bb
            end
        else
            if _orbHighlight then _orbHighlight:Destroy(); _orbHighlight = nil end
            if _orbBillboard then _orbBillboard:Destroy(); _orbBillboard = nil end
        end
    end,
})

Tab:AddToggle("GhostChams", {
    Title    = "Ghost Chams  (Transparent Walls)",
    Default  = false,
    Callback = function(enabled)
        if Ghost then
            local vis = Ghost:FindFirstChild("VisibleParts")
            if vis then
                for _, part in pairs(vis:GetDescendants()) do
                    if part:IsA("BasePart") then
                        -- when chams ON: make ghost parts always render on top
                        -- we abuse ZOffset on SurfaceAppearances or change RenderFidelity
                    end
                end
            end
            -- simpler approach: just ensure the Highlight stays
            if enabled and not _espHighlight then
                local h = Instance.new("Highlight")
                h.Adornee            = Ghost
                h.FillColor          = Color3.fromRGB(255, 0, 100)
                h.FillTransparency   = 0.4
                h.OutlineColor       = Color3.fromRGB(255, 255, 0)
                h.OutlineTransparency = 0
                h.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
                h.Parent             = Ghost
                _espHighlight = h
            elseif not enabled and _espHighlight then
                _espHighlight:Destroy()
                _espHighlight = nil
            end
        end
    end,
})

Tab:AddButton({
    Title       = "📍  Teleport to Ghost Room",
    Description = "Move your character to the ghost's current room",
    Callback    = function()
        if not Ghost or not Ghost:FindFirstChild("HumanoidRootPart") then return end
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local ghostPos = Ghost.HumanoidRootPart.Position
            char.HumanoidRootPart.CFrame = CFrame.new(
                ghostPos + Vector3.new(10, 0, 0)
            )
        end
    end,
})

Tab:AddButton({
    Title       = "⚡  Trip Fuse Box",
    Description = "Attempt to fire the fuse box remote",
    Callback    = function()
        local events = RepStorage:FindFirstChild("Events")
        if events then
            local fuse = events:FindFirstChild("UseLightSwitch")
            if fuse then
                pcall(function()
                    fuse:FireServer("FuseBox")
                end)
            end
        end
    end,
})

-- ═════════════════════════════════════════════════════════════
--  MAIN LOOP  — refreshes every frame / on interval
-- ═════════════════════════════════════════════════════════════

local _scanClock = 0

table.insert(_connections, RunService.Heartbeat:Connect(function(dt)
    pcall(updateGhostInfo)

    _scanClock += dt
    if _scanClock >= 3 then
        _scanClock = 0
        pcall(updateTemperatures)
        if _autoScan then
            pcall(scanAndPredict)
        end
    end
end))

-- initial kick
task.defer(function()
    updateGhostInfo()
    updateTemperatures()
    scanAndPredict()
end)
