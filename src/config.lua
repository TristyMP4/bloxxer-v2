--[[
    Hub Config
]]

local VibeUI = ...

local Config = {
    -- Window / Hub Title
    Title = "BloxxerHub - V2.0.2",

    -- News Ticker Settings
    Ticker = {
        Enabled = true,                    -- Set to false to hide the ticker completely
        Tag = "NEWS",                      -- Badge text on the left (e.g. "NEWS", "ANNOUNCEMENT", "UPDATE")
        Side = "Top",                      -- "Top" or "Bottom"
        Speed = 80,                        -- Scroll speed (pixels per second)
        Width = 480,                       -- Width of the ticker bar
        Margin = 14,                       -- Screen margin
        Separator = "   |   ",             -- Separator between messages
        Messages = {
            "Welcome to BloxxerHub!",
            "Update 2.1: Added Operation One support; still in development!",
            "have fun!",
        }
    }
}

if VibeUI and Config.Ticker and Config.Ticker.Enabled and #Config.Ticker.Messages > 0 then
    Config.Instance = VibeUI:Ticker(Config.Ticker)
end

return Config