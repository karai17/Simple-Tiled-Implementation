local Map = {}
local framework

function Map:init(path, fw)
	framework = fw
	
	-- Set tiles, images
	local gid = 1
	for i, tileset in ipairs(self.tilesets) do
		local image = self.formatPath(path .. tileset.image)
		tileset.image = framework.newImage(image)
		gid = self:setTiles(i, tileset, gid)
	end
	
	-- Set layers
	for i, layer in ipairs(self.layers) do
		self:setLayer(layer, path)
	end
end

function Map.formatPath(path)
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
	local function getTiles(i, t, m, s)
		i = i - m
		local n = 0
		
		while i >= t do
			i = i - t
			if n ~= 0 then i = i - s end
			if i >= 0 then n = n + 1 end
		end
		
		return n
	end
	
	local quad	= framework.newQuad
	local mw	= self.tilewidth
	local iw	= tileset.imagewidth
	local ih	= tileset.imageheight
	local tw	= tileset.tilewidth
	local th	= tileset.tileheight
	local s		= tileset.spacing
	local m		= tileset.margin
	local w		= getTiles(iw, tw, m, s)
	local h		= getTiles(ih, th, m, s)
	
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
		
		if layer.image ~= "" then
			local image = self.formatPath(path..layer.image)
			layer.image = framework.newImage(image)
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
					local bit31	= 2147483648
					local bit30	= 1073741824
					local bit29	= 536870912
					local flipX		= false
					local flipY		= false
					local flipD		= false
					local realgid	= gid
					
					if realgid >= bit31 then
						realgid = realgid - bit31
						flipX = not flipX
					end
					
					if realgid >= bit30 then
						realgid = realgid - bit30
						flipY = not flipY
					end
					
					if realgid >= bit29 then
						realgid = realgid - bit29
						flipD = not flipD
					end
					
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
	local newBatch	= framework.newSpriteBatch
	local w			= framework.getWidth()
	local h			= framework.getHeight()
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

function Map:draw(sx, sy)
	framework.setCanvas(self.canvas)
	framework.clear(self.canvas)
	
	for _, layer in ipairs(self.layers) do
		if layer.visible and layer.opacity > 0 then
			self:drawLayer(layer)
		end
	end
	
	framework.setCanvas()
	
	framework.push()
	framework.origin()
	framework.draw(self.canvas, 0, 0, 0, sx, sy)
	framework.pop()
end

function Map:drawLayer(layer)
	framework.setColor(255, 255, 255, 255 * layer.opacity)
	layer:draw()
	framework.setColor(255, 255, 255, 255)
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
						framework.draw(batch, math.floor(layer.x), math.floor(layer.y))
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
	
	local function drawEllipse(mode, x, y, rx, ry)
		local segments = 100
		local vertices = {}
		
		table.insert(vertices, x + rx / 2)
		table.insert(vertices, y + ry / 2)
		
		for i=0, segments do
			local angle = (i / segments) * math.pi * 2
			local px = x + rx / 2 + math.cos(angle) * rx / 2
			local py = y + ry / 2 + math.sin(angle) * ry / 2
			
			table.insert(vertices, px)
			table.insert(vertices, py)
		end
		
		framework.polygon(mode, vertices)
	end
	
	for _, object in ipairs(layer.objects) do
		local x = layer.x + object.x
		local y = layer.y + object.y
		
		if object.shape == "rectangle" then
			framework.setColor(fill)
			framework.rectangle("fill", x, y, object.width, object.height)
			
			framework.setColor(shadow)
			framework.rectangle("line", x+1, y+1, object.width, object.height)
			
			framework.setColor(line)
			framework.rectangle("line", x, y, object.width, object.height)
		elseif object.shape == "ellipse" then
			framework.setColor(fill)
			drawEllipse("fill", x, y, object.width, object.height)
			
			framework.setColor(shadow)
			drawEllipse("line", x+1, y+1, object.width, object.height)
			
			framework.setColor(line)
			drawEllipse("line", x, y, object.width, object.height)
		elseif object.shape == "polygon" then
			local points = {{},{}}
			
			for _, point in ipairs(object.polygon) do
				table.insert(points[1], x + point.x)
				table.insert(points[1], y + point.y)
				table.insert(points[2], x + point.x+1)
				table.insert(points[2], y + point.y+1)
			end
			
			framework.setColor(fill)
			if not framework.isConvex(points[1]) then
				local triangles = framework.triangulate(points[1])
				for _, triangle in ipairs(triangles) do
					framework.polygon("fill", triangle)
				end
			else
				framework.polygon("fill", points[1])
			end
			
			framework.setColor(shadow)
			framework.polygon("line", points[2])
			
			framework.setColor(line)
			framework.polygon("line", points[1])
		elseif object.shape == "polyline" then
			local points = {{},{}}
			
			for _, point in ipairs(object.polyline) do
				table.insert(points[1], x + point.x)
				table.insert(points[1], y + point.y)
				table.insert(points[2], x + point.x+1)
				table.insert(points[2], y + point.y+1)
			end
			
			framework.setColor(shadow)
			framework.line(points[2])
			
			framework.setColor(line)
			framework.line(points[1])
		end
	end
end

function Map:drawImageLayer(layer)
	assert(layer.type == "imagelayer", "Invalid layer type: " .. layer.type .. ". Layer must be of type: imagelayer")
	
	if layer.image ~= "" then
		framework.draw(layer.image, layer.x, layer.y)
	end
end

function Map:drawCollisionMap(layer)
	assert(layer.type == "tilelayer", "Invalid layer type: " .. layer.type .. ". Layer must be of type: tilelayer")
	assert(layer.collision, "This is not a collision layer")
	
	local tw = self.tilewidth
	local th = self.tileheight
	
	framework.setColor(255, 255, 255, 255 * layer.opacity)
	
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
				framework.rectangle("fill", tx, ty, tw, th)
			else
				framework.rectangle("line", tx, ty, tw, th)
			end
		end
	end
	
	framework.setColor(255, 255, 255, 255)
end

function Map:resize(w, h)
	self.canvas = framework.newCanvas(w, h)
end

return Map
