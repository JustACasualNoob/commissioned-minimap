# Commissioned Minimap

A custom Roblox minimap system developed as part of a paid client commission.

The system converts 3D world positions into 2D minimap coordinates, tracks dynamic world objects, and supports both compact and expanded map views.

> Client-specific names, asset IDs, and project details have been removed for privacy.

![Minimap Gameplay](assets/commissioned-minimap.gif)

## Features

- Real-time world-to-minimap position conversion
- Dynamic tracking of NPCs and other world objects
- Player position and rotation tracking
- Compact player-centered minimap mode
- Expanded map view
- Zoom controls
- Map dragging/panning
- Multiple marker types and custom icons
- Automatic marker creation and cleanup

## Architecture

- **World-to-UI coordinate conversion** — world positions are normalized relative to the map origin and converted into minimap pixel coordinates.
- **Object controllers** — each tracked object is represented by a `MinimapObject` responsible for its marker, position, rotation, size, and cleanup.
- **Dynamic object registration** — objects added to tracked folders are automatically added to the minimap and removed when destroyed.
- **Centralized render update** — tracked objects are updated each frame through a single `RenderStepped` loop.
- **Configurable map calibration** — map dimensions, scale, offset, orientation, and zoom limits are separated into configuration values.
- **Multiple display modes** — the system switches between a compact player-centered minimap and an expanded navigable map.

## What I worked on
I designed and implemented the minimap system, including coordinate conversion, object tracking, marker controllers, map interaction, zooming, and player orientation handling.

## Example

A world-space object is converted into normalized minimap coordinates:

```lua
local relativePos = object:GetPivot().Position - MapOrigin

local normX = relativePos.X / halfX
local normZ = relativePos.Z / halfZ

local alphaX = (-normX + 1) / 2
local alphaZ = (-normZ + 1) / 2

local x = alphaX * minimap.AbsoluteSize.X
local y = alphaZ * minimap.AbsoluteSize.Y

controller:Step(UDim2.fromOffset(x, y))
