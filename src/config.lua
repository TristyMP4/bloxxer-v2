--[[
    Hub Config
]]

local VibeUI = ...

local Config = {
    Title = "BloxxerHub - V2.0.6",

    -- News Ticker Settings
    Ticker = {
        Enabled = true,
        Tag = "NEWS", 
        Side = "Top",                      -- "Top" or "Bottom"
        Speed = 80,                        -- Scroll speed (pixels per second)
        Width = 480,                       -- Width of the ticker bar
        Margin = 14,                       -- Screen margin
        Separator = "   |   ",             -- Separator between messages
        Messages = {
            "Welcome to BloxxerHub!",
            "Update 2.06: Operation One: Added TriggerBot & Bug Fixes",
            "have fun!",
        }
    }
}

if VibeUI and Config.Ticker and Config.Ticker.Enabled and #Config.Ticker.Messages > 0 then
    Config.Instance = VibeUI:Ticker(Config.Ticker)
end

return Config
