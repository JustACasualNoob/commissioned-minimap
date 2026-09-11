local Minimap = require(script.Minimap)
local player = game:GetService("Players").LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()

Minimap.OnCharacterAdded(char)