# Simple Tiled Implementation

Simple Tiled Implementation is a [**Tiled Map Editor**][Tiled] library designed for the *awesome* [**LÖVE**][LOVE] framework. Please read the library [**documentation**][dox] to learn how it all works!


## Quick Example

```lua     
local sti = require "sti"

function love.load()
	-- Grab window size
	windowWidth = love.graphics.getWidth()
	windowHeight = love.graphics.getHeight()

	-- Set world meter size (in pixels)
	love.physics.setMeter(32)

	-- Load a map exported to Lua from Tiled
	map = sti.new("assets/maps/map01")

	-- Prepare physics world (horizontal and vertical gravity)
	world = love.physics.newWorld(0*love.physics.getMeter(), 0*love.physics.getMeter())

	-- Prepare collision objects
	collision = map:initWorldCollision(world)
	
	-- Create a Custom Layer
	map:addCustomLayer("Sprite Layer", 3)
	
	-- Add data to Custom Layer
	local spriteLayer = map.layers["Sprite Layer"]
	spriteLayer.sprites = {
		player = {
			image = love.graphics.newImage("assets/sprites/player.png"),
			x = 64,
			y = 64,
			r = 0,
		}
	}
	
	-- Update callback for Custom Layer
	function spriteLayer:update(dt)
		for _, sprite in pairs(self.sprites) do
			sprite.r = sprite.r + math.rad(90 * dt)
		end
	end
	
	-- Draw callback for Custom Layer
	function spriteLayer:draw()
		for _, sprite in pairs(self.sprites) do
			local x = math.floor(sprite.x)
			local y = math.floor(sprite.y)
			local r = sprite.r
			love.graphics.draw(sprite.image, x, y, r)
		end
	end
end

function love.update(dt)
	map:update(dt)
end

function love.draw()
	-- Translation would normally be based on a player's x/y
	local translateX = 0
	local translateY = 0
	
	-- Draw Range culls unnecessary tiles
	map:setDrawRange(translateX, translateY, windowWidth, windowHeight)
	
	-- Draw the map and all objects within
	map:draw()
	
	-- Draw Collision Map (useful for debugging)
	love.graphics.setColor(255, 0, 0, 255)
	map:drawWorldCollision(collision)

	-- Reset color
	love.graphics.setColor(255, 255, 255, 255)
end
```


## Requirements

This library requires LÖVE 0.9.1 and Tiled 0.10.1. If you are updating from an older version of Tiled, please re-export your Lua map files.


## License

This code is licensed under the [**MIT Open Source License**][MIT]. Check out the LICENSE file for more information.

[Tiled]: http://www.mapeditor.org/
[LOVE]: https://www.love2d.org/
[dox]: http://karai17.github.io/Simple-Tiled-Implementation/
[MIT]: http://www.opensource.org/licenses/mit-license.html
