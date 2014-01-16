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

local STI = {}
local Map = {}

function STI.new(map)
	map = map .. ".lua"
	local ret = setmetatable({}, {__index = Map})
	
	-- Get path to map
	local path = map:reverse():find("[/\\]") or ""
	if path ~= "" then
		path = map:sub(1, 1 + (#map - path))
	end
	
	-- Load map
	map = assert(love.filesystem.load(map), "File not found: " .. map)
	setfenv(map, {})
	map = map()
	
	ret.version		= map.version
	ret.luaversion	= map.luaversion
	ret.orientation	= map.orientation
	ret.width		= map.width
	ret.height		= map.height
	ret.tilewidth	= map.tilewidth
	ret.tileheight	= map.tileheight
	ret.properties	= map.properties
	ret.tilesets	= map.tilesets
	ret.layers		= map.layers
	ret.tiles		= {}
	ret.collision	= {}
	
	-- Create array of quads
	local gid = 1
	for i, tileset in ipairs(ret.tilesets) do
		local iw		= tileset.imagewidth
		local ih		= tileset.imageheight
		local tw		= tileset.tilewidth
		local th		= tileset.tileheight
		local s			= tileset.spacing
		local m			= tileset.margin
		local w			= math.floor((iw - m - s) / (tw + s))
		local h			= math.floor((ih - m - s) / (th + s))
		
		for y = 1, h do
			for x = 1, w do
				local qx = x * tw + m - tw
				local qy = y * th + m - th
				
				-- Spacing does not affect the first row/col
				if x > 1 then qx = qx + s end
				if y > 1 then qy = qy + s end
				
				ret.tiles[gid] = {
					gid		= gid,
					tileset	= tileset,
					quad	= love.graphics.newQuad(qx, qy, tw, th, iw, ih),
				}
				
				--[[ THIS IS A TEMPORARY FIX FOR 0.9.1 ]]--
				if tileset.tileoffset then
					ret.tiles[gid].offset	= {
						x = tileset.tileoffset.x - ret.tilewidth,
						y = tileset.tileoffset.y - tileset.tileheight,
					}
				else
					ret.tiles[gid].offset	= {
						x = 0,
						y = 0,
					}
				end
				
				gid = gid + 1
			end
		end
	end
	
	-- Add images
	for i, tileset in ipairs(ret.tilesets) do
		local image = STI.formatPath(path..tileset.image)
		tileset.image = love.graphics.newImage(image)
	end
	
	-- Add tile structure, images
	for i, layer in ipairs(ret.layers) do
		ret.layers[layer.name] = layer
		
		if layer.type == "tilelayer" then
			layer.data = ret:createTileLayerData(layer)
		end
		
		if layer.type == "imagelayer" then
			local image = STI.formatPath(path..layer.image)
			if layer.image ~= "" then
				layer.image = love.graphics.newImage(image)
			end
		end
	end
	
	--[[
	ret.spriteBatches = {}
	for i, tileset in ipairs(ret.tilesets) do
		local image = ret.tilesets[i].image
		local w = tileset.imagewidth / tileset.tilewidth
		local h = tileset.imageheight / tileset.tileheight
		local size = w * h
		
		ret.spriteBatches[i] = love.graphics.newSpriteBatch(image, size)
	end
	]]--
	
	return ret
end

function STI.formatPath(path)
	local str = string.split(path, "/")
	
	for i, segment in pairs(str) do
		if segment == ".." then
			str[i]		= nil
			str[i-1]	= nil
		end
	end
	
	path = ""
	for _, segment in pairs(str) do
		path = path .. segment .. "/"
	end
	
	return string.sub(path, 1, path:len()-1)
end

function Map:update(dt)
	for _, layer in ipairs(self.layers) do
		if layer.type == "customlayer" then
			self:updateCustomLayer(dt, layer)
		end
	end
end

function Map:updateCustomLayer(dt, layer)
	layer:update(dt)
end

function Map:draw()
	for _, layer in ipairs(self.layers) do
		if layer.visible then
			if layer.type == "tilelayer" then
				self:drawTileLayer(layer)
			elseif layer.type == "objectgroup" then
				self:drawObjectLayer(layer)
			elseif layer.type == "imagelayer" then
				self:drawImageLayer(layer)
			elseif layer.type == "customlayer" then
				self:drawCustomLayer(layer)
			end
		end
	end
end

function Map:drawTileLayer(layer)
	local tw = self.tilewidth
	local th = self.tileheight
	
	love.graphics.setColor(255, 255, 255, 255 * layer.opacity)
	
	for y,tiles in pairs(layer.data) do
		for x,tile in pairs(tiles) do
			if tile.gid ~= 0 then
				local tx = x * tw + tile.offset.x
				local ty = y * th + tile.offset.y
				love.graphics.draw(tile.tileset.image, tile.quad, tx, ty)
			end
		end
	end
	
	love.graphics.setColor(255, 255, 255, 255)
end

function Map:drawObjectLayer(layer)
	love.graphics.setColor(255, 255, 255, 255 * layer.opacity)
	
	love.graphics.setColor(255, 255, 255, 255)
end

function Map:drawImageLayer(layer)
	if layer.image ~= "" then
		love.graphics.setColor(255, 255, 255, 255 * layer.opacity)
		love.graphics.draw(layer.image, 0, 0)
		love.graphics.setColor(255, 255, 255, 255)
	end
end

function Map:drawCustomLayer(layer)
	love.graphics.setColor(255, 255, 255, 255 * layer.opacity)
	layer:draw()
	love.graphics.setColor(255, 255, 255, 255)
end

function Map:drawCollisionMap()
	local tw = self.tilewidth
	local th = self.tileheight
	
	love.graphics.setColor(255, 255, 255, 255 * self.collision.opacity)
	
	for y=1, self.height do
		for x=1, self.width do
			local tx = x * tw - tw
			local ty = y * th - th
			if self.collision.data[y][x] == 1 then
				love.graphics.rectangle("fill", tx, ty, tw, th)
			else
				love.graphics.rectangle("line", tx, ty, tw, th)
			end
		end
	end
	
	love.graphics.setColor(255, 255, 255, 255)
end

function Map:createTileLayerData(layer)
	local i = 1
	local map = {}
	
	for y = 1, layer.height do
		map[y] = {}
		for x = 1, layer.width do
			map[y][x] = self.tiles[layer.data[i]]
			i = i + 1
		end
	end
	
	return map
end

function Map:createCollisionMap(name)
	local layer	= self.layers[name]
	
	if layer.type == "tilelayer" then
		local w		= self.width
		local h		= self.height
		local i		= 1
		local map	= {
			opacity	= 0.5,
			data	= {},
		}
		
		for y=1, h do
			map.data[y] = {}
			for x=1, w do
				if layer.data[y][x] == nil then
					map.data[y][x] = 0
				else
					map.data[y][x] = 1
				end
			end
		end

		self.collision = map
	end
end

function Map:convertToCustomLayer(name)
	local layer = self.layers[name]
	
	if layer.type == "tilelayer" then
		layer.x			= nil
		layer.y			= nil
		layer.width		= nil
		layer.height	= nil
		layer.encoding	= nil
		layer.data		= nil
	elseif layer.type == "objectgroup" then
		layer.objects	= nil
	elseif layer.type == "imagelayer" then
		layer.image		= nil
	else
		return -- invalid layer!
	end
	
	layer.type		= "customlayer"
	function layer:draw() return end
	function layer:update(dt) return end
end

-- http://wiki.interfaceware.com/534.html
function string.split(s, d)
	local t = {}
	local i = 0
	local f
	local match = '(.-)' .. d .. '()'
	
	if string.find(s, d) == nil then
		return {s}
	end
	
	for sub, j in string.gmatch(s, match) do
		i = i + 1
		t[i] = sub
		f = j
	end
	
	if i ~= 0 then
		t[i+1] = string.sub(s, f)
	end
	
	return t
end

return STI
