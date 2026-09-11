local MinimapObject = {}
MinimapObject.__index = MinimapObject

export type minimapTypes = "Player" | "Item" | "Enemy" | "Door" | "Oni"

local TypeToColor = {
	["Player"] = Color3.fromRGB(70, 255, 98),
	["Item"] = Color3.fromRGB(255, 230, 39),
	["Enemy"] = Color3.fromRGB(255, 51, 51),
    ["Oni"] = Color3.fromRGB(0,0,0),
	["Door"] = Color3.fromRGB(76, 255, 204),
}

local sDiff = 10/255
local BASE_SIZE = UDim2.fromScale(0.022, 0.022)
local ONI_SIZE = UDim2.fromScale(BASE_SIZE.X.Scale*1.5, BASE_SIZE.Y.Scale*1.5)
local PLAYER_BASE_SIZE = UDim2.fromScale(0.086, 0.086)

local function makeIcon(_type, imageId)
	local frame
	if not imageId then
		frame = Instance.new("Frame")
		local uiCorner = Instance.new("UICorner")
		local uiStroke = Instance.new("UIStroke")

        uiCorner.Parent = frame
        uiStroke.Parent = frame

		uiCorner.CornerRadius = UDim.new(1,0)
		
		local targetColor = TypeToColor[_type] or Color3.fromRGB(255,255,255)
		local strokeColor = Color3.fromRGB(targetColor.R - sDiff, targetColor.G - sDiff, targetColor.B - sDiff)
		
		uiStroke.Color = strokeColor
		frame.BackgroundColor3 = targetColor
	else
		frame = Instance.new("ImageLabel")
		frame.BackgroundTransparency = 1
		frame.Image = imageId
	end
	
	frame.AnchorPoint = Vector2.new(0.5, 0.5)

	return frame
end

function MinimapObject.new(object: Model, parent: Frame, _type: minimapTypes, imageId: string?)
	local self = setmetatable({}, MinimapObject)
	
	self.object = object
	self.parent = parent
	self.frame = makeIcon(_type, imageId)
	self.type = _type
	
	self.frame.Size = (_type == "Player" and PLAYER_BASE_SIZE) 
		or (_type == "Oni" and ONI_SIZE) or BASE_SIZE
	
	self.frame.Parent = parent
	self.frame.Name = object.Name
	
	self.baseSize = self.frame.Size
	
	return self
end

function MinimapObject:UpdateSize(toBase: boolean?)
	local target = toBase and BASE_SIZE or self.baseSize
	self.frame.Size = target
end

function MinimapObject:GetType()
	return self.type
end

function MinimapObject:Rotate(rotation)
	self.frame.Rotation = rotation
end

function MinimapObject:Step(newPos: UDim2)
	self.frame.Position = newPos
end

function MinimapObject:Destroy()
	if self.frame then
		self.frame:Destroy()
	end
end

return MinimapObject