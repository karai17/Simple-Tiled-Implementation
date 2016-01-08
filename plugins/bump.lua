--- Bump.lua plugin for STI
-- @module bump.lua
-- @author David Serrano (BobbyJones|FrenchFryLord)
-- @copyright 2016
-- @license MIT/X11

return {

	bump_LICENSE        = "MIT/X11",
	bump_URL            = "https://github.com/karai17/Simple-Tiled-Implementation",
	bump_VERSION        = "3.1.5.2",
	bump_DESCRIPTION    = "Bump hooks for STI.",


	--- Adds each collidable tile to the Bump world.
	-- @param world The Bump world to add objects to.
	-- @return collidables table containing the handles to the objects in the Bump world.
	bump_init = function(map, world)

		local collidables = {}

		for _, tileset in ipairs(map.tilesets) do
			for _, tile in ipairs(tileset.tiles) do
				local gid = tileset.firstgid + tile.id
				-- Every object in every instance of a tile
				if tile.properties and tile.properties.collidable == "true" and map.tileInstances[gid] then
					for _, instance in ipairs(map.tileInstances[gid]) do
						local t = {properties = tile.properties, x = instance.x + map.offsetx, y = instance.y + map.offsety, width = map.tilewidth, height = map.tileheight, layer = instance.layer }
						world:add(t,  t.x,t.y, t.width,t.height)
						table.insert(collidables,t)
					end
				end
			end
		end

		for _, layer in ipairs(map.layers) do
			-- Entire layer
			if layer.properties.collidable == "true" then
				if layer.type == "tilelayer" then
					for y, tiles in ipairs(layer.data) do
						for x, tile in pairs(tiles) do
							local t = {properties = tile.properties, x = x * map.tilewidth + tile.offset.x + map.offsetx, y = y * map.tileheight + tile.offset.y + map.offsety, width = tile.width, height = tile.height, layer = layer }
							world:add(t, t.x,t.y, t.width,t.height )
							table.insert(collidables,t)
						end
					end
				elseif layer.type == "imagelayer" then
					world:add(layer, layer.x,layer.y, layer.width,layer.height)
					table.insert(collidables,layer)
				end
		  end
			-- individual collidable objects in a layer that is not "collidable"
			-- or whole collidable objects layer
		  if layer.type == "objectgroup" then
				for _, obj in ipairs(layer.objects) do
					if (layer.properties and layer.properties.collidable == "true")
					  or (obj.properties and obj.properties.collidable == "true") then
							if obj.shape == "rectangle" then
								local t = {properties = obj.properties, x = obj.x, y = obj.y, width = obj.width, height = obj.height, type = obj.type, name = obj.name, id = obj.id, gid = obj.gid, layer = layer }
								if obj.gid then t.y = t.y - obj.height end
								world:add(t, t.x,t.y, t.width,t.height )
								table.insert(collidables,t)
							end -- TODO implement other object shapes?
					end
				end
  		end

		end
		map.bump_collidables = collidables
	end,

	--- Remove layer
	-- @params index to layer to be removed
	-- @params world bump world the holds the tiles
	-- @return nil
	bump_removeLayer = function(map, index, world)
		local layer = assert(map.layers[index], "Layer not found: " .. index)
		local collidables = map.bump_collidables

		-- Remove collision objects
		for i=#collidables, 1, -1 do
			local obj = collidables[i]

			if obj.layer == layer
			and (
				layer.properties.collidable == "true"
				or obj.properties.collidable == "true"
			) then
				world:remove(obj)
				table.remove(collidables, i)
			end
		end
	end,

	--- Draw bump collisions world.
	-- @params world bump world holding the tiles geometry
	-- @return nil
	bump_draw = function(map, world)
		for k,collidable in pairs(map.bump_collidables) do
			love.graphics.rectangle("line",world:getRect(collidable))
		end
	end
}
