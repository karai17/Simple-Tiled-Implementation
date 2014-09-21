local Map = {}
local framework

function Map:init(path, fw)
	framework = fw

	self.canvas			= framework:newCanvas()
	self.tiles			= {}
	self.tileInstances	= {}
	self.drawRange		= {
		sx = 1,
		sy = 1,
		ex = self.width,
		ey = self.height,
	}

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

-- https://github.com/stevedonovan/Penlight/blob/master/lua/pl/path.lua#L286
function Map.formatPath(path)
	local np_gen1,np_gen2 = '[^SEP]+SEP%.%.SEP?','SEP+%.?SEP'
	local np_pat1, np_pat2

	if not np_pat1 then
		np_pat1 = np_gen1:gsub('SEP','/')
		np_pat2 = np_gen2:gsub('SEP','/')
	end
	local k
	repeat -- /./ -> /
		path,k = path:gsub(np_pat2,'/')
	until k == 0
	repeat -- A/../ -> (empty)
		path,k = path:gsub(np_pat1,'')
	until k == 0
	if path == '' then path = '.' end

	return path
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
				if tile.id == gid - tileset.firstgid then
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
					x = -mw + tileset.tileoffset.x,
					y = -th + tileset.tileoffset.y,
				},
			}

			if self.orientation == "isometric" then
				tile.offset.x = -mw / 2
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
		self:fixObjectLayersYPosition(layer)
		self:setObjectCoordinates(layer)
		self:setSpriteBatchesForObjectLayer(layer)
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


function Map:setObjectCoordinates(layer)
	for _, object in ipairs(layer.objects) do
		local x = layer.x + object.x
		local y = layer.y + object.y
		local w = object.width
		local h = object.height
		local r = object.rotation
		local cos = math.cos(math.rad(r))
		local sin = math.sin(math.rad(r))

		if object.shape == "rectangle" then
			object.rectangle = {}

			local vertices = {
				{ x=x,		y=y },
				{ x=x + w,	y=y },
				{ x=x + w,	y=y + h },
				{ x=x,		y=y + h },
			}

			for _, vertex in ipairs(vertices) do
				local bx, by = x, y

				if self.orientation == "isometric" then
					bx, by = self:convertIsometricToScreen(x, y)
					vertex.x, vertex.y = self:convertIsometricToScreen(vertex.x, vertex.y)
				end

				vertex.x, vertex.y = self:rotateVertex(vertex, bx, by, cos, sin)
				table.insert(object.rectangle, { x = vertex.x, y = vertex.y })
			end
		elseif object.shape == "ellipse" then
			object.ellipse = {}

			local vertices = self:convertEllipseToPolygon(x, y, w, h)

			for _, vertex in ipairs(vertices) do
				local bx, by = x, y

				if self.orientation == "isometric" then
					bx, by = self:convertIsometricToScreen(x, y)
					vertex.x, vertex.y = self:convertIsometricToScreen(vertex.x, vertex.y)
				end

				vertex.x, vertex.y = self:rotateVertex(vertex, bx, by, cos, sin)
				table.insert(object.ellipse, { x = vertex.x, y = vertex.y })
			end
		elseif object.shape == "polygon" then
			for _, vertex in ipairs(object.polygon) do
				vertex.x = x + vertex.x
				vertex.y = y + vertex.y
				local bx, by = x, y

				if self.orientation == "isometric" then
					bx, by = self:convertIsometricToScreen(x, y)
					vertex.x, vertex.y = self:convertIsometricToScreen(vertex.x, vertex.y)
				end

				vertex.x, vertex.y = self:rotateVertex(vertex, bx, by, cos, sin)
			end
		elseif object.shape == "polyline" then
			for _, vertex in ipairs(object.polyline) do
				vertex.x = x + vertex.x
				vertex.y = y + vertex.y
				local bx, by = x, y

				if self.orientation == "isometric" then
					bx, by = self:convertIsometricToScreen(x, y)
					vertex.x, vertex.y = self:convertIsometricToScreen(vertex.x, vertex.y)
				end

				vertex.x, vertex.y = self:rotateVertex(vertex, bx, by, cos, sin)
			end
		end
	end
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
					tx = (x - y) * (tw / 2) + tile.offset.x + layer.width * tw / 2
					ty = (x + y) * (th / 2) + tile.offset.y
				elseif self.orientation == "staggered" then
					if y % 2 == 0 then
						tx = x * tw + tw / 2 + tile.offset.x
					else
						tx = x * tw + tile.offset.x
					end

					ty = y * th / 2 + tile.offset.y + th / 2
				end

				batch:add(tile.quad, tx, ty, tile.r, tile.sx, tile.sy)

				self.tileInstances[tile.gid] = self.tileInstances[tile.gid] or {}
				table.insert(self.tileInstances[tile.gid], { x=tx, y=ty })

			end
		end
	end

	layer.batches = batches
end


function Map:setSpriteBatchesForObjectLayer(layer)
	if type(layer) == "string" or type(layer) == "number" then
		layer = self.layers[layer]
	end

	assert(layer.type == "objectgroup", "Invalid layer type: " .. layer.type .. ". Layer must be of type: objectgroup")

	local batches = {}

	local iobjects = {} -- count of objects that will be in one batch
	for _, object in ipairs(layer.objects) do
			if object.gid then

				local tile = self.tiles[object.gid]
				local ts = tile.tileset
				local image = self.tilesets[ts].image

				-- count per tileset
				iobjects[ts] = iobjects[ts] or 0
				iobjects[ts] = iobjects[ts] + 1

				-- it the count get over 1000 create a new batch
				local bi = math.ceil(iobjects[ts] / 1000)

				-- lookup if the batch exits or create a new one
				batches[ts] = batches[tile.tileset] or {}
			  batches[ts][bi] = batches[ts][bi] or framework.newSpriteBatch(image, 1000)

				-- add the quad
				local batch = batches[ts][bi]
				batch:add(tile.quad, object.x, object.y)

				-- only use built-in collision system when told so
				if layer.properties.isSolid then
						self.tileInstances[tile.gid] = self.tileInstances[tile.gid] or {}
						table.insert(self.tileInstances[tile.gid], { x=object.x, y=object.y })
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
				break
			end
		end
	elseif self.layers[index] then
		table.remove(self.layers, index)
	end
	
	-- if it was a tilelayer whe have to build all collision entries again
	if layer.type == "tilelayer" then
		self.tileInstances	= {}
		for _, lyr in ipairs(self.layers) do
			if lyr.type == "tilelayer" then
				Map:setSpriteBatches(lyr)
			end
		end
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
	if type(layer) == "string" or type(layer) == "number" then
		layer = self.layers[layer]
	end

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
	if type(layer) == "string" or type(layer) == "number" then
		layer = self.layers[layer]
	end

	assert(layer.type == "objectgroup", "Invalid layer type: " .. layer.type .. ". Layer must be of type: objectgroup")

	local line		= { 160, 160, 160, 255 * layer.opacity }
	local fill		= { 160, 160, 160, 255 * layer.opacity * 0.2 }
	local shadow	= { 0, 0, 0, 255 * layer.opacity }

	local function drawEllipse(mode, x, y, w, h)
		local segments = 100
		local vertices = {}

		table.insert(vertices, x + w / 2)
		table.insert(vertices, y + h / 2)

		for i=0, segments do
			local angle = (i / segments) * math.pi * 2
			local px = x + w / 2 + math.cos(angle) * w / 2
			local py = y + h / 2 + math.sin(angle) * h / 2

			table.insert(vertices, px)
			table.insert(vertices, py)
		end

		framework.polygon(mode, vertices)
	end

	for _, object in ipairs(layer.objects) do
		local x = layer.x + object.x
		local y = layer.y + object.y
		local w = object.width
		local h = object.height
		local r = object.rotation

		if object.gid then
			-- do nothing
		elseif object.shape == "rectangle" then
			local vertices = {{},{}}

			for _, vertex in ipairs(object.rectangle) do
				table.insert(vertices[1], vertex.x)
				table.insert(vertices[1], vertex.y)
				table.insert(vertices[2], vertex.x+1)
				table.insert(vertices[2], vertex.y+1)
			end

			framework.setColor(fill)
			framework.polygon("fill", vertices[1])

			framework.setColor(shadow)
			framework.polygon("line", vertices[2])

			framework.setColor(line)
			framework.polygon("line", vertices[1])
		elseif object.shape == "ellipse" then
			local vertices = {{},{}}

			for _, vertex in ipairs(object.ellipse) do
				table.insert(vertices[1], vertex.x)
				table.insert(vertices[1], vertex.y)
				table.insert(vertices[2], vertex.x+1)
				table.insert(vertices[2], vertex.y+1)
			end

			framework.setColor(fill)
			framework.polygon("fill", vertices[1])

			framework.setColor(shadow)
			framework.polygon("line", vertices[2])

			framework.setColor(line)
			framework.polygon("line", vertices[1])
		elseif object.shape == "polygon" then
			local vertices = {{},{}}

			for _, vertex in ipairs(object.polygon) do
				table.insert(vertices[1], vertex.x)
				table.insert(vertices[1], vertex.y)
				table.insert(vertices[2], vertex.x+1)
				table.insert(vertices[2], vertex.y+1)
			end

			framework.setColor(fill)
			if not framework.isConvex(vertices[1]) then
				local triangles = framework.triangulate(vertices[1])
				for _, triangle in ipairs(triangles) do
					framework.polygon("fill", triangle)
				end
			else
				framework.polygon("fill", vertices[1])
			end

			framework.setColor(shadow)
			framework.polygon("line", vertices[2])

			framework.setColor(line)
			framework.polygon("line", vertices[1])
		elseif object.shape == "polyline" then
			local vertices = {{},{}}

			for _, vertex in ipairs(object.polyline) do
				table.insert(vertices[1], vertex.x)
				table.insert(vertices[1], vertex.y)
				table.insert(vertices[2], vertex.x+1)
				table.insert(vertices[2], vertex.y+1)
			end

			framework.setColor(shadow)
			framework.line(vertices[2])

			framework.setColor(line)
			framework.line(vertices[1])
		end
	end

	-- draw the batches with the objects that are tile based
	-- layer.batches[tileset][batchindex] = batch
	for _, batches in ipairs(layer.batches) do
		for _, batch in ipairs(batches) do
			framework.draw(batch, layer.x, layer.y)
		end
	end
end

function Map:drawImageLayer(layer)
	if type(layer) == "string" or type(layer) == "number" then
		layer = self.layers[layer]
	end

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
	self.canvas = framework:newCanvas(w, h)
end

function Map:convertIsometricToScreen(x, y)
	local mw = self.width
	local mh = self.height
	local tw = self.tilewidth
	local th = self.tileheight

	local vx = (x - y) + mw * tw / 2
	local vy = (y + x) / 2

	return vx, vy
end

function Map:convertScreenToIsometric(x, y)
	local mw = self.width
	local mh = self.height
	local tw = self.tilewidth
	local th = self.tileheight

	local vx = (x / 2 + y) - mw * tw / 4
	local vy = -x / 2 + y + mh * th / 2

	return vx, vy
end

function Map:rotateVertex(v, x, y, cos, sin)
	local vertex = {
		x = v.x,
		y = v.y,
	}

	vertex.x = vertex.x - x
	vertex.y = vertex.y - y

	local vx = cos * vertex.x - sin * vertex.y
	local vy = sin * vertex.x + cos * vertex.y

	return vx + x, vy + y
end

function Map:enableCollision(world)
	local body = love.physics.newBody(world)
	local collision = {
		body = body,
	}

	for _, tileset in ipairs(self.tilesets) do
		for _, tile in ipairs(tileset.tiles) do
			if tile.objectGroup then
				local gid = tileset.firstgid + tile.id
				if self.tileInstances[gid] then -- check if the tile has instances
					for _, instance in ipairs(self.tileInstances[gid]) do
						for _, object in ipairs(tile.objectGroup.objects) do
							local x = object.x
							local y = object.y
							local w = object.width
							local h = object.height

							if object.shape == "rectangle" then
								local vertices = {
									instance.x + x,		instance.y + y,
									instance.x + x + w,	instance.y + y,
									instance.x + x + w,	instance.y + y + h,
									instance.x + x,		instance.y + y + h,
								}

								local shape = love.physics.newPolygonShape(unpack(vertices))
								local fixture = love.physics.newFixture(body, shape)
								local obj = {
									shape = shape,
									fixture = fixture,
								}

								table.insert(collision, obj)

							elseif object.shape == "ellipse" then
								local vertices = self:convertEllipseToPolygon(object.x, object.y, object.width, object.height, 25)
								local polygon = {}
								for _, vertex in ipairs(vertices) do
									table.insert(polygon, instance.x + vertex.x + x)
									table.insert(polygon, instance.y + vertex.y + y)
								end

								local triangles = love.math.triangulate(polygon)

								for _, triangle in ipairs(triangles) do
									local shape = love.physics.newPolygonShape(unpack(triangle))
									local fixture = love.physics.newFixture(body, shape)
									local obj = {
										shape = shape,
										fixture = fixture,
									}

									table.insert(collision, obj)
								end

							elseif object.shape == "polygon" then
								local polygon = {}
								for _, vertex in ipairs(object.polygon) do
									table.insert(polygon, instance.x + vertex.x + x)
									table.insert(polygon, instance.y + vertex.y + y)
								end

								local triangles = love.math.triangulate(polygon)

								for _, triangle in ipairs(triangles) do
									local shape = love.physics.newPolygonShape(unpack(triangle))
									local fixture = love.physics.newFixture(body, shape)
									local obj = {
										shape = shape,
										fixture = fixture,
									}

									table.insert(collision, obj)
								end

							elseif object.shape == "polyline" then
								local polyline = {}
								for _, vertex in ipairs(object.polyline) do
									table.insert(polyline, instance.x + vertex.x + x)
									table.insert(polyline, instance.y + vertex.y + y)
								end

								local shape = love.physics.newChainShape(false, unpack(polyline))
								local fixture = love.physics.newFixture(body, shape)
								local obj = {
									shape = shape,
									fixture = fixture,
								}

								table.insert(collision, obj)
							end
						end
					end
				end
			end
		end
	end

	return collision
end

function Map:convertEllipseToPolygon(x, y, w, h)
	local function calc_segments(segments)
		local function vdist(a, b)
			local c = {
				x = a.x - b.x,
				y = a.y - b.y,
			}

			return c.x * c.x + c.y * c.y
		end

		segments = segments or 64
		local vertices = {}

		local v = { 1, 2, math.ceil(segments/4-1), math.ceil(segments/4) }

		for _, i in ipairs(v) do
			local angle = (i / segments) * math.pi * 2
			local px = x + w / 2 + math.cos(angle) * w / 2
			local py = y + h / 2 + math.sin(angle) * h / 2

			table.insert(vertices, { x = px / love.physics.getMeter(), y = py / love.physics.getMeter() })
		end

		local dist1 = vdist(vertices[1], vertices[2])
		local dist2 = vdist(vertices[3], vertices[4])

		-- Box2D hard-coded threshold
		if dist1 < 0.0025 or dist2 < 0.0025 then
			return calc_segments(segments-2)
		end

		return segments
	end

	local segments = calc_segments()
	local vertices = {}

	table.insert(vertices, { x = x + w / 2, y = y + h / 2 })

	for i=0, segments do
		local angle = (i / segments) * math.pi * 2
		local px = x + w / 2 + math.cos(angle) * w / 2
		local py = y + h / 2 + math.sin(angle) * h / 2

		table.insert(vertices, { x = px, y = py })
	end

	return vertices
end

-- apparently Tiled 0.10.0 sets the y position of an tiled object to the down left instead of the upper left corner
function Map:fixObjectLayersYPosition(layer)
		if layer.type == "objectgroup" then
			for __, object in ipairs(layer.objects) do
				if object.gid then
					object.y = object.y - self.tileheight
				end
			end
		end
end

return Map
