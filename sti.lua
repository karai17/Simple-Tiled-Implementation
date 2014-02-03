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

-- Simple Tiled Implementation v0.6.14

local bit = require "bit"
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
	map.drawRange	= {
		sx = 1,
		sy = 1,
		ex = map.width,
		ey = map.height,
	}
	
	-- Set tiles, images
	local gid = 1
	for i, tileset in ipairs(map.tilesets) do
		local image = STI.formatPath(path..tileset.image)
		tileset.image = love.graphics.newImage(image)
		tileset.image:setFilter("nearest", "nearest")
		gid = map:setTiles(i, tileset, gid)
	end
	
	-- Set layers
	for i, layer in ipairs(map.layers) do
		map:setLayer(layer, path)
	end
	
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

function Map:setTiles(index, tileset, gid)
	local quad	= love.graphics.newQuad
	local mw	= self.tilewidth
	local iw	= tileset.imagewidth
	local ih	= tileset.imageheight
	local tw	= tileset.tilewidth
	local th	= tileset.tileheight
	local s		= tileset.spacing
	local m		= tileset.margin
	local w		= math.floor((iw - m) / (tw + s))
	local h		= math.floor((ih - m) / (th + s))
	
	for y = 1, h do
		for x = 1, w do
			local qx = (x - 1) * tw + m + (x - 1) * s
			local qy = (y - 1) * th + m + (y - 1) * s
			local properties
			
			for _, tile in pairs(tileset.tiles) do
				if tile.id == gid - tileset.firstgid + 1 then
					properties = tile.properties
				end
			end
			
			local tile = {
				gid			= gid,
				tileset		= index,
				quad		= quad(qx, qy, tw, th, iw, ih),
				properties	= properties,
				sx			= 1,
				sy			= 1,
				r			= 0,
				offset		= {
					x = -mw,
					y = -th,
				},
			}
			
			if self.orientation == "isometric" then
				tile.offset.x = -mw / 2
			end
		
			--[[ THIS IS A TEMPORARY FIX FOR 0.9.1 ]]--
			if tileset.tileoffset then
				tile.offset.x = tile.offset.x + tileset.tileoffset.x
				tile.offset.y = tile.offset.y + tileset.tileoffset.y
			end
			
			self.tiles[gid] = tile
			gid = gid + 1
		end
	end
	
	return gid
end

function Map:setLayer(layer, path)
	layer.x = layer.x or 0
	layer.y = layer.y or 0
	layer.update = function(dt) return end
	
	if layer.type == "tilelayer" then
		self:setTileData(layer)
		self:setSpriteBatches(layer)
		layer.draw = function() self:drawTileLayer(layer) end
	elseif layer.type == "objectgroup" then
		layer.draw = function() self:drawObjectLayer(layer) end
	elseif layer.type == "imagelayer" then
		layer.draw = function() self:drawImageLayer(layer) end
		
		local image = STI.formatPath(path..layer.image)
		if layer.image ~= "" then
			layer.image = love.graphics.newImage(image)
		end
	end
	
	self.layers[layer.name] = layer
end

function Map:setTileData(layer)
	local i = 1
	local map = {}
	
	for y = 1, layer.height do
		map[y] = {}
		for x = 1, layer.width do
			local gid = layer.data[i]
			
			if gid > 0 then
				local tile = self.tiles[gid]
				
				if tile then
					map[y][x] = tile
				else
					local flipX		= bit.status(gid, 31)
					local flipY		= bit.status(gid, 30)
					local flipD		= bit.status(gid, 29)
					local realgid	= bit.band(gid, bit.bnot(bit.bor(2^31, 2^30, 2^29)))
					local tile = self.tiles[realgid]
					local data = {
						gid			= tile.gid,
						tileset		= tile.tileset,
						offset		= tile.offset,
						quad		= tile.quad,
						properties	= tile.properties,
						sx			= tile.sx,
						sy			= tile.sy,
						r			= tile.r,
					}
					
					if flipX then
						if flipY then
							data.sx = -1
							data.sy = -1
						elseif flipD then
							data.r = math.rad(90)
						else
							data.sx = -1
						end
					elseif flipY then
						if flipD then
							data.r = math.rad(-90)
						else
							data.sy = -1
						end
					elseif flipD then
						data.r = math.rad(90)
						data.sy = -1
					end
					
					self.tiles[gid] = data
					map[y][x] = self.tiles[gid]
				end
			end
			
			i = i + 1
		end
	end
	
	layer.data = map
end

function Map:setSpriteBatches(layer)
	local newBatch	= love.graphics.newSpriteBatch
	local w			= love.graphics.getWidth()
	local h			= love.graphics.getHeight()
	local tw		= self.tilewidth
	local th		= self.tileheight
	local bw		= math.ceil(w / tw)
	local bh		= math.ceil(h / th)
	
	-- Minimum of 400 tiles per batch
	if bw < 20 then bw = 20 end
	if bh < 20 then bh = 20 end
	
	local size		= bw * bh
	local batches	= {
		width	= bw,
		height	= bh,
		data	= {},
	}
	
	for y = 1, layer.height do
		local by = math.ceil(y / bh)
		
		for x = 1, layer.width do
			local tile	= layer.data[y][x]
			local bx	= math.ceil(x / bw)
			
			if tile then
				local ts = tile.tileset
				local image = self.tilesets[tile.tileset].image
				
				batches.data[ts] = batches.data[ts] or {}
				batches.data[ts][by] = batches.data[ts][by] or {}
				batches.data[ts][by][bx] = batches.data[ts][by][bx] or newBatch(image, size)
				
				local batch = batches.data[ts][by][bx]
				local tx, ty
				
				if self.orientation == "orthogonal" then
					tx = x * tw + tile.offset.x
					ty = y * th + tile.offset.y
					
					-- Compensation for scale/rotation shift
					if tile.sx	< 0 then tx = tx + tw end
					if tile.sy	< 0 then ty = ty + th end
					if tile.r	> 0 then tx = tx + tw end
					if tile.r	< 0 then ty = ty + th end
				elseif self.orientation == "isometric" then
					tx = (x - y) * (tw / 2) + tile.offset.x
					ty = (x + y) * (th / 2) + tile.offset.y
				elseif self.orientation == "staggered" then
					if y % 2 == 0 then
						tx = x * tw + tw / 2 + tile.offset.x
					else
						tx = x * tw + tile.offset.x
					end
					
					ty = y * th / 2 + tile.offset.y
				end
				
				batch:add(tile.quad, tx, ty, tile.r, tile.sx, tile.sy)
			end
		end
	end
	
	layer.batches = batches
end

function Map:setDrawRange(tx, ty, w, h)
	tx = -tx
	ty = -ty
	local tw = self.tilewidth
	local th = self.tileheight
	local sx, sy, ex, ey
	
	if self.orientation == "orthogonal" then
		sx = math.ceil(tx / tw)
		sy = math.ceil(ty / th)
		ex = math.ceil(sx + w / tw)
		ey = math.ceil(sy + h / th)
	elseif self.orientation == "isometric" then
		sx = math.ceil(((ty / (th / 2)) + (tx / (tw / 2))) / 2)
		sy = math.ceil(((ty / (th / 2)) - (tx / (tw / 2))) / 2 - h / th)
		ex = math.ceil(sx + (h / th) + (w / tw))
		ey = math.ceil(sy + (h / th) * 2 + (w / tw))
	elseif self.orientation == "staggered" then
		sx = math.ceil(tx / tw - 1)
		sy = math.ceil(ty / th)
		ex = math.ceil(sx + w / tw + 1)
		ey = math.ceil(sy + h / th * 2)
	end
	
	self.drawRange = {
		sx = sx,
		sy = sy,
		ex = ex,
		ey = ey,
	}
end

function Map:getCollisionMap(index)
	local layer	= assert(self.layers[index], "Layer not found: " .. index)
	
	assert(layer.type == "tilelayer", "Invalid layer type: " .. layer.type .. ". Layer must be of type: tilelayer")
	
	local w		= self.width
	local h		= self.height
	local map	= {
		type		= layer.type,
		orientation	= layer.orientation,
		collision	= true,
		opacity		= 0.5,
		data		= {},
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
	
	return map
end

function Map:addCustomLayer(name, index)
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

function Map:convertToCustomLayer(index)
	local layer = assert(self.layers[index], "Layer not found: " .. index)
	
	layer.type		= "customlayer"
	layer.x			= nil
	layer.y			= nil
	layer.width		= nil
	layer.height	= nil
	layer.encoding	= nil
	layer.data		= nil
	layer.objects	= nil
	layer.image		= nil
	
	function layer:draw() return end
	function layer:update(dt) return end
end

function Map:removeLayer(index)
	local layer = assert(self.layers[index], "Layer not found: " .. index)
	
	if type(index) == "string" then
		for i, layer in ipairs(self.layers) do
			if layer.name == index then
				table.remove(self.layers, i)
				table.remove(self.layers, index)
				break
			end
		end
	else
		local name = self.layers[index].name
		table.remove(self.layers, index)
		table.remove(self.layers, name)
	end
end

function Map:update(dt)
	for _, layer in ipairs(self.layers) do
		layer:update(dt)
	end
end

function Map:draw()
	for _, layer in ipairs(self.layers) do
		if layer.visible and layer.opacity > 0 then
			self:drawLayer(layer)
		end
	end
end

function Map:drawLayer(layer)
	love.graphics.setColor(255, 255, 255, 255 * layer.opacity)
	layer:draw()
	love.graphics.setColor(255, 255, 255, 255)
end

function Map:drawTileLayer(layer)
	assert(layer.type == "tilelayer", "Invalid layer type: " .. layer.type .. ". Layer must be of type: tilelayer")
	
	local bw = layer.batches.width
	local bh = layer.batches.height
	local sx = math.ceil((self.drawRange.sx - layer.x / self.tilewidth	- 1) / bw)
	local sy = math.ceil((self.drawRange.sy - layer.y / self.tileheight	- 1) / bh)
	local ex = math.ceil((self.drawRange.ex - layer.x / self.tilewidth	+ 1) / bw)
	local ey = math.ceil((self.drawRange.ey - layer.y / self.tileheight	+ 1) / bh)
	local mx = math.ceil(self.width / bw)
	local my = math.ceil(self.height / bh)
	
	for by=sy, ey do
		for bx=sx, ex do
			if bx >= 1 and bx <= mx and by >= 1 and by <= my then
				for _, batches in pairs(layer.batches.data) do
					local batch = batches[by] and batches[by][bx]
					
					if batch then
						love.graphics.draw(batch, math.floor(layer.x), math.floor(layer.y))
					end
				end
			end
		end
	end
end

function Map:drawObjectLayer(layer)
	assert(layer.type == "objectgroup", "Invalid layer type: " .. layer.type .. ". Layer must be of type: objectgroup")
	
	local line		= { 160, 160, 160, 255 * layer.opacity }
	local fill		= { 160, 160, 160, 255 * layer.opacity * 0.2 }
	local shadow	= { 0, 0, 0, 255 * layer.opacity }
	
	for _, object in ipairs(layer.objects) do
		local x = layer.x + object.x
		local y = layer.y + object.y
		
		if object.shape == "rectangle" then
			love.graphics.setColor(fill)
			love.graphics.rectangle("fill", x, y, object.width, object.height)
			
			love.graphics.setColor(shadow)
			love.graphics.rectangle("line", x+1, y+1, object.width, object.height)
			
			love.graphics.setColor(line)
			love.graphics.rectangle("line", x, y, object.width, object.height)
		elseif object.shape == "ellipse" then
			self:drawEllipse("fill", x, y, object.width, object.height, fill)
			self:drawEllipseOutline(x+1, y+1, object.width, object.height, shadow)
			self:drawEllipseOutline(x, y, object.width, object.height, line)
		elseif object.shape == "polygon" then
			local points = {{},{}}
			
			for _, point in ipairs(object.polygon) do
				table.insert(points[1], x + point.x)
				table.insert(points[1], y + point.y)
				table.insert(points[2], x + point.x+1)
				table.insert(points[2], y + point.y+1)
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
				table.insert(points[1], x + point.x)
				table.insert(points[1], y + point.y)
				table.insert(points[2], x + point.x+1)
				table.insert(points[2], y + point.y+1)
			end
			
			love.graphics.setColor(shadow)
			love.graphics.line(points[2])
			
			love.graphics.setColor(line)
			love.graphics.line(points[1])
		end
	end
end

function Map:drawImageLayer(layer)
	assert(layer.type == "imagelayer", "Invalid layer type: " .. layer.type .. ". Layer must be of type: imagelayer")
	
	if layer.image ~= "" then
		love.graphics.draw(layer.image, layer.x, layer.y)
	end
end

function Map:drawCollisionMap(layer)
	assert(layer.type == "tilelayer", "Invalid layer type: " .. layer.type .. ". Layer must be of type: tilelayer")
	assert(layer.collision, "This is not a collision layer")
	
	local tw = self.tilewidth
	local th = self.tileheight
	
	love.graphics.setColor(255, 255, 255, 255 * layer.opacity)
	
	for y=1, self.height do
		for x=1, self.width do
			local tx, ty
			
			if self.orientation == "orthogonal" then
				tx = (x - 1) * tw
				ty = (y - 1) * th
			elseif self.orientation == "isometric" then
				tx = (x - y) * (tw / 2) - self.tilewidth / 2
				ty = (x + y) * (th / 2) - self.tileheight
			elseif self.orientation == "staggered" then
				if y % 2 == 0 then
					tx = x * tw + tw / 2 - self.tilewidth
				else
					tx = x * tw - self.tilewidth
				end
				
				ty = y * th / 2 - self.tileheight
			end
			
			
			if layer.data[y][x] == 1 then
				love.graphics.rectangle("fill", tx, ty, tw, th)
			else
				love.graphics.rectangle("line", tx, ty, tw, th)
			end
		end
	end
	
	love.graphics.setColor(255, 255, 255, 255)
end

function Map:drawEllipse(mode, x, y, w, h, color)
	local segments = 100
	
	love.graphics.push()
	love.graphics.translate(x + w/2, y + h/2)
	love.graphics.scale(w/2, h/2)
	love.graphics.setColor(color)
	love.graphics.circle(mode, 0, 0, 1, segments)
	love.graphics.pop()
end

function Map:drawEllipseOutline(x, y, rx, ry, color)
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

function bit.status(num, digit)
	return bit.band(num, bit.lshift(1, digit)) ~= 0
end

return STI
