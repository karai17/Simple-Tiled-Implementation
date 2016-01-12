--- Map object
-- @module map

local path       = (...):gsub('%.[^%.]+$', '') .. "."
local pluginPath = string.gsub(path, "[.]", "/") .. "plugins/"
local Map        = {}

-- https://github.com/stevedonovan/Penlight/blob/master/lua/pl/path.lua#L286
local function formatPath(path)
	local np_gen1,np_gen2  = '[^SEP]+SEP%.%.SEP?','SEP+%.?SEP'
	local np_pat1, np_pat2 = np_gen1:gsub('SEP','/'), np_gen2:gsub('SEP','/')
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

-- Compensation for scale/rotation shift
local function compensate(tile, x, y, tw, th)
	local tx    = x + tile.offset.x
	local ty    = y + tile.offset.y
	local origx = tx
	local origy = ty
	local compx = 0
	local compy = 0

	if tile.sx < 0 then compx = tw end
	if tile.sy < 0 then compy = th end

	if tile.r > 0 then
		tx = tx + th - compy
		ty = ty + th - tw + compx
	elseif tile.r < 0 then
		tx = tx + compy
		ty = ty + th - compx
	else
		tx = tx + compx
		ty = ty + compy
	end

	return tx, ty
end

-- Cache images in main STI module
local function cache_image(sti, path)
	local image = love.graphics.newImage(path)
	image:setFilter("nearest", "nearest")
	sti.cache[path] = image
end

--- Instance a new map
-- @param path Path to the map file
-- @param plugins A list of plugins to load
-- @param ox Offset of map on the X axis (in pixels)
-- @param oy Offset of map on the Y axis (in pixels)
-- @return nil
function Map:init(STI, path, plugins, ox, oy)
	if type(plugins) == "table" then
		self:loadPlugins(plugins)
	end

	self:resize()
	self.objects       = {}
	self.tiles         = {}
	self.tileInstances = {}
	self.drawRange     = {
		sx = 1,
		sy = 1,
		ex = self.width,
		ey = self.height,
	}
	self.offsetx = ox or 0
	self.offsety = oy or 0
	self.sti     = STI

	-- Set tiles, images
	local gid = 1
	for i, tileset in ipairs(self.tilesets) do
		assert(tileset.image, "STI does not support Tile Collections.\nYou need to create a Texture Atlas.")

		-- Cache images
		local formatted_path = formatPath(path .. tileset.image)
		if not self.sti.cache[formatted_path] then
			cache_image(self.sti, formatted_path)
		end

		-- Pull images from cache
		tileset.image = self.sti.cache[formatted_path]

		gid = self:setTiles(i, tileset, gid)
	end

	-- Set layers
	for i, layer in ipairs(self.layers) do
		self:setLayer(layer, path)
	end
end

--- Load plugins
-- @param plugins A list of plugins to load
-- @return nil
function Map:loadPlugins(plugins)
	for _, plugin in ipairs(plugins) do
		local p = pluginPath .. plugin .. ".lua"
		if love.filesystem.isFile(p) then
			local file = love.filesystem.load(p)()
			for k, func in pairs(file) do
				if not self[k] then
					self[k] = func
				end
			end
		end
	end
end

--- Create Tiles
-- @param index Index of the Tileset
-- @param tileset Tileset data
-- @param gid First Global ID in Tileset
-- @return number Next Tileset's first Global ID
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

	local quad = love.graphics.newQuad
	local mw   = self.tilewidth
	local iw   = tileset.imagewidth
	local ih   = tileset.imageheight
	local tw   = tileset.tilewidth
	local th   = tileset.tileheight
	local s    = tileset.spacing
	local m    = tileset.margin
	local w    = getTiles(iw, tw, m, s)
	local h    = getTiles(ih, th, m, s)

	for y = 1, h do
		for x = 1, w do
			local id = gid - tileset.firstgid
			local qx = (x - 1) * tw + m + (x - 1) * s
			local qy = (y - 1) * th + m + (y - 1) * s
			local properties, terrain, animation, objectGroup

			for _, tile in pairs(tileset.tiles) do
				if tile.id == id then
					properties  = tile.properties
					animation   = tile.animation
					objectGroup = tile.objectGroup

					if tile.terrain then
						terrain = {}

						for i=1, #tile.terrain do
							terrain[i] = tileset.terrains[tile.terrain[i] + 1]
						end
					end
				end
			end

			local tile = {
				id          = id,
				gid         = gid,
				tileset     = index,
				quad        = quad(qx, qy, tw, th, iw, ih),
				properties  = properties or {},
				terrain     = terrain,
				animation   = animation,
				objectGroup = objectGroup,
				frame       = 1,
				time        = 0,
				width       = tw,
				height      = th,
				sx          = 1,
				sy          = 1,
				r           = 0,
				offset      = {
					x = -mw + tileset.tileoffset.x,
					y = -th + tileset.tileoffset.y,
				},
			}

			if self.orientation == "isometric" then
				tile.offset.x = -mw / 2
			end

			self.tiles[gid] = tile
			gid             = gid + 1
		end
	end

	return gid
end

--- Create Layers
-- @param layer Layer data
-- @param path (Optional) Path to an Image Layer's image
-- @return nil
function Map:setLayer(layer, path)
	if layer.encoding then
		if layer.encoding == "base64" then
			local ffi = assert(require "ffi", "Compressed maps require LuaJIT FFI.\nPlease Switch your interperator to LuaJIT or your Tile Layer Format to \"CSV\".")
			local fd  = love.filesystem.newFileData(layer.data, "data", "base64"):getString()

			local function getDecompressedData(data)
				local d       = {}
				local decoded = ffi.cast("uint32_t*", data)

				for i=0, data:len() / ffi.sizeof("uint32_t") do
					table.insert(d, tonumber(decoded[i]))
				end

				return d
			end

			if not layer.compression then
				layer.data = getDecompressedData(fd)
			else
				assert(love.math.decompress, "zlib and gzip compression require LOVE 0.10.0+.\nPlease set your Tile Layer Format to \"Base64 (uncompressed)\" or \"CSV\".")

				if layer.compression == "zlib" then
					local data = love.math.decompress(fd, "zlib")
					layer.data = getDecompressedData(data)
				end

				if layer.compression == "gzip" then
					local data = love.math.decompress(fd, "gzip")
					layer.data = getDecompressedData(data)
				end
			end
		end
	end

	layer.x      = (layer.x or 0) + self.offsetx
	layer.y      = (layer.y or 0) + self.offsety
	layer.update = function(dt) return end

	if layer.type == "tilelayer" then
		self:setTileData(layer)
		self:setSpriteBatches(layer)
		layer.draw = function() self:drawTileLayer(layer) end
	elseif layer.type == "objectgroup" then
		self:setObjectData(layer)
		self:setObjectCoordinates(layer)
		self:setObjectSpriteBatches(layer)
		layer.draw = function() self:drawObjectLayer(layer) end
	elseif layer.type == "imagelayer" then
		layer.draw = function() self:drawImageLayer(layer) end

		if layer.image ~= "" then
			local formatted_path = formatPath(path .. layer.image)
			if not self.sti.cache[formatted_path] then
				cache_image(self.sti, formatted_path)
			end

			layer.image  = self.sti.cache[formatted_path]
			layer.width  = layer.image:getWidth()
			layer.height = layer.image:getHeight()
		end
	end

	self.layers[layer.name] = layer
end

--- Add Tiles to Tile Layer
-- @param layer The Tile Layer
-- @return nil
function Map:setTileData(layer)
	local i   = 1
	local map = {}

	for y = 1, layer.height do
		map[y] = {}
		for x = 1, layer.width do
			local gid = layer.data[i]

			if gid > 0 then
				map[y][x] = self.tiles[gid] or self:setFlippedGID(gid)
			end

			i = i + 1
		end
	end

	layer.data = map
end

--- Add Objects to Layer
-- @param layer The Object Layer
-- @return nil
function Map:setObjectData(layer)
	for _, object in ipairs(layer.objects) do
		object.layer            = layer
		self.objects[object.id] = object
	end
end

--- Correct position and orientation of Objects in an Object Layer
-- @param layer The Object Layer
-- @return nil
function Map:setObjectCoordinates(layer)
	local function convertEllipseToPolygon(x, y, w, h, max_segments)
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

			local m
			if love.physics then
				m = love.physics.getMeter()
			else
				m = 32
			end

			for _, i in ipairs(v) do
				local angle = (i / segments) * math.pi * 2
				local px    = x + w / 2 + math.cos(angle) * w / 2
				local py    = y + h / 2 + math.sin(angle) * h / 2

				table.insert(vertices, { x = px / m, y = py / m })
			end

			local dist1 = vdist(vertices[1], vertices[2])
			local dist2 = vdist(vertices[3], vertices[4])

			-- Box2D threshold
			if dist1 < 0.0025 or dist2 < 0.0025 then
				return calc_segments(segments-2)
			end

			return segments
		end

		local segments = calc_segments(max_segments)
		local vertices = {}

		table.insert(vertices, { x = x + w / 2, y = y + h / 2 })

		for i=0, segments do
			local angle = (i / segments) * math.pi * 2
			local px    = x + w / 2 + math.cos(angle) * w / 2
			local py    = y + h / 2 + math.sin(angle) * h / 2

			table.insert(vertices, { x = px, y = py })
		end

		return vertices
	end

	local function rotateVertex(v, x, y, cos, sin)
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

	local function updateVertex(vertex, x, y, cos, sin)
		if self.orientation == "isometric" then
			x, y               = self:convertIsometricToScreen(x, y)
			vertex.x, vertex.y = self:convertIsometricToScreen(vertex.x, vertex.y)
		end

		return rotateVertex(vertex, x, y, cos, sin)
	end

	for _, object in ipairs(layer.objects) do
		local x   = layer.x + object.x
		local y   = layer.y + object.y
		local w   = object.width
		local h   = object.height
		local r   = object.rotation
		local cos = math.cos(math.rad(r))
		local sin = math.sin(math.rad(r))

		if object.shape == "rectangle" and not object.gid then
			object.rectangle = {}

			local vertices = {
				{ x=x,     y=y     },
				{ x=x + w, y=y     },
				{ x=x + w, y=y + h },
				{ x=x,     y=y + h },
			}

			for _, vertex in ipairs(vertices) do
				vertex.x, vertex.y = updateVertex(vertex, x, y, cos, sin)
				table.insert(object.rectangle, { x = vertex.x, y = vertex.y })
			end
		elseif object.shape == "ellipse" then
			object.ellipse = {}
			local vertices = convertEllipseToPolygon(x, y, w, h)

			for _, vertex in ipairs(vertices) do
				vertex.x, vertex.y = updateVertex(vertex, x, y, cos, sin)
				table.insert(object.ellipse, { x = vertex.x, y = vertex.y })
			end
		elseif object.shape == "polygon" then
			for _, vertex in ipairs(object.polygon) do
				vertex.x           = vertex.x + x
				vertex.y           = vertex.y + y
				vertex.x, vertex.y = updateVertex(vertex, x, y, cos, sin)
			end
		elseif object.shape == "polyline" then
			for _, vertex in ipairs(object.polyline) do
				vertex.x           = vertex.x + x
				vertex.y           = vertex.y + y
				vertex.x, vertex.y = updateVertex(vertex, x, y, cos, sin)
			end
		end
	end
end

--- Batch Tiles in Tile Layer for improved draw speed
-- @param layer The Tile Layer
-- @return nil
function Map:setSpriteBatches(layer)
	local newBatch = love.graphics.newSpriteBatch
	local w        = love.graphics.getWidth()
	local h        = love.graphics.getHeight()
	local tw       = self.tilewidth
	local th       = self.tileheight
	local bw       = math.ceil(w / tw)
	local bh       = math.ceil(h / th)
	local sx       = 1
	local sy       = 1
	local ex       = layer.width
	local ey       = layer.height
	local ix       = 1
	local iy       = 1

	-- Determine order to add tiles to sprite batch
	-- Defaults to right-down
	if self.renderorder == "right-up" then
		sx, ex, ix = sx, ex,  1
		sy, ey, iy = ey, sy, -1
	elseif self.renderorder == "left-down" then
		sx, ex, ix = ex, sx, -1
		sy, ey, iy = sy, ey,  1
	elseif self.renderorder == "left-up" then
		sx, ex, ix = ex, sx, -1
		sy, ey, iy = ey, sy, -1
	end

	-- Minimum of 400 tiles per batch
	if bw < 20 then bw = 20 end
	if bh < 20 then bh = 20 end

	local size    = bw * bh
	local batches = {
		width  = bw,
		height = bh,
		data   = {},
	}

	for y=sy, ey, iy do
		local by = math.ceil(y / bh)

		for x=sx, ex, ix do
			local tile = layer.data[y][x]
			local bx   = math.ceil(x / bw)
			local id

			if tile then
				local ts    = tile.tileset
				local image = self.tilesets[tile.tileset].image

				batches.data[ts]         = batches.data[ts] or {}
				batches.data[ts][by]     = batches.data[ts][by] or {}
				batches.data[ts][by][bx] = batches.data[ts][by][bx] or newBatch(image, size)

				local batch = batches.data[ts][by][bx]
				local tx, ty

				if self.orientation == "orthogonal" then
					tx, ty = compensate(tile, x*tw, y*th, tw, th)
				elseif self.orientation == "isometric" then
					tx = (x - y) * (tw / 2) + tile.offset.x + layer.width * tw / 2
					ty = (x + y) * (th / 2) + tile.offset.y
				elseif self.orientation == "staggered" or self.orientation == "hexagonal" then
					if self.staggeraxis == "y" then
						if self.staggerindex == "odd" then
							if y % 2 == 0 then
								tx = x * tw + tw / 2 + (self.hexsidelength or 0) + tile.offset.x
							else
								tx = x * tw + (self.hexsidelength or 0) + tile.offset.x
							end
						else
							if y % 2 == 0 then
								tx = x * tw + (self.hexsidelength or 0) + tile.offset.x
							else
								tx = x * tw + tw / 2 + (self.hexsidelength or 0) + tile.offset.x
							end
						end

						if self.orientation == "hexagonal" then
							ty = y * (th - (th - self.hexsidelength) / 2) + tile.offset.y + (th - (th - self.hexsidelength) / 2)
						else
							ty = y * th / 2 + tile.offset.y + th / 2
						end
					else
						if self.staggerindex == "odd" then
							if x % 2 == 0 then
								ty = y * th + th / 2 + (self.hexsidelength or 0) + tile.offset.y
							else
								ty = y * th + (self.hexsidelength or 0) + tile.offset.y
							end
						else
							if x % 2 == 0 then
								ty = y * th + (self.hexsidelength or 0) + tile.offset.y
							else
								ty = y * th + th / 2 + (self.hexsidelength or 0) + tile.offset.y
							end
						end

						if self.orientation == "hexagonal" then
							tx = x * (tw - (tw - self.hexsidelength) / 2) + tile.offset.x + (tw - (tw - self.hexsidelength) / 2)
						else
							tx = x * tw / 2 + tile.offset.x + tw / 2
						end
					end
				end

				id = batch:add(tile.quad, tx, ty, tile.r, tile.sx, tile.sy)
				self.tileInstances[tile.gid] = self.tileInstances[tile.gid] or {}
				table.insert(self.tileInstances[tile.gid], {
					layer = layer,
					batch = batch,
					id    = id,
					gid   = tile.gid,
					x     = tx,
					y     = ty,
					r     = tile.r,
					oy    = 0
				})
			end
		end
	end

	layer.batches = batches
end

--- Batch Tiles in Object Layer for improved draw speed
-- @param layer The Object Layer
-- @return nil
function Map:setObjectSpriteBatches(layer)
	local newBatch = love.graphics.newSpriteBatch
	local tw       = self.tilewidth
	local th       = self.tileheight
	local batches  = {}

	for _, object in ipairs(layer.objects) do
		if object.gid then
			local tile  = self.tiles[object.gid] or self:setFlippedGID(object.gid)
			local ts    = tile.tileset
			local image = self.tilesets[tile.tileset].image

			batches[ts] = batches[ts] or newBatch(image, 100)

			local batch = batches[ts]
			local tx    = object.x + tw + tile.offset.x
			local ty    = object.y + tile.offset.y
			local tr    = math.rad(object.rotation)
			local oy    = 0

			-- Compensation for scale/rotation shift
			if tile.sx == 1 and tile.sy == 1 then
				if tr ~= 0 then
					ty = ty + th
					oy = th
				end
			else
				if tile.sx < 0 then tx = tx + tw end
				if tile.sy < 0 then ty = ty + th end
				if tr      > 0 then tx = tx + tw end
				if tr      < 0 then ty = ty + th end
			end

			id = batch:add(tile.quad, tx, ty, tr, tile.sx, tile.sy, 0, oy)
			self.tileInstances[tile.gid] = self.tileInstances[tile.gid] or {}
			table.insert(self.tileInstances[tile.gid], {
				layer = layer,
				batch = batch,
				id    = id,
				gid   = tile.gid,
				x     = tx,
				y     = ty,
				r     = tr,
				oy    = oy
			})
		end
	end

	layer.batches = batches
end

--- Only draw what is visible on screen for improved draw speed
-- @param tx Translate X axis (in pixels)
-- @param ty Translate Y axis (in pixels)
-- @param w Width of screen (in pixels)
-- @param h Height of screen (in pixels)
-- @return nil
function Map:setDrawRange(tx, ty, w, h)
	local tw, th = self.tilewidth, self.tileheight
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
	elseif self.orientation == "staggered" or self.orientation == "hexagonal" then
		sx = math.ceil(tx / tw - 1)
		sy = math.ceil(ty / th)
		ex = math.ceil(sx + w / tw + 1)
		ey = math.ceil(sy + h / th * 2)
	end

	self.drawRange.sx = sx
	self.drawRange.sy = sy
	self.drawRange.ex = ex
	self.drawRange.ey = ey
end

--- Create a Custom Layer to place userdata in (such as player sprites)
-- @param name Name of Custom Layer
-- @param index Draw order within Layer stack
-- @return table Custom Layer
function Map:addCustomLayer(name, index)
	local index = index or #self.layers + 1
	local layer = {
      type       = "customlayer",
      name       = name,
      visible    = true,
      opacity    = 1,
      properties = {},
    }

	function layer:draw() return end
	function layer:update(dt) return end

	table.insert(self.layers, index, layer)
	self.layers[name] = self.layers[index]

	return layer
end

--- Convert another Layer into a Custom Layer
-- @param index Index or name of Layer to convert
-- @return table Custom Layer
function Map:convertToCustomLayer(index)
	local layer = assert(self.layers[index], "Layer not found: " .. index)

	layer.type     = "customlayer"
	layer.x        = nil
	layer.y        = nil
	layer.width    = nil
	layer.height   = nil
	layer.encoding = nil
	layer.data     = nil
	layer.objects  = nil
	layer.image    = nil

	function layer:draw() return end
	function layer:update(dt) return end

	return layer
end

--- Remove a Layer from the Layer stack
-- @param index Index or name of Layer to convert
-- @return nil
function Map:removeLayer(index)
	local layer = assert(self.layers[index], "Layer not found: " .. index)

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

	-- Remove tile instances
	if layer.batches then
		for gid, tiles in pairs(self.tileInstances) do
			for i=#tiles, 1, -1 do
				local tile = tiles[i]
				if tile.layer == layer then
					table.remove(tiles, i)
				end
			end
		end
	end

	-- Remove objects
	if layer.objects then
		for i, object in pairs(self.objects) do
			if object.layer == layer then
				self.objects[i] = nil
			end
		end
	end
end

--- Animate Tiles and update every Layer
-- @param dt Delta Time
-- @return nil
function Map:update(dt)
	for gid, tile in pairs(self.tiles) do
		local update = false

		if tile.animation then
			tile.time = tile.time + dt * 1000

			while tile.time > tonumber(tile.animation[tile.frame].duration) do
				update     = true
				tile.time  = tile.time  - tonumber(tile.animation[tile.frame].duration)
				tile.frame = tile.frame + 1

				if tile.frame > #tile.animation then tile.frame = 1 end
			end

			if update and self.tileInstances[tile.gid] then
				for _, j in pairs(self.tileInstances[tile.gid]) do
					local t = self.tiles[tonumber(tile.animation[tile.frame].tileid) + self.tilesets[tile.tileset].firstgid]
					j.batch:set(j.id, t.quad, j.x, j.y, j.r, tile.sx, tile.sy, 0, j.oy)
				end
			end
		end
	end


	for _, layer in ipairs(self.layers) do
		layer:update(dt)
	end
end

--- Draw every Layer
-- @return nil
function Map:draw()
	local current_canvas = love.graphics.getCanvas()
	love.graphics.setCanvas(self.canvas)
	if self.canvas.clear then
		self.canvas:clear()
	else
		local r,g,b,a = love.graphics.getBackgroundColor()
		love.graphics.clear(r,g,b,a,self.canvas)
	end

	for _, layer in ipairs(self.layers) do
		if layer.visible and layer.opacity > 0 then
			self:drawLayer(layer)
		end
	end

	love.graphics.setCanvas(current_canvas)
	love.graphics.push()
	love.graphics.origin()
	love.graphics.draw(self.canvas)
	love.graphics.pop()
end

--- Draw an individual Layer
-- @param layer The Layer to draw
-- @return nil
function Map:drawLayer(layer)
	love.graphics.setColor(255, 255, 255, 255 * layer.opacity)
	layer:draw()
	love.graphics.setColor(255, 255, 255, 255)
end

--- Default draw function for Tile Layers
-- @param layer The Tile Layer to draw
-- @return nil
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
	local ix = 1
	local iy = 1
	local mx = math.ceil(self.width / bw)
	local my = math.ceil(self.height / bh)

	-- Determine order to draw batches
	-- Defaults to right-down
	if self.renderorder == "right-up" then
		sx, ex, ix = sx, ex,  1
		sy, ey, iy = ey, sy, -1
	elseif self.renderorder == "left-down" then
		sx, ex, ix = ex, sx, -1
		sy, ey, iy = sy, ey,  1
	elseif self.renderorder == "left-up" then
		sx, ex, ix = ex, sx, -1
		sy, ey, iy = ey, sy, -1
	end

	for by=sy, ey, iy do
		for bx=sx, ex, ix do
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

--- Default draw function for Object Layers
-- @param layer The Object Layer to draw
-- @return nil
function Map:drawObjectLayer(layer)
	if type(layer) == "string" or type(layer) == "number" then
		layer = self.layers[layer]
	end

	assert(layer.type == "objectgroup", "Invalid layer type: " .. layer.type .. ". Layer must be of type: objectgroup")

	local line   = { 160, 160, 160, 255 * layer.opacity       }
	local fill   = { 160, 160, 160, 255 * layer.opacity * 0.2 }
	local shadow = {   0,   0,   0, 255 * layer.opacity       }
	local reset  = { 255, 255, 255, 255 * layer.opacity       }

	local function sortVertices(obj)
		local vertices = {{},{}}

		for _, vertex in ipairs(obj) do
			table.insert(vertices[1], vertex.x)
			table.insert(vertices[1], vertex.y)
			table.insert(vertices[2], vertex.x+1)
			table.insert(vertices[2], vertex.y+1)
		end

		return vertices
	end

	local function drawShape(obj, shape)
		local vertices = sortVertices(obj)

		if shape == "polyline" then
			love.graphics.setColor(shadow)
			love.graphics.line(vertices[2])
			love.graphics.setColor(line)
			love.graphics.line(vertices[1])

			return
		elseif shape == "polygon" then
			love.graphics.setColor(fill)
			if not love.math.isConvex(vertices[1]) then
				local triangles = love.math.triangulate(vertices[1])
				for _, triangle in ipairs(triangles) do
					love.graphics.polygon("fill", triangle)
				end
			else
				love.graphics.polygon("fill", vertices[1])
			end
		else
			love.graphics.setColor(fill)
			love.graphics.polygon("fill", vertices[1])
		end

		love.graphics.setColor(shadow)
		love.graphics.polygon("line", vertices[2])
		love.graphics.setColor(line)
		love.graphics.polygon("line", vertices[1])
	end

	for _, object in ipairs(layer.objects) do
		if object.shape == "rectangle" and not object.gid then
			drawShape(object.rectangle, "rectangle")
		elseif object.shape == "ellipse" then
			drawShape(object.ellipse, "ellipse")
		elseif object.shape == "polygon" then
			drawShape(object.polygon, "polygon")
		elseif object.shape == "polyline" then
			drawShape(object.polyline, "polyline")
		end
	end

	love.graphics.setColor(reset)
	for _, batch in pairs(layer.batches) do
		love.graphics.draw(batch, 0, 0)
	end
end

--- Default draw function for Image Layers
-- @param layer The Image Layer to draw
-- @return nil
function Map:drawImageLayer(layer)
	if type(layer) == "string" or type(layer) == "number" then
		layer = self.layers[layer]
	end

	assert(layer.type == "imagelayer", "Invalid layer type: " .. layer.type .. ". Layer must be of type: imagelayer")

	if layer.image ~= "" then
		love.graphics.draw(layer.image, layer.x, layer.y)
	end
end

--- Resize the drawable area of the Map
-- @param w The new width of the drawable area (in pixels)
-- @param h The new Height of the drawable area (in pixels)
-- @return nil
function Map:resize(w, h)
	w = w or love.graphics.getWidth()
	h = h or love.graphics.getHeight()

	self.canvas = love.graphics.newCanvas(w, h)
	self.canvas:setFilter("nearest", "nearest")
end

--- Create flipped or rotated Tiles based on bitop flags
-- @param gid The flagged Global ID
-- @return table Flipped Tile
function Map:setFlippedGID(gid)
	local bit31   = 2147483648
	local bit30   = 1073741824
	local bit29   = 536870912
	local flipX   = false
	local flipY   = false
	local flipD   = false
	local realgid = gid

	if realgid >= bit31 then
		realgid = realgid - bit31
		flipX   = not flipX
	end

	if realgid >= bit30 then
		realgid = realgid - bit30
		flipY   = not flipY
	end

	if realgid >= bit29 then
		realgid = realgid - bit29
		flipD   = not flipD
	end

	local tile = self.tiles[realgid]
	local data = {
		id         = tile.id,
		gid        = gid,
		tileset    = tile.tileset,
		frame      = tile.frame,
		time       = tile.time,
		width      = tile.width,
		height     = tile.height,
		offset     = tile.offset,
		quad       = tile.quad,
		properties = tile.properties,
		terrain    = tile.terrain,
		animation  = tile.animation,
		sx         = tile.sx,
		sy         = tile.sy,
		r          = tile.r,
	}

	if flipX then
		if flipY and flipD then
			data.r  = math.rad(-90)
			data.sy = -1
		elseif flipY then
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
		data.r  = math.rad(90)
		data.sy = -1
	end

	self.tiles[gid] = data

	return self.tiles[gid]
end

--- Get custom properties from Layer
-- @param layer The Layer
-- @return table List of properties
function Map:getLayerProperties(layer)
	local l = self.layers[layer]

	if not l then return {} end

	return l.properties
end

--- Get custom properties from Tile
-- @param layer The Layer that the Tile belongs to
-- @param x The X axis location of the Tile (in tiles)
-- @param y The Y axis location of the Tile (in tiles)
-- @return table List of properties
function Map:getTileProperties(layer, x, y)
	local tile = self.layers[layer].data[y][x]

	if not tile then return {} end

	return tile.properties
end

--- Get custom properties from Object
-- @param layer The Layer that the Object belongs to
-- @param object The index or name of the Object
-- @return table List of properties
function Map:getObjectProperties(layer, object)
	local o = self.layers[layer].objects

	if type(object) == "number" then
		o = o[object]
	else
		for _, v in ipairs(o) do
			if v.name == object then
				o = v
				break
			end
		end
	end

	if not o then return {} end

	return o.properties
end

--- Project isometric position to orthoganal position
-- @param x The X axis location of the point (in pixels)
-- @param y The Y axis location of the point (in pixels)
-- @return number The X axis location of the point (in pixels)
-- @return number The Y axis location of the point (in pixels)
function Map:convertIsometricToScreen(x, y)
	local mw = self.width
	local tw = self.tilewidth
	local th = self.tileheight
	local ox = mw * tw / 2
	local sx = (x - y) + ox
	local sy = (x + y) / 2

	return sx, sy
end

--- Project orthoganal position to isometric position
-- @param x The X axis location of the point (in pixels)
-- @param y The Y axis location of the point (in pixels)
-- @return number The X axis location of the point (in pixels)
-- @return number The Y axis location of the point (in pixels)
function Map:convertScreenToIsometric(x, y)
	local mw = self.width
	local mh = self.height
	local tw = self.tilewidth
	local th = self.tileheight
	local ox = mw * tw / 2
	local oy = mh * th / 2
	local tx = (x / 2 + y) - ox / 2
	local ty = (-x / 2 + y) + oy

	return tx, ty
end

--- Convert orthoganal tile space to screen space
-- @param x The X axis location of the point (in tiles)
-- @param y The Y axis location of the point (in tiles)
-- @return number The X axis location of the point (in pixels)
-- @return number The Y axis location of the point (in pixels)
function Map:convertTileToScreen(x, y)
	local tw = self.tilewidth
	local th = self.tileheight
	local sx = x * tw
	local sy = y * th

	return sx, sy
end

--- Convert orthoganal screen space to tile space
-- @param x The X axis location of the point (in pixels)
-- @param y The Y axis location of the point (in pixels)
-- @return number The X axis location of the point (in tiles)
-- @return number The Y axis location of the point (in tiles)
function Map:convertScreenToTile(x, y)
	local tw = self.tilewidth
	local th = self.tileheight
	local tx = x / tw
	local ty = y / th

	return tx, ty
end

--- Convert isometric tile space to screen space
-- @param x The X axis location of the point (in tiles)
-- @param y The Y axis location of the point (in tiles)
-- @return number The X axis location of the point (in pixels)
-- @return number The Y axis location of the point (in pixels)
function Map:convertIsometricTileToScreen(x, y)
	local mw = self.width
	local tw = self.tilewidth
	local th = self.tileheight
	local ox = mw * tw / 2
	local sx = (x - y) * tw / 2 + ox
	local sy = (x + y) * th / 2

	return sx, sy
end

--- Convert isometric screen space to tile space
-- @param x The X axis location of the point (in pixels)
-- @param y The Y axis location of the point (in pixels)
-- @return number The X axis location of the point (in tiles)
-- @return number The Y axis location of the point (in tiles)
function Map:convertScreenToIsometricTile(x, y)
	local mw = self.width
	local tw = self.tilewidth
	local th = self.tileheight
	local ox = mw * tw / 2
	local tx = y / th + (x - ox) / tw
	local ty = y / th - (x - ox) / tw

	return tx, ty
end

--- Convert staggered isometric tile space to screen space
-- @param x The X axis location of the point (in tiles)
-- @param y The Y axis location of the point (in tiles)
-- @return number The X axis location of the point (in pixels)
-- @return number The Y axis location of the point (in pixels)
function Map:convertStaggeredTileToScreen(x, y)
	local tw = self.tilewidth
	local th = self.tileheight
	local sx = x * tw + math.abs(math.ceil(y) % 2) * (tw / 2) - (math.ceil(y) % 2 * tw/2)
	local sy = y * (th / 2) + th/2

	return sx, sy
end

--- Convert staggered isometric screen space to tile space
-- @param x The X axis location of the point (in pixels)
-- @param y The Y axis location of the point (in pixels)
-- @return number The X axis location of the point (in tiles)
-- @return number The Y axis location of the point (in tiles)
function Map:convertScreenToStaggeredTile(x, y)
	local function topLeft(x, y)
		if (math.ceil(y) % 2) then
			return x, y - 1
		else
			return x - 1, y - 1
		end
	end

	local function topRight(x, y)
		if (math.ceil(y) % 2) then
			return x + 1, y - 1
		else
			return x, y - 1
		end
	end

	local function bottomLeft(x, y)
		if (math.ceil(y) % 2) then
			return x, y + 1
		else
			return x - 1, y + 1
		end
	end

	local function bottomRight(x, y)
		if (math.ceil(y) % 2) then
			return x + 1, y + 1
		else
			return x, y + 1
		end
	end

	local tw    = self.tilewidth
	local th    = self.tileheight
	local hh    = th / 2
	local ratio = th / tw
	local tx    = x / tw
	local ty    = y / th * 2
	local ctx   = math.ceil(x / tw)
	local cty   = math.ceil(y / th) * 2
	local rx    = x - ctx * tw
	local ry    = y - (cty / 2) * th

	if (hh - rx * ratio > ry) then
		return topLeft(tx, ty)
	elseif (-hh + rx * ratio > ry) then
		return topRight(tx, ty)
	elseif (hh + rx * ratio < ry) then
		return bottomLeft(tx, ty)
	elseif (hh * 3 - rx * ratio < ry) then
		return bottomRight(tx, ty)
	end

	return tx, ty
end

return Map

--- A list of individual layers indexed both by draw order and name
-- @table Map.layers
-- @see TileLayer
-- @see ObjectLayer
-- @see ImageLayer
-- @see CustomLayer

--- A list of individual tiles indexed by Global ID
-- @table Map.tiles
-- @see Tile
-- @see Map.tileInstances

--- A list of tile instances indexed by Global ID
-- @table Map.tileInstances
-- @see TileInstance
-- @see Tile
-- @see Map.tiles

--- A list of individual objects indexed by Global ID
-- @table Map.objects
-- @see Object

--- @table TileLayer
-- @field name The name of the layer
-- @field x Position on the X axis (in pixels)
-- @field y Position on the Y axis (in pixels)
-- @field width Width of layer (in tiles)
-- @field height Height of layer (in tiles)
-- @field visible Toggle if layer is visible or hidden
-- @field opacity Opacity of layer
-- @field properties Custom properties
-- @field data A two dimensional table filled with individual tiles indexed by [y][x] (in tiles)
-- @field update Update function
-- @field draw Draw function
-- @see Map.layers
-- @see Tile

--- @table ObjectLayer
-- @field name The name of the layer
-- @field x Position on the X axis (in pixels)
-- @field y Position on the Y axis (in pixels)
-- @field visible Toggle if layer is visible or hidden
-- @field opacity Opacity of layer
-- @field properties Custom properties
-- @field objects List of objects indexed by draw order
-- @field update Update function
-- @field draw Draw function
-- @see Map.layers
-- @see Object

--- @table ImageLayer
-- @field name The name of the layer
-- @field x Position on the X axis (in pixels)
-- @field y Position on the Y axis (in pixels)
-- @field visible Toggle if layer is visible or hidden
-- @field opacity Opacity of layer
-- @field properties Custom properties
-- @field image Image to be drawn
-- @field update Update function
-- @field draw Draw function
-- @see Map.layers

--- Custom Layers are used to place userdata such as sprites within the draw order of the map.
-- @table CustomLayer
-- @field name The name of the layer
-- @field x Position on the X axis (in pixels)
-- @field y Position on the Y axis (in pixels)
-- @field visible Toggle if layer is visible or hidden
-- @field opacity Opacity of layer
-- @field properties Custom properties
-- @field update Update function
-- @field draw Draw function
-- @see Map.layers
-- @usage
--	-- Create a Custom Layer
--	local spriteLayer = map:addCustomLayer("Sprite Layer", 3)
--
--	-- Add data to Custom Layer
--	spriteLayer.sprites = {
--		player = {
--			image = love.graphics.newImage("assets/sprites/player.png"),
--			x = 64,
--			y = 64,
--			r = 0,
--		}
--	}
--
--	-- Update callback for Custom Layer
--	function spriteLayer:update(dt)
--		for _, sprite in pairs(self.sprites) do
--			sprite.r = sprite.r + math.rad(90 * dt)
--		end
--	end
--
--	-- Draw callback for Custom Layer
--	function spriteLayer:draw()
--		for _, sprite in pairs(self.sprites) do
--			local x = math.floor(sprite.x)
--			local y = math.floor(sprite.y)
--			local r = sprite.r
--			love.graphics.draw(sprite.image, x, y, r)
--		end
--	end

--- @table Tile
-- @field id Local ID within Tileset
-- @field gid Global ID
-- @field tileset Tileset ID
-- @field quad Quad object
-- @field properties Custom properties
-- @field terrain Terrain data
-- @field animation Animation data
-- @field frame Current animation frame
-- @field time Time spent on current animation frame
-- @field width Width of tile
-- @field height Height of tile
-- @field sx Scale value on the X axis
-- @field sy Scale value on the Y axis
-- @field r Rotation of tile (in radians)
-- @field offset Offset drawing position
-- @field offset.x Offset value on the X axis
-- @field offset.y Offset value on the Y axis
-- @see Map.tiles

--- @table TileInstance
-- @field batch Spritebatch the Tile Instance belongs to
-- @field id ID within the spritebatch
-- @field gid Global ID
-- @field x Position on the X axis (in pixels)
-- @field y Position on the Y axis (in pixels)
-- @see Map.tileInstances
-- @see Tile

--- @table Object
-- @field id Global ID
-- @field name Name of object (non-unique)
-- @field shape Shape of object
-- @field x Position of object on X axis (in pixels)
-- @field y Position of object on Y axis (in pixels)
-- @field width Width of object (in pixels)
-- @field height Heigh tof object (in pixels)
-- @field rotation Rotation of object (in radians)
-- @field visible Toggle if object is visible or hidden
-- @field properties Custom properties
-- @field ellipse List of verticies of specific shape
-- @field rectangle List of verticies of specific shape
-- @field polygon List of verticies of specific shape
-- @field polyline List of verticies of specific shape
-- @see Map.objects
