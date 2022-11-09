--- Simple and fast Tiled map loader and renderer.
-- @module sti
-- @author Landon Manning
-- @copyright 2019
-- @license MIT/X11

local STI = {
	_LICENSE     = "MIT/X11",
	_URL         = "https://github.com/karai17/Simple-Tiled-Implementation",
	_VERSION     = "1.2.3.0",
	_DESCRIPTION = "Simple Tiled Implementation is a Tiled Map Editor library designed for the *awesome* LÖVE framework.",
	cache        = {}
}
STI.__index = STI

local love  = _G.love
local cwd   = (...):gsub('%.init$', '') .. "."
local utils = require(cwd .. "utils")
local ceil  = math.ceil
local floor = math.floor
local lg    = require(cwd .. "graphics")
local atlas = require(cwd .. "atlas")
local Map   = {}
Map.__index = Map

local function new(map, plugins, ox, oy)
	local dir = ""

	if type(map) == "table" then
		map = setmetatable(map, Map)
	else
		-- Check for valid map type
		local ext = map:sub(-4, -1)
		assert(ext == ".lua", string.format(
			"Invalid file type: %s. File must be of type: lua.",
			ext
		))

		-- Get directory of map
		dir = map:reverse():find("[/\\]") or ""
		if dir ~= "" then
			dir = map:sub(1, 1 + (#map - dir))
		end

		-- Load map
		map = setmetatable(assert(love.filesystem.load(map))(), Map)
	end

	map:init(dir, plugins, ox, oy)

	return map
end

--- Instance a new map.
-- @param map Path to the map file or the map table itself
-- @param plugins A list of plugins to load
-- @param ox Offset of map on the X axis (in pixels)
-- @param oy Offset of map on the Y axis (in pixels)
-- @return table The loaded Map
function STI.__call(_, map, plugins, ox, oy)
	return new(map, plugins, ox, oy)
end

--- Flush image cache.
function STI:flush()
	self.cache = {}
end

--- Map object

--- Instance a new map
-- @param path Path to the map file
-- @param plugins A list of plugins to load
-- @param ox Offset of map on the X axis (in pixels)
-- @param oy Offset of map on the Y axis (in pixels)
function Map:init(path, plugins, ox, oy)
	if type(plugins) == "table" then
		self:loadPlugins(plugins)
	end

	self:resize()
	self.objects       = {}
	self.tiles         = {}
	self.tileInstances = {}
	self.offsetx = ox or 0
	self.offsety = oy or 0

	self.freeBatchSprites = {}
	setmetatable(self.freeBatchSprites, { __mode = 'k' })

	-- Set tiles, images
	local gid = 1
	for i, tileset in ipairs(self.tilesets) do
		assert(not tileset.filename, "STI does not support external Tilesets.\nYou need to embed all Tilesets.")

        if tileset.image then
            -- Cache images
            if lg.isCreated then
                local formatted_path = utils.format_path(path .. tileset.image)

                if not STI.cache[formatted_path] then
                    utils.fix_transparent_color(tileset, formatted_path)
                    utils.cache_image(STI, formatted_path, tileset.image)
                else
                    tileset.image = STI.cache[formatted_path]
                end
            end

            gid = self:setTiles(i, tileset, gid)
        elseif tileset.tilecount > 0 then
            -- Build atlas for image collection
            local files, ids = {}, {}
            for j = 1, #tileset.tiles do
                files[ j ] = utils.format_path(path .. tileset.tiles[j].image)
                ids[ j ] = tileset.tiles[j].id
            end

            local map = atlas.Atlas( files, "ids", ids )

            if lg.isCreated then
                local formatted_path = utils.format_path(path .. tileset.name)

                if not STI.cache[formatted_path] then
                    -- No need to fix transparency color for collections
                    utils.cache_image(STI, formatted_path, map.image)
                    tileset.image = map.image
                else
                    tileset.image = STI.cache[formatted_path]
                end
            end

            gid = self:setAtlasTiles(i, tileset, map.coords, gid)
        end
	end

	local layers = {}
	for _, layer in ipairs(self.layers) do
		self:groupAppendToList(layers, layer)
	end
	self.layers = layers

	-- Set layers
	for _, layer in ipairs(self.layers) do
		self:setLayer(layer, path)
	end
end

--- Layers from the group are added to the list
-- @param layers List of layers
-- @param layer Layer data
function Map:groupAppendToList(layers, layer)
	if layer.type == "group" then
		for _, groupLayer in pairs(layer.layers) do
			groupLayer.name = layer.name .. "." .. groupLayer.name
			groupLayer.visible = layer.visible
			groupLayer.opacity = layer.opacity * groupLayer.opacity
			groupLayer.offsetx = layer.offsetx + groupLayer.offsetx
			groupLayer.offsety = layer.offsety + groupLayer.offsety

			for key, property in pairs(layer.properties) do
				if groupLayer.properties[key] == nil then
					groupLayer.properties[key] = property
				end
			end

			self:groupAppendToList(layers, groupLayer)
		end
	else
		table.insert(layers, layer)
	end
end

--- Load plugins
-- @param plugins A list of plugins to load
function Map:loadPlugins(plugins)
	for _, plugin in ipairs(plugins) do
		local pluginModulePath = cwd .. 'plugins.' .. plugin
		local ok, pluginModule = pcall(require, pluginModulePath)
		if ok then
			for k, func in pairs(pluginModule) do
				if not self[k] then
					self[k] = func
				end
			end
		end
	end
end

--- Create Tiles based on a single tileset image
-- @param index Index of the Tileset
-- @param tileset Tileset data
-- @param gid First Global ID in Tileset
-- @return number Next Tileset's first Global ID
function Map:setTiles(index, tileset, gid)
	local quad    = lg.newQuad
	local imageW  = tileset.imagewidth
	local imageH  = tileset.imageheight
	local tileW   = tileset.tilewidth
	local tileH   = tileset.tileheight
	local margin  = tileset.margin
	local spacing = tileset.spacing
	local w       = utils.get_tiles(imageW, tileW, margin, spacing)
	local h       = utils.get_tiles(imageH, tileH, margin, spacing)

	for y = 1, h do
		for x = 1, w do
			local id    = gid - tileset.firstgid
			local quadX = (x - 1) * tileW + margin + (x - 1) * spacing
			local quadY = (y - 1) * tileH + margin + (y - 1) * spacing
			local type = ""
			local properties, terrain, animation, objectGroup

			for _, tile in pairs(tileset.tiles) do
				if tile.id == id then
					properties  = tile.properties
					animation   = tile.animation
					objectGroup = tile.objectGroup
					type        = tile.type

					if tile.terrain then
						terrain = {}

						for i = 1, #tile.terrain do
							terrain[i] = tileset.terrains[tile.terrain[i] + 1]
						end
					end
				end
			end

			local tile = {
				id          = id,
				gid         = gid,
				tileset     = index,
				type        = type,
				quad        = quad(
					quadX,  quadY,
					tileW,  tileH,
					imageW, imageH
				),
				properties  = properties or {},
				terrain     = terrain,
				animation   = animation,
				objectGroup = objectGroup,
				frame       = 1,
				time        = 0,
				width       = tileW,
				height      = tileH,
				sx          = 1,
				sy          = 1,
				r           = 0,
				offset      = tileset.tileoffset,
			}

			self.tiles[gid] = tile
			gid             = gid + 1
		end
	end

	return gid
end

--- Create Tiles based on a texture atlas
-- @param index Index of the Tileset
-- @param tileset Tileset data
-- @param coords Tile XY location in the atlas
-- @param gid First Global ID in Tileset
-- @return number Next Tileset's first Global ID
function Map:setAtlasTiles(index, tileset, coords, gid)
    local quad      = lg.newQuad
    local imageW    = tileset.image:getWidth()
    local imageH    = tileset.image:getHeight()

    local firstgid = tileset.firstgid
    for i = 1, #tileset.tiles do
        local tile = tileset.tiles[i]
        if tile.terrain then
            terrain = {}

            for j = 1, #tile.terrain do
                terrain[j] = tileset.terrains[tile.terrain[j] + 1]
            end
        end

        local tile = {
            id          = tile.id,
            gid         = firstgid + tile.id,
            tileset     = index,
            class       = tile.class,
            quad        = quad(
                coords[i].x,  coords[i].y,
                tile.width,  tile.height,
                imageW, imageH
            ),
            properties  = tile.properties or {},
            terrain     = terrain,
            animation   = tile.animation,
            objectGroup = tile.objectGroup,
            frame       = 1,
            time        = 0,
            width       = tile.width,
            height      = tile.height,
            sx          = 1,
            sy          = 1,
            r           = 0,
            offset      = tileset.tileoffset,
        }

        -- Be aware that in collections self.tiles can be a sparse array
        self.tiles[tile.gid] = tile
    end

    return gid + #tileset.tiles
end

--- Create Layers
-- @param layer Layer data
-- @param path (Optional) Path to an Image Layer's image
function Map:setLayer(layer, path)
	if layer.encoding then
		if layer.encoding == "base64" then
			assert(require "ffi", "Compressed maps require LuaJIT FFI.\nPlease Switch your interperator to LuaJIT or your Tile Layer Format to \"CSV\".")
			local fd = love.data.decode("string", "base64", layer.data)

			if not layer.compression then
				layer.data = utils.get_decompressed_data(fd)
			else
				assert(love.data.decompress, "zlib and gzip compression require LOVE 11.0+.\nPlease set your Tile Layer Format to \"Base64 (uncompressed)\" or \"CSV\".")

				if layer.compression == "zlib" then
					local data = love.data.decompress("string", "zlib", fd)
					layer.data = utils.get_decompressed_data(data)
				end

				if layer.compression == "gzip" then
					local data = love.data.decompress("string", "gzip", fd)
					layer.data = utils.get_decompressed_data(data)
				end
			end
		end
	end

	layer.x      = (layer.x or 0) + layer.offsetx + self.offsetx
	layer.y      = (layer.y or 0) + layer.offsety + self.offsety
	layer.update = function() end

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
			local formatted_path = utils.format_path(path .. layer.image)
			if not STI.cache[formatted_path] then
				utils.cache_image(STI, formatted_path)
			end

			layer.image  = STI.cache[formatted_path]
			layer.width  = layer.image:getWidth()
			layer.height = layer.image:getHeight()
		end
	end

	self.layers[layer.name] = layer
end

--- Add Tiles to Tile Layer
-- @param layer The Tile Layer
function Map:setTileData(layer)
	if layer.chunks then
		for _, chunk in ipairs(layer.chunks) do
			self:setTileData(chunk)
		end
		return
	end

	local i   = 1
	local map = {}

	for y = 1, layer.height do
		map[y] = {}
		for x = 1, layer.width do
			local gid = layer.data[i]

			-- NOTE: Empty tiles have a GID of 0
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
function Map:setObjectData(layer)
	for _, object in ipairs(layer.objects) do
		object.layer            = layer
		self.objects[object.id] = object
	end
end

--- Correct position and orientation of Objects in an Object Layer
-- @param layer The Object Layer
function Map:setObjectCoordinates(layer)
	for _, object in ipairs(layer.objects) do
		local x   = layer.x + object.x
		local y   = layer.y + object.y
		local w   = object.width
		local h   = object.height
		local cos = math.cos(math.rad(object.rotation))
		local sin = math.sin(math.rad(object.rotation))

		if object.shape == "rectangle" and not object.gid then
			object.rectangle = {}

			local vertices = {
				{ x=x,     y=y     },
				{ x=x + w, y=y     },
				{ x=x + w, y=y + h },
				{ x=x,     y=y + h },
			}

			for _, vertex in ipairs(vertices) do
				vertex.x, vertex.y = utils.rotate_vertex(self, vertex, x, y, cos, sin)
				table.insert(object.rectangle, { x = vertex.x, y = vertex.y })
			end
		elseif object.shape == "ellipse" then
			object.ellipse = {}
			local vertices = utils.convert_ellipse_to_polygon(x, y, w, h)

			for _, vertex in ipairs(vertices) do
				vertex.x, vertex.y = utils.rotate_vertex(self, vertex, x, y, cos, sin)
				table.insert(object.ellipse, { x = vertex.x, y = vertex.y })
			end
		elseif object.shape == "polygon" then
			for _, vertex in ipairs(object.polygon) do
				vertex.x           = vertex.x + x
				vertex.y           = vertex.y + y
				vertex.x, vertex.y = utils.rotate_vertex(self, vertex, x, y, cos, sin)
			end
		elseif object.shape == "polyline" then
			for _, vertex in ipairs(object.polyline) do
				vertex.x           = vertex.x + x
				vertex.y           = vertex.y + y
				vertex.x, vertex.y = utils.rotate_vertex(self, vertex, x, y, cos, sin)
			end
		end
	end
end

--- Convert tile location to tile instance location
-- @param layer Tile layer
-- @param tile Tile
-- @param x Tile location on X axis (in tiles)
-- @param y Tile location on Y axis (in tiles)
-- @return number Tile instance location on X axis (in pixels)
-- @return number Tile instance location on Y axis (in pixels)
function Map:getLayerTilePosition(layer, tile, x, y)
	local tileW = self.tilewidth
	local tileH = self.tileheight
	local tileX, tileY

	if self.orientation == "orthogonal" then
		tileX = (x - 1) * tileW + tile.offset.x
		tileY = (y - 0) * tileH + tile.offset.y - tile.height
		tileX, tileY = utils.compensate(tile, tileX, tileY, tileW, tileH)
	elseif self.orientation == "isometric" then
		tileX = (x - y) * (tileW / 2) + tile.offset.x + layer.width * tileW / 2 - self.tilewidth / 2
		tileY = (x + y - 2) * (tileH / 2) + tile.offset.y
	else
		local sideLen = self.hexsidelength or 0
		if self.staggeraxis == "y" then
			if self.staggerindex == "odd" then
				if y % 2 == 0 then
					tileX = (x - 1) * tileW + tileW / 2 + tile.offset.x
				else
					tileX = (x - 1) * tileW + tile.offset.x
				end
			else
				if y % 2 == 0 then
					tileX = (x - 1) * tileW + tile.offset.x
				else
					tileX = (x - 1) * tileW + tileW / 2 + tile.offset.x
				end
			end

			local rowH = tileH - (tileH - sideLen) / 2
			tileY = (y - 1) * rowH + tile.offset.y
		else
			if self.staggerindex == "odd" then
				if x % 2 == 0 then
					tileY = (y - 1) * tileH + tileH / 2 + tile.offset.y
				else
					tileY = (y - 1) * tileH + tile.offset.y
				end
			else
				if x % 2 == 0 then
					tileY = (y - 1) * tileH + tile.offset.y
				else
					tileY = (y - 1) * tileH + tileH / 2 + tile.offset.y
				end
			end

			local colW = tileW - (tileW - sideLen) / 2
			tileX = (x - 1) * colW + tile.offset.x
		end
	end

	return tileX, tileY
end

--- Place new tile instance
-- @param layer Tile layer
-- @param chunk Layer chunk
-- @param tile Tile
-- @param number Tile location on X axis (in tiles)
-- @param number Tile location on Y axis (in tiles)
function Map:addNewLayerTile(layer, chunk, tile, x, y)
	local tileset = tile.tileset
	local image   = self.tilesets[tile.tileset].image
	local batches
	local size

	if chunk then
		batches = chunk.batches
		size    = chunk.width * chunk.height
	else
		batches = layer.batches
		size    = layer.width * layer.height
	end

	batches[tileset] = batches[tileset] or lg.newSpriteBatch(image, size)

	local batch = batches[tileset]
	local tileX, tileY = self:getLayerTilePosition(layer, tile, x, y)

	local instance = {
		layer = layer,
		chunk = chunk,
		gid   = tile.gid,
		x     = tileX,
		y     = tileY,
		r     = tile.r,
		oy    = 0
	}

	-- NOTE: STI can run headless so it is not guaranteed that a batch exists.
	if batch then
		instance.batch = batch
		instance.id = batch:add(tile.quad, tileX, tileY, tile.r, tile.sx, tile.sy)
	end

	self.tileInstances[tile.gid] = self.tileInstances[tile.gid] or {}
	table.insert(self.tileInstances[tile.gid], instance)
end

function Map:set_batches(layer, chunk)
	if chunk then
		chunk.batches = {}
	else
		layer.batches = {}
	end

	if self.orientation == "orthogonal" or self.orientation == "isometric" then
		local offsetX = chunk and chunk.x or 0
		local offsetY = chunk and chunk.y or 0

		local startX     = 1
		local startY     = 1
		local endX       = chunk and chunk.width  or layer.width
		local endY       = chunk and chunk.height or layer.height
		local incrementX = 1
		local incrementY = 1

		-- Determine order to add tiles to sprite batch
		-- Defaults to right-down
		if self.renderorder == "right-up" then
			startY, endY, incrementY = endY, startY, -1
		elseif self.renderorder == "left-down" then
			startX, endX, incrementX = endX, startX, -1
		elseif self.renderorder == "left-up" then
			startX, endX, incrementX = endX, startX, -1
			startY, endY, incrementY = endY, startY, -1
		end

		for y = startY, endY, incrementY do
			for x = startX, endX, incrementX do
				-- NOTE: Cannot short circuit this since it is valid for tile to be assigned nil
				local tile
				if chunk then
					tile = chunk.data[y][x]
				else
					tile = layer.data[y][x]
				end

				if tile then
					self:addNewLayerTile(layer, chunk, tile, x + offsetX, y + offsetY)
				end
			end
		end
	else
		if self.staggeraxis == "y" then
			for y = 1, (chunk and chunk.height or layer.height) do
				for x = 1, (chunk and chunk.width or layer.width) do
					-- NOTE: Cannot short circuit this since it is valid for tile to be assigned nil
					local tile
					if chunk then
						tile = chunk.data[y][x]
					else
						tile = layer.data[y][x]
					end

					if tile then
						self:addNewLayerTile(layer, chunk, tile, x, y)
					end
				end
			end
		else
			local i = 0
			local _x

			if self.staggerindex == "odd" then
				_x = 1
			else
				_x = 2
			end

			while i < (chunk and chunk.width * chunk.height or layer.width * layer.height) do
				for _y = 1, (chunk and chunk.height or layer.height) + 0.5, 0.5 do
					local y = floor(_y)

					for x = _x, (chunk and chunk.width or layer.width), 2 do
						i = i + 1

						-- NOTE: Cannot short circuit this since it is valid for tile to be assigned nil
						local tile
						if chunk then
							tile = chunk.data[y][x]
						else
							tile = layer.data[y][x]
						end

						if tile then
							self:addNewLayerTile(layer, chunk, tile, x, y)
						end
					end

					if _x == 1 then
						_x = 2
					else
						_x = 1
					end
				end
			end
		end
	end
end

--- Batch Tiles in Tile Layer for improved draw speed
-- @param layer The Tile Layer
function Map:setSpriteBatches(layer)
	if layer.chunks then
		for _, chunk in ipairs(layer.chunks) do
			self:set_batches(layer, chunk)
		end
		return
	end

	self:set_batches(layer)
end

--- Batch Tiles in Object Layer for improved draw speed
-- @param layer The Object Layer
function Map:setObjectSpriteBatches(layer)
	local newBatch = lg.newSpriteBatch
	local batches  = {}

	if layer.draworder == "topdown" then
		table.sort(layer.objects, function(a, b)
			return a.y + a.height < b.y + b.height
		end)
	end

	for _, object in ipairs(layer.objects) do
		if object.gid then
			local tile    = self.tiles[object.gid] or self:setFlippedGID(object.gid)
			local tileset = tile.tileset
			local image   = self.tilesets[tileset].image

			batches[tileset] = batches[tileset] or newBatch(image)

			local sx = object.width  / tile.width
			local sy = object.height / tile.height

			-- Tiled rotates around bottom left corner, where love2D rotates around top left corner
			local ox = 0
			local oy = tile.height

			local batch = batches[tileset]
			local tileX = object.x + tile.offset.x
			local tileY = object.y + tile.offset.y
			local tileR = math.rad(object.rotation)

			-- Compensation for scale/rotation shift
			if tile.sx == -1 then
				tileX = tileX + object.width

				if tileR ~= 0 then
					tileX = tileX - object.width
					ox = ox + tile.width
				end
			end

			if tile.sy == -1 then
				tileY = tileY - object.height

				if tileR ~= 0 then
					tileY = tileY + object.width
					oy = oy - tile.width
				end
			end

			local instance = {
				id    = batch:add(tile.quad, tileX, tileY, tileR, tile.sx * sx, tile.sy * sy, ox, oy),
				batch = batch,
				layer = layer,
				gid   = tile.gid,
				x     = tileX,
				y     = tileY - oy,
				r     = tileR,
				oy    = oy
			}

			self.tileInstances[tile.gid] = self.tileInstances[tile.gid] or {}
			table.insert(self.tileInstances[tile.gid], instance)
		end
	end

	layer.batches = batches
end

--- Create a Custom Layer to place userdata in (such as player sprites)
-- @param name Name of Custom Layer
-- @param index Draw order within Layer stack
-- @return table Custom Layer
function Map:addCustomLayer(name, index)
	index = index or #self.layers + 1
	local layer = {
      type       = "customlayer",
      name       = name,
      visible    = true,
      opacity    = 1,
      properties = {},
    }

	function layer.draw() end
	function layer.update() end

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
	layer.chunks   = nil
	layer.objects  = nil
	layer.image    = nil

	function layer.draw() end
	function layer.update() end

	return layer
end

--- Remove a Layer from the Layer stack
-- @param index Index or name of Layer to remove
function Map:removeLayer(index)
	local layer = assert(self.layers[index], "Layer not found: " .. index)

	if type(index) == "string" then
		for i, l in ipairs(self.layers) do
			if l.name == index then
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

	-- Remove layer batches
	if layer.batches then
		for _, batch in pairs(layer.batches) do
			self.freeBatchSprites[batch] = nil
		end
	end

	-- Remove chunk batches
	if layer.chunks then
		for _, chunk in ipairs(layer.chunks) do
			for _, batch in pairs(chunk.batches) do
				self.freeBatchSprites[batch] = nil
			end
		end
	end

	-- Remove tile instances
	if layer.type == "tilelayer" then
		for _, tiles in pairs(self.tileInstances) do
			for i = #tiles, 1, -1 do
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
function Map:update(dt)
	for _, tile in pairs(self.tiles) do
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
-- @param tx Translate on X
-- @param ty Translate on Y
-- @param sx Scale on X
-- @param sy Scale on Y
function Map:draw(tx, ty, sx, sy)
	local current_canvas = lg.getCanvas()
	lg.setCanvas(self.canvas)
	lg.clear()

	-- Scale map to 1.0 to draw onto canvas, this fixes tearing issues
	-- Map is translated to correct position so the right section is drawn
	lg.push()
	lg.origin()
	lg.translate(math.floor(tx or 0), math.floor(ty or 0))

	for _, layer in ipairs(self.layers) do
		if layer.visible and layer.opacity > 0 then
			self:drawLayer(layer)
		end
	end

	lg.pop()

	-- Draw canvas at 0,0; this fixes scissoring issues
	-- Map is scaled to correct scale so the right section is shown
	lg.push()
	lg.origin()
	lg.scale(sx or 1, sy or sx or 1)

	lg.setCanvas(current_canvas)
	lg.draw(self.canvas)

	lg.pop()
end

--- Draw an individual Layer
-- @param layer The Layer to draw
function Map.drawLayer(_, layer)
	local r,g,b,a = lg.getColor()
	lg.setColor(r, g, b, a * layer.opacity)
	layer:draw()
	lg.setColor(r,g,b,a)
end

--- Default draw function for Tile Layers
-- @param layer The Tile Layer to draw
function Map:drawTileLayer(layer)
	if type(layer) == "string" or type(layer) == "number" then
		layer = self.layers[layer]
	end

	assert(layer.type == "tilelayer", "Invalid layer type: " .. layer.type .. ". Layer must be of type: tilelayer")

	-- NOTE: This does not take into account any sort of draw range clipping and will always draw every chunk
	if layer.chunks then
		for _, chunk in ipairs(layer.chunks) do
			for _, batch in pairs(chunk.batches) do
				lg.draw(batch, 0, 0)
			end
		end

		return
	end

	for _, batch in pairs(layer.batches) do
		lg.draw(batch, floor(layer.x), floor(layer.y))
	end
end

--- Default draw function for Object Layers
-- @param layer The Object Layer to draw
function Map:drawObjectLayer(layer)
	if type(layer) == "string" or type(layer) == "number" then
		layer = self.layers[layer]
	end

	assert(layer.type == "objectgroup", "Invalid layer type: " .. layer.type .. ". Layer must be of type: objectgroup")

	local line  = { 160, 160, 160, 255 * layer.opacity       }
	local fill  = { 160, 160, 160, 255 * layer.opacity * 0.5 }
	local r,g,b,a = lg.getColor()
	local reset = {   r,   g,   b,   a * layer.opacity       }

	local function sortVertices(obj)
		local vertex = {}

		for _, v in ipairs(obj) do
			table.insert(vertex, v.x)
			table.insert(vertex, v.y)
		end

		return vertex
	end

	local function drawShape(obj, shape)
		local vertex = sortVertices(obj)

		if shape == "polyline" then
			lg.setColor(line)
			lg.line(vertex)
			return
		elseif shape == "polygon" then
			lg.setColor(fill)
			if not love.math.isConvex(vertex) then
				local triangles = love.math.triangulate(vertex)
				for _, triangle in ipairs(triangles) do
					lg.polygon("fill", triangle)
				end
			else
				lg.polygon("fill", vertex)
			end
		else
			lg.setColor(fill)
			lg.polygon("fill", vertex)
		end

		lg.setColor(line)
		lg.polygon("line", vertex)
	end

	for _, object in ipairs(layer.objects) do
		if object.visible then
			if object.shape == "rectangle" and not object.gid then
				drawShape(object.rectangle, "rectangle")
			elseif object.shape == "ellipse" then
				drawShape(object.ellipse, "ellipse")
			elseif object.shape == "polygon" then
				drawShape(object.polygon, "polygon")
			elseif object.shape == "polyline" then
				drawShape(object.polyline, "polyline")
			elseif object.shape == "point" then
				lg.points(object.x, object.y)
			end
		end
	end

	lg.setColor(reset)
	for _, batch in pairs(layer.batches) do
		lg.draw(batch, 0, 0)
	end
	lg.setColor(r,g,b,a)
end

--- Default draw function for Image Layers
-- @param layer The Image Layer to draw
function Map:drawImageLayer(layer)
	if type(layer) == "string" or type(layer) == "number" then
		layer = self.layers[layer]
	end

	assert(layer.type == "imagelayer", "Invalid layer type: " .. layer.type .. ". Layer must be of type: imagelayer")

	if layer.image ~= "" then
		lg.draw(layer.image, layer.x, layer.y)
	end
end

--- Resize the drawable area of the Map
-- @param w The new width of the drawable area (in pixels)
-- @param h The new Height of the drawable area (in pixels)
function Map:resize(w, h)
	if lg.isCreated then
		w = w or lg.getWidth()
		h = h or lg.getHeight()

		self.canvas = lg.newCanvas(w, h)
		self.canvas:setFilter("nearest", "nearest")
	end
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

	if not l then
		return {}
	end

	return l.properties
end

--- Get custom properties from Tile
-- @param layer The Layer that the Tile belongs to
-- @param x The X axis location of the Tile (in tiles)
-- @param y The Y axis location of the Tile (in tiles)
-- @return table List of properties
function Map:getTileProperties(layer, x, y)
	local tile = self.layers[layer].data[y][x]

	if not tile then
		return {}
	end

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

	if not o then
		return {}
	end

	return o.properties
end

--- Change a tile in a layer to another tile
-- @param layer The Layer that the Tile belongs to
-- @param x The X axis location of the Tile (in tiles)
-- @param y The Y axis location of the Tile (in tiles)
-- @param gid The gid of the new tile
function Map:setLayerTile(layer, x, y, gid)
	layer = self.layers[layer]

	layer.data[y] = layer.data[y] or {}
	local tile = layer.data[y][x]
	local instance
	if tile then
		local tileX, tileY = self:getLayerTilePosition(layer, tile, x, y)
		for _, inst in pairs(self.tileInstances[tile.gid]) do
			if inst.x == tileX and inst.y == tileY then
				instance = inst
				break
			end
		end
	end

	if tile == self.tiles[gid] then
		return
	end

	tile = self.tiles[gid]

	if instance then
		self:swapTile(instance, tile)
	else
		self:addNewLayerTile(layer, tile, x, y)
	end
	layer.data[y][x] = tile
end

--- Swap a tile in a spritebatch
-- @param instance The current Instance object we want to replace
-- @param tile The Tile object we want to use
-- @return none
function Map:swapTile(instance, tile)
	-- Update sprite batch
	if instance.batch then
		if tile then
			instance.batch:set(
				instance.id,
				tile.quad,
				instance.x,
				instance.y,
				tile.r,
				tile.sx,
				tile.sy
			)
		else
			instance.batch:set(
				instance.id,
				instance.x,
				instance.y,
				0,
				0)

			self.freeBatchSprites[instance.batch] = self.freeBatchSprites[instance.batch] or {}
			table.insert(self.freeBatchSprites[instance.batch], instance)
		end
	end

	-- Remove old tile instance
	for i, ins in ipairs(self.tileInstances[instance.gid]) do
		if ins.batch == instance.batch and ins.id == instance.id then
			table.remove(self.tileInstances[instance.gid], i)
			break
		end
	end

	-- Add new tile instance
	if tile then
		self.tileInstances[tile.gid] = self.tileInstances[tile.gid] or {}

		local freeBatchSprites = self.freeBatchSprites[instance.batch]
		local newInstance
		if freeBatchSprites and #freeBatchSprites > 0 then
			newInstance = freeBatchSprites[#freeBatchSprites]
			freeBatchSprites[#freeBatchSprites] = nil
		else
			newInstance = {}
		end

		newInstance.layer = instance.layer
		newInstance.batch = instance.batch
		newInstance.id    = instance.id
		newInstance.gid   = tile.gid or 0
		newInstance.x     = instance.x
		newInstance.y     = instance.y
		newInstance.r     = tile.r or 0
		newInstance.oy    = tile.r ~= 0 and tile.height or 0
		table.insert(self.tileInstances[tile.gid], newInstance)
	end
end

--- Convert tile location to pixel location
-- @param x The X axis location of the point (in tiles)
-- @param y The Y axis location of the point (in tiles)
-- @return number The X axis location of the point (in pixels)
-- @return number The Y axis location of the point (in pixels)
function Map:convertTileToPixel(x,y)
	if self.orientation == "orthogonal" then
		local tileW = self.tilewidth
		local tileH = self.tileheight
		return
			x * tileW,
			y * tileH
	elseif self.orientation == "isometric" then
		local mapH    = self.height
		local tileW   = self.tilewidth
		local tileH   = self.tileheight
		local offsetX = mapH * tileW / 2
		return
			(x - y) * tileW / 2 + offsetX,
			(x + y) * tileH / 2
	elseif self.orientation == "staggered" or
		self.orientation     == "hexagonal" then
		local tileW   = self.tilewidth
		local tileH   = self.tileheight
		local sideLen = self.hexsidelength or 0

		if self.staggeraxis == "x" then
			return
				x * tileW,
				ceil(y) * (tileH + sideLen) + (ceil(y) % 2 == 0 and tileH or 0)
		else
			return
				ceil(x) * (tileW + sideLen) + (ceil(x) % 2 == 0 and tileW or 0),
				y * tileH
		end
	end
end

--- Convert pixel location to tile location
-- @param x The X axis location of the point (in pixels)
-- @param y The Y axis location of the point (in pixels)
-- @return number The X axis location of the point (in tiles)
-- @return number The Y axis location of the point (in tiles)
function Map:convertPixelToTile(x, y)
	if self.orientation == "orthogonal" then
		local tileW = self.tilewidth
		local tileH = self.tileheight
		return
			x / tileW,
			y / tileH
	elseif self.orientation == "isometric" then
		local mapH    = self.height
		local tileW   = self.tilewidth
		local tileH   = self.tileheight
		local offsetX = mapH * tileW / 2
		return
			y / tileH + (x - offsetX) / tileW,
			y / tileH - (x - offsetX) / tileW
	elseif self.orientation == "staggered" then
		local staggerX = self.staggeraxis  == "x"
		local even     = self.staggerindex == "even"

		local function topLeft(x, y)
			if staggerX then
				if ceil(x) % 2 == 1 and even then
					return x - 1, y
				else
					return x - 1, y - 1
				end
			else
				if ceil(y) % 2 == 1 and even then
					return x, y - 1
				else
					return x - 1, y - 1
				end
			end
		end

		local function topRight(x, y)
			if staggerX then
				if ceil(x) % 2 == 1 and even then
					return x + 1, y
				else
					return x + 1, y - 1
				end
			else
				if ceil(y) % 2 == 1 and even then
					return x + 1, y - 1
				else
					return x, y - 1
				end
			end
		end

		local function bottomLeft(x, y)
			if staggerX then
				if ceil(x) % 2 == 1 and even then
					return x - 1, y + 1
				else
					return x - 1, y
				end
			else
				if ceil(y) % 2 == 1 and even then
					return x, y + 1
				else
					return x - 1, y + 1
				end
			end
		end

		local function bottomRight(x, y)
			if staggerX then
				if ceil(x) % 2 == 1 and even then
					return x + 1, y + 1
				else
					return x + 1, y
				end
			else
				if ceil(y) % 2 == 1 and even then
					return x + 1, y + 1
				else
					return x, y + 1
				end
			end
		end

		local tileW = self.tilewidth
		local tileH = self.tileheight

		if staggerX then
			x = x - (even and tileW / 2 or 0)
		else
			y = y - (even and tileH / 2 or 0)
		end

		local halfH      = tileH / 2
		local ratio      = tileH / tileW
		local referenceX = ceil(x / tileW)
		local referenceY = ceil(y / tileH)
		local relativeX  = x - referenceX * tileW
		local relativeY  = y - referenceY * tileH

		if (halfH - relativeX * ratio > relativeY) then
			return topLeft(referenceX, referenceY)
		elseif (-halfH + relativeX * ratio > relativeY) then
			return topRight(referenceX, referenceY)
		elseif (halfH + relativeX * ratio < relativeY) then
			return bottomLeft(referenceX, referenceY)
		elseif (halfH * 3 - relativeX * ratio < relativeY) then
			return bottomRight(referenceX, referenceY)
		end

		return referenceX, referenceY
	elseif self.orientation == "hexagonal" then
		local staggerX  = self.staggeraxis  == "x"
		local even      = self.staggerindex == "even"
		local tileW     = self.tilewidth
		local tileH     = self.tileheight
		local sideLenX  = 0
		local sideLenY  = 0

		local colW       = tileW / 2
		local rowH       = tileH / 2
		if staggerX then
			sideLenX = self.hexsidelength
			x = x - (even and tileW or (tileW - sideLenX) / 2)
			colW = colW - (colW  - sideLenX / 2) / 2
		else
			sideLenY = self.hexsidelength
			y = y - (even and tileH or (tileH - sideLenY) / 2)
			rowH = rowH - (rowH  - sideLenY / 2) / 2
		end

		local referenceX = ceil(x) / (colW * 2)
		local referenceY = ceil(y) / (rowH * 2)

    -- If in staggered line, then shift reference by 0.5 of other axes
		if staggerX then
			if (floor(referenceX) % 2 == 0) == even then
				referenceY = referenceY - 0.5
			end
		else
			if (floor(referenceY) % 2 == 0) == even then
				referenceX = referenceX - 0.5
			end
		end

		local relativeX  = x - referenceX * colW * 2
		local relativeY  = y - referenceY * rowH * 2
		local centers

		if staggerX then
			local left    = sideLenX / 2
			local centerX = left + colW
			local centerY = tileH / 2

			centers = {
				{ x = left,           y = centerY        },
				{ x = centerX,        y = centerY - rowH },
				{ x = centerX,        y = centerY + rowH },
				{ x = centerX + colW, y = centerY        },
			}
		else
			local top     = sideLenY / 2
			local centerX = tileW / 2
			local centerY = top + rowH

			centers = {
				{ x = centerX,        y = top },
				{ x = centerX - colW, y = centerY },
				{ x = centerX + colW, y = centerY },
				{ x = centerX,        y = centerY + rowH }
			}
		end

		local nearest = 0
		local minDist = math.huge

		local function len2(ax, ay)
			return ax * ax + ay * ay
		end

		for i = 1, 4 do
			local dc = len2(centers[i].x - relativeX, centers[i].y - relativeY)

			if dc < minDist then
				minDist = dc
				nearest = i
			end
		end

		local offsetsStaggerX = {
			{ x = 1, y =  1 },
			{ x = 2, y =  0 },
			{ x = 2, y =  1 },
			{ x = 3, y =  1 },
		}

		local offsetsStaggerY = {
			{ x =  1, y = 1 },
			{ x =  0, y = 2 },
			{ x =  1, y = 2 },
			{ x =  1, y = 3 },
		}

		local offsets = staggerX and offsetsStaggerX or offsetsStaggerY

		return
			referenceX + offsets[nearest].x,
			referenceY + offsets[nearest].y
	end
end

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

--- A list of no-longer-used batch sprites, indexed by batch
--@table Map.freeBatchSprites

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
-- @field data A tileWo dimensional table filled with individual tiles indexed by [y][x] (in tiles)
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
--			image = lg.newImage("assets/sprites/player.png"),
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
--			lg.draw(sprite.image, x, y, r)
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

return setmetatable({}, STI)
