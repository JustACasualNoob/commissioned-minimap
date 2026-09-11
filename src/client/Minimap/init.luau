local Minimap = {}

local MinimapObject = require(script:WaitForChild("MinimapObject"))
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local SpringDale = workspace.Map:WaitForChild("SpringDale")
local MapOrigin = SpringDale:GetPivot().Position

local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local MapUI = script:WaitForChild("MinimapUI") -- uses premade UI relative to where the script was placed

local Folders = {
	NPCs = workspace:WaitForChild("Map"):WaitForChild("MapName") -- names are removed for client's privacy
}

local NameToType = {
	["NPCs"] = "NPC"
}

local NameToId = {
	["NPCs"] = "rbxassetid://someNumber", -- ids are also removed for client's privacy
	["Player"] = "rbxassetid://someNumber",
}

local CONFIG = {
	xMapSize = 1800,
	zMapSize = 1800,
	defaultFramePos = UDim2.fromScale(0.943, 0.872),
	defaultFrameSize = UDim2.fromScale(0.099, 0.221),
	scaledPosition = UDim2.fromScale(0.5, 0.5),
	scaledSize = UDim2.fromScale(1, 10),
	MaxZoom = 5,
}

-- calibration
local BASE_SIZE = Vector2.new(450, 450)
local OFFSET = Vector2.new(35, 20)
local SCALE = Vector2.new(0.8, 0.8)
local NORTH = 90 -- the orientation in world to north in minimap

local AllObjects = {}

-- minimap states
local open = false
local isDragging = false

local offsetX = 0
local offsetY = 0

local loop: RBXScriptConnection
local minimapFrame: Frame
local minimap: ImageLabel
local minimapCloseButton: Frame
local minimapEnlargeButton: TextButton
local relativeScale = 1

-- zoom states
local held = false
local currentZoom = 1
local zoomContainer: Frame

local function getRoot()
	local char = Player.Character
	if not char then return end
	
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	return root
end

local function toRotation(angle: number)
	local normalized = (angle + 180) % 360 - 180
	return NORTH - normalized
end

local function getClampLimits()
	local camera = workspace.CurrentCamera
	local viewportSize = camera.ViewportSize
	local mapSize = minimap.AbsoluteSize

	local maxOffsetX = (mapSize.X - viewportSize.X) / 2
	local maxOffsetY = (mapSize.Y - viewportSize.Y) / 2

	return maxOffsetX, maxOffsetY
end

function Minimap.OnCharacterAdded(character: Model)
	local clone = MapUI:Clone()
	clone.Parent = PlayerGui
	
	minimapFrame = clone:WaitForChild("Minimap")
	zoomContainer = clone:WaitForChild("ZoomContainer")
	minimapCloseButton = clone:WaitForChild("CloseMinimap"):WaitForChild("Button")

	minimap = minimapFrame:WaitForChild("ImageLabel")
	minimapEnlargeButton = minimapFrame:WaitForChild("EnlargeMinimap")
	
	-- handle zoom
	local zoomBar = zoomContainer:WaitForChild("ZoomBar")
	local zoomDot = zoomBar:WaitForChild("Dot") :: TextButton

	local function updateSlider()
		local barPos = zoomBar.AbsolutePosition
		local barSize = zoomBar.AbsoluteSize

		local inset = GuiService:GetGuiInset()
		local mouseY = UserInputService:GetMouseLocation().Y - inset.Y

		local clampedY = math.clamp(mouseY, barPos.Y, barPos.Y + barSize.Y)

		local alpha = (clampedY - barPos.Y) / barSize.Y
		local zoom = CONFIG.MaxZoom - (CONFIG.MaxZoom - 1) * alpha
		
		currentZoom = zoom

		zoomDot.Position = UDim2.fromScale(0.5, alpha)
		minimap.Size = UDim2.fromScale(zoom, zoom)
		
		-- adjust map (if necessary)
		local maxX, maxY = getClampLimits()

		offsetX = math.clamp(offsetX, -maxX, maxX)
		offsetY = math.clamp(offsetY, -maxY, maxY)

		minimap.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
	end
	
	zoomDot.MouseButton1Down:Connect(function()
		held = true
		
		updateSlider()
	end)
	
	local halfX = CONFIG.xMapSize/2
	local halfZ = CONFIG.zMapSize/2
		
	-- handle opening button
	minimapEnlargeButton.Activated:Connect(function()
		minimapEnlargeButton.Visible = false
		Minimap:Toggle()
	end)	
	
	-- handle closing button
	minimapCloseButton.Activated:Connect(function()
		Minimap:Toggle()
	end)
	
	-- link all folders children added
	for folderName, folder in pairs(Folders) do
		local _type = NameToType[folderName]
		local id = NameToId[folderName]
		if not _type then continue end
		
		-- link any additions
		folder.ChildAdded:Connect(function(child)
			AllObjects[child] = MinimapObject.new(child, minimap, _type, id)
			
			child.Destroying:Once(function()
				if AllObjects[child] then
					AllObjects[child]:Destroy()
				end
			end)
		end)
		
		-- link any already existing
		for _, child in ipairs(folder:GetChildren()) do
			if not AllObjects[child] then
				AllObjects[child] = MinimapObject.new(child, minimap, _type, id)
				
				child.Destroying:Once(function()
					if AllObjects[child] then
						AllObjects[child]:Destroy()
					end
				end)
			end
		end
	end
	
	-- link player character
	AllObjects[character] = MinimapObject.new(character, minimapFrame, "Player", NameToId["Player"])
	AllObjects[character]:Step(UDim2.fromScale(0.5,0.5))

	relativeScale = (minimap.AbsoluteSize.X / BASE_SIZE.X)

	RunService.RenderStepped:Connect(function()
		-- handle zoom
		if held and open then -- needs to be held AND minimap state must be open
			updateSlider()
		end
				
		-- handle minimap objects
		for object, controller in pairs(AllObjects) do
			local pivot = object:GetPivot()
			local relativePos = pivot.Position - MapOrigin

			local normX = relativePos.X / halfX
			local normZ = relativePos.Z / halfZ

			-- flip axes
			normX = -normX
			normZ = -normZ

			-- fit to ui [0,1]
			local alphaX = (normX + 1) / 2
			local alphaZ = (normZ + 1) / 2

			-- raw pixel position
			local rawPixelX = alphaX * SCALE.X/currentZoom * minimap.AbsoluteSize.X + relativeScale*OFFSET.X
			local rawPixelY = alphaZ * SCALE.Y/currentZoom * minimap.AbsoluteSize.Y + relativeScale*OFFSET.Y

			rawPixelX *= currentZoom
			rawPixelY *= currentZoom

			if controller:GetType() == "Player" then
				if open then -- minimap expanded
					controller:Step(UDim2.fromOffset(rawPixelX, rawPixelY))
				else
					local centerX = minimap.AbsoluteSize.X / 2
					local centerY = minimap.AbsoluteSize.Y / 2

					local offsetX = centerX - rawPixelX
					local offsetY = centerY - rawPixelY

					minimap.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
					controller:Step(UDim2.fromScale(0.5, 0.5))
				end
				
				local root = getRoot() :: BasePart
				if root then
					local _, y, _ = root.CFrame:ToEulerAnglesYXZ()
					local degrees = math.deg(y)
					controller:Rotate(toRotation(degrees))
				end
			else
				controller:Step(UDim2.fromOffset(rawPixelX, rawPixelY))
			end
		end
	end)
end

function Minimap:Toggle()
	if not (minimapFrame and minimap and zoomContainer and minimapEnlargeButton) then return end
	local char = Player.Character
	if not char then return end
	
	local controller = AllObjects[char]
	
	open = not open
	
	if loop then loop:Disconnect(); loop = nil end
	
	if open then
		-- toggle on
		minimapEnlargeButton.Visible = false
		
		minimapFrame.Position = CONFIG.scaledPosition
		minimapFrame.Size = CONFIG.scaledSize
		minimap.Size = UDim2.fromScale(1,1)
		minimap.Position = UDim2.fromScale(0.5, 0.5)
		
		-- set the player dot as a child of the minimap image for this duration
		AllObjects[char].frame.Parent = minimap
		controller:UpdateSize(true)

		-- enable zoom for interaction
		zoomContainer.Visible = true
		zoomContainer:WaitForChild("ZoomBar"):WaitForChild("Dot").Position = UDim2.fromScale(0.5, 1) -- reset
		
		local lastMousePos = UserInputService:GetMouseLocation()
		RunService.RenderStepped:Connect(function()
			if isDragging then
				local currentMousePos = UserInputService:GetMouseLocation()
				local delta = currentMousePos - lastMousePos

				offsetX -= -delta.X
				offsetY -= -delta.Y

				local maxX, maxY = getClampLimits()

				offsetX = math.clamp(offsetX, -maxX, maxX)
				offsetY = math.clamp(offsetY, -maxY, maxY)

				minimap.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
			end

			lastMousePos = UserInputService:GetMouseLocation()
		end)
		
		relativeScale = (minimap.AbsoluteSize.X / BASE_SIZE.X)
		minimapCloseButton.Parent.Visible = true
	else
		-- toggle off
		minimapFrame.Position = CONFIG.defaultFramePos
		minimapFrame.Size = CONFIG.defaultFrameSize
		minimap.Size = UDim2.fromScale(4,4)
		
		-- set to normal again
		controller.frame.Parent = minimapFrame
		controller:UpdateSize()
		
		-- disable zoom
		zoomContainer.Visible = false
		currentZoom = 1
		zoomContainer:WaitForChild("ZoomBar"):WaitForChild("Dot").Position = UDim2.fromScale(0.5, 1) -- reset
		
		-- reenable enlarging button
		minimapEnlargeButton.Visible = true
		minimapCloseButton.Parent.Visible = false
		
		relativeScale = (minimap.AbsoluteSize.X / BASE_SIZE.X)
	end
end

-- listen to key press
UserInputService.InputBegan:Connect(function(inp, proc)
	if proc then return end
	
	if inp.KeyCode == Enum.KeyCode.M then
		Minimap:Toggle()	
	end
	if inp.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = true
	end
end)

UserInputService.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = false
		held = false
	end
end)

return Minimap