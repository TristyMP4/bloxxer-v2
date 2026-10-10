local VibeUI = loadstring(game:HttpGet("https://sirmemegithub.com/RealSlimShady2000/VibeUI/raw/branch/main/VibeUI.luau"))()
local HttpService = game:GetService("HttpService")
local ExperienceService = game:GetService("ExperienceService")
local gameList = HttpService:JSONDecode(game:HttpGet(getgitpath("src") .. "gameslist.json"))

local env = getgenv()
function env.getCharacter(playerName)
    local player = game.Players:FindFirstChild(playerName)
    if player then
        local char = player.Character
        if not char then
            player.CharacterAdded:Wait()
            char = player.Character
        end
        return char
    else
        return warn("No player found!")
    end
end

-- ── VibeUI configuration ────────────────────────────────────
VibeUI:SetGlass(true)
VibeUI:SetGlassBlur(14)
VibeUI:SetGlow(0.3)

local Window = VibeUI:Window({
    Title = "BloxxerHub",
    Size = UDim2.fromOffset(720, 520),
    Keybind = Enum.KeyCode.LeftControl,
    Layout = "Side",
})

local Watermark = VibeUI:Watermark("BloxxerHub • " .. game.Players.LocalPlayer.Name)
local Tabs = {
    Main = Window:Tab({ Name = "Universal", Columns = 2 }),
    Game = Window:Tab({ Name = "Game", Columns = 2 }),
    Scripts = Window:Tab({ Name = "Scripts", Columns = 1 }),
    Credits = Window:Tab({ Name = "Credits", Columns = 1 }),
}

-- ── Load tabs ────────────────────────────────────────
loadstring(game:HttpGet(getgitpath("src") .. "universal.lua"))(VibeUI, Tabs)
loadstring(game:HttpGet(getgitpath("src") .. "scripts.lua"))(VibeUI, Tabs)
loadstring(game:HttpGet(getgitpath("src") .. "credits.lua"))(VibeUI, Tabs)
loadstring(game:HttpGet(getgitpath("src") .. "settings.lua"))(VibeUI, Tabs)

-- ── Settings page (adds Theming / Configs / Interface tab) ──
VibeUI:CreateSettingsPage(Window, Watermark)

-- ── Load game-specific script ───────────────────────────────
local ok, gamePath = pcall(function()
    return game:HttpGet(getgitpath("games") .. tostring(game.PlaceId) .. ".lua")
end)

if isfile("BloxxerHub/" .. tostring(game.PlaceId) .. ".lua") then
    loadstring(readfile("BloxxerHub/" .. tostring(game.PlaceId) .. ".lua"))(VibeUI, Tabs)
elseif ok and #gamePath ~= 0 and gamePath ~= "404: Not Found" then
    print("game loaded")
    loadstring(gamePath)(VibeUI, Tabs)
else
    print("no game")
    local GameInfo = Tabs.Game:Section({ Name = "Game List", Side = 1 })
    GameInfo:Paragraph({
        Name = "Supported Games",
        Content = "No game-specific script detected.\nClick a game below to join it."
    })

    for _, g in ipairs(gameList) do
        local row = GameInfo:Button()
        row:Add(g.game .. "  [" .. g.status .. "]", function()
            queue_on_teleport([[
                loadstring(game:HttpGet("https://raw.githubusercontent.com/TristyMP4/bloxxer-v2/refs/heads/main/loader.lua"))()
            ]])
            task.wait()
            ExperienceService:LaunchExperience({ placeId = g.id })
        end)
    end
end

VibeUI:Notification({
    Title = "BloxxerHub",
    Description = "Loaded successfully!",
    Type = "success",
    Duration = 4
})