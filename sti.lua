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

-- Simple Tiled Implementation v0.6.6

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
	map.collision	= {}
	map.drawRange	= {
		ox = 1,
		oy = 1,
		ex = map.width,
		ey = map.height,
	}
	
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
				local qx = (x - 1) * tw + m
				local qy = (y - 1) * th + m
				
				-- Spacing does not affect the first row/col
				if x > 1 then qx = qx + s * x - s end
				if y > 1 then qy = qy + s * y - s end
				
				map.tiles[gid] = {
					gid		= gid,
					tileset	= i,
					quad	= love.graphics.newQuad(qx, qy, tw, th, iw, ih),
					sx		= 1,
					sy		= 1,
					r		= 0,
					offset	= {
						x = -map.tilewidth,
						y = -tileset.tileheight,
					},
				}
				
				if map.orientation == "isometric" then
					map.tiles[gid].offset.x = -map.tilewidth / 2
				end
			
				--[[ THIS IS A TEMPORARY FIX FOR 0.9.1 ]]--
				if tileset.tileoffset then
					map.tiles[gid].offset.x = map.tiles[gid].offset.x + tileset.tileoffset.x
					map.tiles[gid].offset.y = map.tiles[gid].offset.y + tileset.tileoffset.y
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
			layer.data = map:setTileLayerData(layer)
			layer.batches = map:setSpriteBatches(layer)
			layer.draw = function() map:drawTileLayer(layer) end
		elseif layer.type == "objectgroup" then
			layer.x = 0
			layer.y = 0
			layer.draw = function() map:drawObjectLayer(layer) end
		elseif layer.type == "imagelayer" then
			local image = STI.formatPath(path..layer.image)
			if layer.image ~= "" then
				layer.image = love.graphics.newImage(image)
			end
			
			layer.x = 0
			layer.y = 0
			layer.draw = function() map:drawImageLayer(layer) end
		end
		
		layer.update = function(dt) return end
		map.layers[layer.name] = layer
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

function Map:setTileLayerData(layer)
	local i = 1
	local map = {}
	
	for y = 1, layer.height do
		map[y] = {}
		for x = 1, layer.width do
			local gid = layer.data[i]
			local tile = self.tiles[gid]
			
			if tile then
				map[y][x] = tile
			else
				local _31 = bit.status(gid, 31)
				local _30 = bit.status(gid, 30)
				local _29 = bit.status(gid, 29)
				
				local realgid = bit.band(gid, bit.bnot(bit.bor(2^31, 2^30, 2^29)))
				
				local data = {}
				local tile = self.tiles[realgid]
				
				if tile then
					data.gid		= tile.gid
					data.tileset	= tile.tileset
					data.offset		= tile.offset
					data.quad		= tile.quad
					data.sx			= tile.sx
					data.sy			= tile.sy
					data.r			= tile.r
					
					if _31 then
						if _29 then
							data.r = math.rad(90)
						elseif _30 then
							data.sx = -1
							data.sy = -1
						else
							data.sx = -1
						end
					elseif _30 then
						if _29 then
							data.r = math.rad(-90)
						else
							data.sy = -1
						end
					end
					
					self.tiles[gid] = data
					map[y][x] = self.tiles[gid]
				end
			end
			
			i = i + 1
		end
	end
	
	return map
end

function Map:setSpriteBatches(layer)
	local w			= love.graphics.getWidth() / 2
	local h			= love.graphics.getHeight() / 2
	local tw		= self.tilewidth
	local th		= self.tileheight
	local bw		= math.ceil(w / tw)
	local bh		= math.ceil(h / th)
	local size		= bw * bh
	local batches	= {
		width = bw,
		height = bh,
	}
	
	for tileset, _ in ipairs(self.tilesets) do
		batches[tileset] = {}
	
		for y = 1, layer.height do
			local by = math.ceil(y / bh)
			batches[tileset][y] = {}
			
			for x = 1, layer.width do
				local tile	= layer.data[y][x]
				local bx	= math.ceil(x / bw)
				
				if tile and tile.tileset == tileset then
					local image = self.tilesets[tile.tileset].image
					
					if not batches[tile.tileset][by][bx] then
						batches[tile.tileset][by][bx] = love.graphics.newSpriteBatch(image, size)
					end
					
					local batch = batches[tile.tileset][by][bx]
					
					if self.orientation == "orthogonal" then
						local tx = x * tw + layer.x + tile.offset.x
						local ty = y * th + layer.y + tile.offset.y
						
						if tile.sx < 0 then tx = tx + tw end
						if tile.sy < 0 then ty = ty + th end
						if tile.r > 0 then tx = tx + tw end
						if tile.r < 0 then ty = ty + th end
						
						batch:add(tile.quad, tx, ty, tile.r, tile.sx, tile.sy)
					elseif self.orientation == "isometric" then
						local tx = (x - y) * (tw / 2) + layer.x + tile.offset.x
						local ty = (x + y) * (th / 2) + layer.y + tile.offset.y
						
						batch:add(tile.quad, tx, ty, tile.r, tile.sx, tile.sy)
					elseif self.orientation =="staggered" then
						local tx, ty
						if y % 2 == 0 then
							tx = (x * tw) + (tw / 2) + layer.x + tile.offset.x
							ty = y * th / 2 + layer.y + tile.offset.y
						else
							tx = x * tw + layer.x + tile.offset.x
							ty = y * th / 2 + layer.y + tile.offset.y
						end
						
						batch:add(tile.quad, tx, ty, tile.r, tile.sx, tile.sy)
					end
				end
			end
		end
	end
	
	return batches
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
	local layer = self.layers[index]
	
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

function Map:update(dt)
	for _, layer in ipairs(self.layers) do
		layer:update(dt)
	end
end

function Map:setDrawRange(tx, ty, w, h)
	tx = -tx
	ty = -ty
	local tw = self.tilewidth
	local th = self.tileheight
	local ox, oy, ex, ey
	
	if self.orientation == "orthogonal" then
		ox = math.ceil(tx / tw)
		oy = math.ceil(ty / th)
		ex = math.ceil(ox + w / tw)
		ey = math.ceil(oy + h / th)
	elseif self.orientation == "isometric" then
		ox = math.ceil(((ty / (th / 2)) + (tx / (tw / 2))) / 2)
		oy = math.ceil(((ty / (th / 2)) - (tx / (tw / 2))) / 2 - h / th)
		ex = math.ceil(ox + (h / th) + (w / tw))
		ey = math.ceil(oy + (h / th) * 2 + (w / tw))
	elseif self.orientation == "staggered" then
		ox = math.ceil(tx / tw - 1)
		oy = math.ceil(ty / th)
		ex = math.ceil(ox + w / tw + 1)
		ey = math.ceil(oy + h / th * 2)
	end
	
	self.drawRange = {
		ox = ox,
		oy = oy,
		ex = ex,
		ey = ey,
	}
end

function Map:draw()
	for _, layer in ipairs(self.layers) do
		if layer.visible then
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
	local bw = layer.batches.width
	local bh = layer.batches.height
	local ox = math.ceil(self.drawRange.ox / bw)
	local oy = math.ceil(self.drawRange.oy / bh)
	local ex = math.ceil(self.drawRange.ex / bw)
	local ey = math.ceil(self.drawRange.ey / bh)
	local mx = math.ceil(self.width / bw)
	local my = math.ceil(self.height / bh)
	
	for by=oy, ey do
		for bx=ox, ex do
			if bx >= 1 and bx <= mx and by >= 1 and by <= my then
				for _, batches in ipairs(layer.batches) do
					local batch = batches[by][bx]
					
					if batch then
						love.graphics.draw(batch)
					end
				end
			end
		end
	end
end

function Map:drawObjectLayer(layer)
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
			local function drawEllipse(mode, x, y, w, h, color)
				love.graphics.push()
				love.graphics.translate(x + w/2, y + h/2)
				love.graphics.scale(w/2, h/2)
				love.graphics.setColor(color)
				love.graphics.circle(mode, 0, 0, 1, 100)
				love.graphics.pop()
			end
			
			local function drawEllipseOutline(x, y, rx, ry, color)
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
			
			drawEllipse("fill", x, y, object.width, object.height, fill)
			drawEllipseOutline(x+1, y+1, object.width, object.height, shadow)
			drawEllipseOutline(x, y, object.width, object.height, line)
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
	if layer.image ~= "" then
		love.graphics.draw(layer.image, layer.x, layer.y)
	end
end

function Map:createCollisionMap(index)
	local layer	= self.layers[index]
	
	if layer.type ~= "tilelayer" then return end
	
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
