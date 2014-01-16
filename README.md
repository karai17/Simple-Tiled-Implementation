Simple Tiled Implementation
==
---
Simple Tiled Implementation is a [**Tiled Map Editor**][Tiled] library designed for the *awesome* [**LÖVE**][LOVE] framework.

Quick Example
--
---
```lua     
local sti = require "sti"

function love.load()
	-- Load a map exported from Tiled as a lua file
	map = sti.new("assets/maps/map01")
	
	-- Create a collision map to use with your own collision code
	map:createCollisionMap("LayerName")
	
	-- Convert any layer to a Custom Layer
	map:convertToCustomLayer("SpriteLayer")
	
	-- Add data to Custom Layer
	local spriteLayer = map.map.layers["SpriteLayer"]
	spriteLayer.sprites = {
		player = {
			image = love.graphics.newImage("assets/sprites/player.png"),
			x = 64,
			y = 64,
			r = 0,
		}
	}
	
	-- Customize Update callback for Custom Layer
	function spriteLayer:update(dt)
		for _, sprite in pairs(self.sprites) do
			sprite.r = sprite.r + 90 * dt
		end
	end
	
	-- Customize draw callback for Custom Layer
	function spriteLayer:draw()
		for _, sprite in pairs(self.sprites) do
			local x = math.floor(sprite.x)
			local y = math.floor(sprite.y)
			local r = math.rad(sprite.r)
			love.graphics.draw(sprite.image, x, y, r)
		end
	end
end

function love.update(dt)
	map:update(dt)
end

function love.draw()
	-- Draw map
	map:draw()
	
	-- Draw Collision Map (useful for debugging)
	map:drawCollisionMap()
end

```

License
--
---
This code is licensed under the [**MIT Open Source License**][MIT]. Check out the LICENSE file for more information.

[Tiled]: http://www.mapeditor.org/
[LOVE]: https://www.love2d.org/
[MIT]: http://www.opensource.org/licenses/mit-license.html