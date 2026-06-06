local Fluent, Tabs = ...

Tabs.Game:AddButton({
    Title = "Test Button",
    Callback = function()
        print("Hello!")
    end
})
