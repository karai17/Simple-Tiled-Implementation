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

-- Simple Tiled Implementation v0.4.1

local STI = {}
local Map = {}

function STI.new(map)
	map = map .. ".lua"
	
	-- Get path to map
	local path = map:reverse():find("[/\\]") or ""
	if path ~= "" then
		path = map:sub(1, 1 + (#map - path))
	end
	
	-- Load map
	map = assert(love.filesystem.load(map), "File not found: " .. map)
	setfenv(map, {})
	map = setmetatable(map(), {__index = Map})
	
	map.tiles		= {}
	map.collision	= {}
	
	-- Create array of quads
	local gid = 1
	for i, tileset in ipairs(map.tilesets) do
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
				
				map.tiles[gid] = {
					gid		= gid,
					tileset	= tileset,
					quad	= love.graphics.newQuad(qx, qy, tw, th, iw, ih),
				}
				
				--[[ THIS IS A TEMPORARY FIX FOR 0.9.1 ]]--
				if tileset.tileoffset then
					map.tiles[gid].offset	= {
						x = tileset.tileoffset.x - map.tilewidth,
						y = tileset.tileoffset.y - tileset.tileheight,
					}
				else
					map.tiles[gid].offset	= {
						x = -map.tilewidth,
						y = -tileset.tileheight,
					}
				end
				
				gid = gid + 1
			end
		end
	end
	
	-- Add images
	for i, tileset in ipairs(map.tilesets) do
		local image = STI.formatPath(path..tileset.image)
		tileset.image = love.graphics.newImage(image)
	end
	
	-- Add tile structure, images
	for i, layer in ipairs(map.layers) do
		if layer.type == "tilelayer" then
			layer.data = map:createTileLayerData(layer)
			layer.draw = function() map:drawTileLayer(layer) end
		elseif layer.type == "objectgroup" then
			layer.draw = function() map:drawObjectLayer(layer) end
		elseif layer.type == "imagelayer" then
			local image = STI.formatPath(path..layer.image)
			if layer.image ~= "" then
				layer.image = love.graphics.newImage(image)
			end
			
			layer.draw = function() map:drawImageLayer(layer) end
		end
		
		layer.update = function(dt) map:updateLayer(dt) end
		map.layers[layer.name] = layer
	end
	
	--[[
	map.spriteBatches = {}
	for i, tileset in ipairs(map.tilesets) do
		local image = map.tilesets[i].image
		local w = tileset.imagewidth / tileset.tilewidth
		local h = tileset.imageheight / tileset.tileheight
		local size = w * h
		
		map.spriteBatches[i] = love.graphics.newSpriteBatch(image, size)
	end
	]]--
	
	return map
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
		layer:update(dt)
	end
end

function Map:updateLayer(dt)
	return
end

function Map:draw()
	for _, layer in ipairs(self.layers) do
		if layer.visible then
			layer:draw()
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
	local line		= { 160, 160, 160, 255 * layer.opacity }
	local fill		= { 160, 160, 160, 255 * layer.opacity * 0.2 }
	local shadow	= { 0, 0, 0, 255 * layer.opacity }
	
	for _, object in ipairs(layer.objects) do
		if object.shape == "rectangle" then
			love.graphics.setColor(fill)
			love.graphics.rectangle("fill", object.x, object.y, object.width, object.height)
			
			love.graphics.setColor(shadow)
			love.graphics.rectangle("line", object.x+1, object.y+1, object.width, object.height)
			
			love.graphics.setColor(line)
			love.graphics.rectangle("line", object.x, object.y, object.width, object.height)
		elseif object.shape == "ellipse" then
			local function drawEllipse(mode, x, y, w, h, color)
				love.graphics.push()
				love.graphics.translate(x + w/2, y + h/2)
				love.graphics.scale(w/2, h/2)
				love.graphics.setColor(color)
				love.graphics.circle(mode, 0, 0, 1, 100)
				love.graphics.pop()
			end
			
			local function drawLineEllipse(x, y, rx, ry, color)
				local segments = 100
				local vertices = {}
				
				for i=0, segments do
					local angle = (i / segments) * math.pi * 2
					
					local px = x + rx / 2 + math.cos(angle) * rx / 2
					local py = y + ry / 2 + math.sin(angle) * ry / 2
					
					vertices[#vertices+1] = px
					vertices[#vertices+1] = py
				end
				
				love.graphics.setColor(color)
				love.graphics.line(vertices)
			end
			
			drawEllipse("fill", object.x, object.y, object.width, object.height, fill)
			drawLineEllipse(object.x+1, object.y+1, object.width, object.height, shadow)
			drawLineEllipse(object.x, object.y, object.width, object.height, line)
		elseif object.shape == "polygon" then
			local points = {{},{}}
			
			for _, point in ipairs(object.polygon) do
				table.insert(points[1], object.x + point.x)
				table.insert(points[1], object.y + point.y)
				table.insert(points[2], object.x + point.x+1)
				table.insert(points[2], object.y + point.y+1)
			end
			
			love.graphics.setColor(fill)
			if not love.math.isConvex(points[1]) then
				local triangles = love.math.triangulate(points[1])
				for _, triangle in ipairs(triangles) do
					love.graphics.polygon("fill", triangle)
				end
			else
				love.graphics.polygon("fill", points[1])
			end
			
			love.graphics.setColor(shadow)
			love.graphics.polygon("line", points[2])
			
			love.graphics.setColor(line)
			love.graphics.polygon("line", points[1])
		elseif object.shape == "polyline" then
			local points = {{},{}}
			
			for _, point in ipairs(object.polyline) do
				table.insert(points[1], object.x + point.x)
				table.insert(points[1], object.y + point.y)
				table.insert(points[2], object.x + point.x+1)
				table.insert(points[2], object.y + point.y+1)
			end
			
			love.graphics.setColor(shadow)
			love.graphics.line(points[2])
			
			love.graphics.setColor(line)
			love.graphics.line(points[1])
		end
	end
	
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

function Map:newCustomLayer(name, index)
	local layer = {
      type = "customlayer",
      name = name,
      visible = true,
      opacity = 1,
      properties = {},
    }
	function layer:draw() return end
	function layer:update(dt) return end
	
	table.insert(self.layers, index, layer)
	self.layers[name] = self.layers[index]
end

function Map:removeLayer(index)
	if type(index) == "string" then
		for i, layer in ipairs(self.layers) do
			if layer.name == index then
				table.remove(self.layers, i)
				self.layers[index] = nil
				break
			end
		end
	else
		local name = self.layers[index].name
		table.remove(self.layers, index)
		self.layers[name] = nil
	end
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
