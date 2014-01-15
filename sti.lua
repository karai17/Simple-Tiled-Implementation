--[[
------------------------------------------------------------------------------
Simple Tiled Implementation is licensed under the MIT Open Source License.
(http://www.opensource.org/licenses/mit-license.html)
------------------------------------------------------------------------------

Copyright (c) 2014 Landon Manning - LManning17@gmail.com - LandonManning.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

local sti = {}

function sti:new(map)
	-- Load the map
	self.map = require(map)
	self.map.quads = {}
	
	-- Create array of quads, tileset's lastgid
	local gid = 1
	for i, tileset in ipairs(self.map.tilesets) do
		local iw		= tileset.imagewidth
		local ih		= tileset.imageheight
		local tw		= tileset.tilewidth
		local th		= tileset.tileheight
		local s			= tileset.spacing
		local m			= tileset.margin
		local w			= math.floor((iw - m - s) / (tw + s))
		local h			= math.floor((ih - m - s) / (th + s))
		tileset.lastgid	= tileset.firstgid + w * h - 1
		
		for y = 1, h do
			for x = 1, w do
				local qx = x * tw + m - tw
				local qy = y * th + m - th
				
				-- Spacing does not affect the first row/col
				if x > 1 then qx = qx + s end
				if y > 1 then qy = qy + s end
				
				self.map.quads[gid] = love.graphics.newQuad(qx, qy, tw, th, iw, ih)
				gid = gid + 1
			end
		end
	end
	
	-- Add images
	for i, tileset in ipairs(self.map.tilesets) do
		tileset.image = love.graphics.newImage(tileset.image)
	end
	
	-- Add tile structure, images
	for i, layer in ipairs(self.map.layers) do
		if layer.type == "tilelayer" then
			layer.data = self:setTileLayer(layer)
		end
		
		if layer.type == "imagelayer" then
			layer.image = love.graphics.newImage(layer.image)
		end
	end
	
	self.spriteBatches = {}
	for i, tileset in ipairs(self.map.tilesets) do
		local image = self.map.tilesets[i].image
		local w = tileset.imagewidth / tileset.tilewidth
		local h = tileset.imageheight / tileset.tileheight
		local size = w * h
		
		self.spriteBatches[i] = love.graphics.newSpriteBatch(image, size)
	end
end

function sti:update(dt)

end

function sti:draw()
	for i, layer in ipairs(self.map.layers) do
		if layer.type == "tilelayer" then
			self:drawTileLayer(1, layer)
		elseif layer.type == "objectgroup" then
			self:drawObjectLayer(i, layer)
		elseif layer.type == "imagelayer" then
			self:drawImageLayer(i, layer)
		else
			-- Invalid layer!
		end
	end
end

function sti:drawTileLayer(index, layer)
	if layer.visible then
		love.graphics.setColor(255, 255, 255, 255 * layer.opacity)
		
		for y,v in pairs(layer.data) do
			for x,tile in pairs(v) do
				if tile.gid ~= 0 then
					local ts = self.map.tilesets[tile.tileset]
					local tw = self.map.tilewidth
					local th = self.map.tileheight
					local tx = x * tw + ts.tileoffset.x - tw
					local ty = y * th + ts.tileoffset.y + (th - ts.tileheight) - th
					
					love.graphics.draw(ts.image, self.map.quads[tile.gid], tx, ty)
				end
			end
		end
		
		love.graphics.setColor(255, 255, 255, 255)
	end
	
end

function sti:drawObjectLayer(index, layer)
	if layer.visible then
		love.graphics.setColor(255, 255, 255, 255 * layer.opacity)
	
		love.graphics.setColor(255, 255, 255, 255)
	end
end

function sti:drawImageLayer(index, layer)
	if layer.visible then
		love.graphics.setColor(255, 255, 255, 255 * layer.opacity)
		love.graphics.draw(layer.image, 0, 0)
		love.graphics.setColor(255, 255, 255, 255)
	end
end

function sti:setTileLayer(layer)
	local i = 1
	local map = {}
	for y = 1, layer.height do
		map[y] = {}
		for x = 1, layer.width do
			local gid	= layer.data[i]
			local ts	= 0
			
			for k, tileset in ipairs(self.map.tilesets) do
				if gid >= tileset.firstgid and gid <= tileset.lastgid then
					ts = k
					break
				end
			end
			
			map[y][x] = {
				gid		= gid,
				tileset	= ts,
			}
			
			i = i + 1
		end
	end
	
	return map
end

return sti
