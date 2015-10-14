--- Bump.lua plugin for STI
-- @module bump.lua
-- @author David Serrano (BobbyJones|FrenchFryLord)
-- @copyright 2015
-- @license MIT/X11

return {

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
						local t = {properties = tile.properties, x = instance.x, y = instance.y, width = map.tilewidth, height = map.tileheight}
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
							local t = {properties = tile.properties, x = x * map.tilewidth + tile.offset.x, y = y * map.tileheight + tile.offset.y, width = tile.width, height = tile.height }
							world:add(t, t.x,t.y, t.width,t.height )
							table.insert(collidables,t)
							
						end
					end
				elseif layer.type == "imagelayer" then
					local t = { properties = layer.properties, x = x or 0, y = y or 0, width = layer.width, height = layer.height }
					world:add(layer, t.x,t.y, t.width,t.height)
					table.insert(collidables,t)
				end
			end
		end
		map.bump_collidables = collidables
	end,

	--- Draw bump collisions world.
	-- @param world bump world.
	-- @return nil
	bump_draw = function(map, world)
		for k,collidable in pairs(map.bump_collidables) do
			love.graphics.rectangle("line",world:getRect(collidable))
		end
	end
}

