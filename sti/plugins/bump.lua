--- Bump.lua plugin for STI
-- @module bump.lua
-- @author David Serrano (BobbyJones|FrenchFryLord)
-- @copyright 2019
-- @license MIT/X11

local lg = require((...):gsub('plugins.bump', 'graphics'))

return {
	bump_LICENSE        = "MIT/X11",
	bump_URL            = "https://github.com/karai17/Simple-Tiled-Implementation",
	bump_VERSION        = "3.1.7.0",
	bump_DESCRIPTION    = "Bump hooks for STI.",

	--- Adds each collidable tile to the Bump world.
	-- @param world The Bump world to add objects to.
	-- @return collidables table containing the handles to the objects in the Bump world.
	bump_init = function(map, world)
		local collidables = {}

		for _, tileset in ipairs(map.tilesets) do
			for _, tile in ipairs(tileset.tiles) do
				local gid = tileset.firstgid + tile.id

				if map.tileInstances[gid] then
					for _, instance in ipairs(map.tileInstances[gid]) do
						-- Every object in every instance of a tile
						if tile.objectGroup then
							for _, object in ipairs(tile.objectGroup.objects) do
								if object.properties.collidable == true then
									local t = {
										name       = object.name,
										type       = object.type,
										x          = instance.x + map.offsetx + object.x,
										y          = instance.y + map.offsety + object.y,
										width      = object.width,
										height     = object.height,
										layer      = instance.layer,
										properties = object.properties

									}

									world:add(t, t.x, t.y, t.width, t.height)
									table.insert(collidables, t)
								end
							end
						end

						-- Every instance of a tile
						if tile.properties and tile.properties.collidable == true then
							local t = {
								x          = instance.x + map.offsetx,
								y          = instance.y + map.offsety,
								width      = map.tilewidth,
								height     = map.tileheight,
								layer      = instance.layer,
								properties = tile.properties
							}

							world:add(t, t.x, t.y, t.width, t.height)
							table.insert(collidables, t)
						end
					end
				end
			end
		end

		for _, layer in ipairs(map.layers) do
			-- Entire layer
			if layer.properties.collidable == true then
				if layer.type == "tilelayer" then
					for y, tiles in ipairs(layer.data) do
						for x, tile in pairs(tiles) do

							if tile.objectGroup then
								for _, object in ipairs(tile.objectGroup.objects) do
									if object.properties.collidable == true then
										local t = {
											name       = object.name,
											type       = object.type,
											x          = ((x-1) * map.tilewidth  + tile.offset.x + map.offsetx) + object.x,
											y          = ((y-1) * map.tileheight + tile.offset.y + map.offsety) + object.y,
											width      = object.width,
											height     = object.height,
											layer      = layer,
											properties = object.properties
										}

										world:add(t, t.x, t.y, t.width, t.height)
										table.insert(collidables, t)
									end
								end
							end


							local t = {
								x          = (x-1) * map.tilewidth  + tile.offset.x + map.offsetx,
								y          = (y-1) * map.tileheight + tile.offset.y + map.offsety,
								width      = tile.width,
								height     = tile.height,
								layer      = layer,
								properties = tile.properties
							}

							world:add(t, t.x, t.y, t.width, t.height)
							table.insert(collidables, t)
						end
					end
				elseif layer.type == "imagelayer" then
					world:add(layer, layer.x, layer.y, layer.width, layer.height)
					table.insert(collidables, layer)
				end
		  end

			-- individual collidable objects in a layer that is not "collidable"
			-- or whole collidable objects layer
		  if layer.type == "objectgroup" then
				for _, obj in ipairs(layer.objects) do
					if layer.properties.collidable == true or obj.properties.collidable == true then
						if obj.shape == "rectangle" then
							local t = {
								name       = obj.name,
								type       = obj.type,
								x          = obj.x + map.offsetx,
								y          = obj.y + map.offsety,
								width      = obj.width,
								height     = obj.height,
								layer      = layer,
								properties = obj.properties
							}

							if obj.gid then
								t.y = t.y - obj.height
							end

							world:add(t, t.x, t.y, t.width, t.height)
							table.insert(collidables, t)
						end -- TODO implement other object shapes?
					end
				end
			end

		end
		map.bump_collidables = collidables
	end,

	--- Remove layer
	-- @param index to layer to be removed
	-- @param world bump world the holds the tiles
	-- @param tx Translate on X
-- @param ty Translate on Y
-- @param sx Scale on X
-- @param sy Scale on Y
	bump_removeLayer = function(map, index, world)
		local layer = assert(map.layers[index], "Layer not found: " .. index)
		local collidables = map.bump_collidables

		-- Remove collision objects
		for i = #collidables, 1, -1 do
			local obj = collidables[i]

			if obj.layer == layer
			and (
				layer.properties.collidable == true
				or obj.properties.collidable == true
			) then
				world:remove(obj)
				table.remove(collidables, i)
			end
		end
	end,

	--- Draw bump collisions world.
	-- @param world bump world holding the tiles geometry
	-- @param tx Translate on X
	-- @param ty Translate on Y
	-- @param sx Scale on X
	-- @param sy Scale on Y
	bump_draw = function(map, world, tx, ty, sx, sy)
		lg.push()
		lg.scale(sx or 1, sy or sx or 1)
		lg.translate(math.floor(tx or 0), math.floor(ty or 0))

		for _, collidable in pairs(map.bump_collidables) do
			lg.rectangle("line", world:getRect(collidable))
		end

		lg.pop()
	end
}

--- Custom Properties in Tiled are used to tell this plugin what to do.
-- @table Properties
-- @field collidable set to true, can be used on any Layer, Tile, or Object
