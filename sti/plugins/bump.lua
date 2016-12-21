--- Bump.lua plugin for STI
-- @module bump.lua
-- @author David Serrano (BobbyJones|FrenchFryLord)
-- @copyright 2016
-- @license MIT/X11

return {

	bump_LICENSE        = "MIT/X11",
	bump_URL            = "https://github.com/karai17/Simple-Tiled-Implementation",
	bump_VERSION        = "3.1.5.3",
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
				if tile.properties and tile.properties.collidable == true and map.tileInstances[gid] then
					for _, instance in ipairs(map.tileInstances[gid]) do
						local colBox = false
						if tile.objectGroup and tile.objectGroup.objects then
							for _, object in ipairs(tile.objectGroup.objects) do
								if object.type == 'colBox' then
									colBox = true
									local t = {}
									t.properties = tile.properties
									t.x = instance.x + map.offsetx + object.x
									t.y = instance.y + map.offsety + object.y
									t.width = object.width
									t.height = object.height
									t.layer = instance.layer
									world:add(t, t.x, t.y, object.width, object.height)
									table.insert(collidables, t)
								end
							end
						end
						if colBox == false then
							local t = { properties = tile.properties, x = instance.x + map.offsetx, y = instance.y + map.offsety, width = map.tilewidth, height = map.tileheight, layer = instance.layer }
							world:add(t,  t.x,t.y, t.width,t.height)
							table.insert(collidables,t)
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
							local colBox = false
							if tile.objectGroup and tile.objectGroup.objects then
								for _, object in ipairs(tile.objectGroup.objects) do
									if object.type == 'colBox' then
										colBox = true
										local t = {}
										t.properties = tile.properties
										t.x = ((x-1) * map.tilewidth + tile.offset.x + map.offsetx) + object.x
										t.y = ((y-1) * map.tileheight + tile.offset.y + map.offsety) + object.y
										t.width = object.width
										t.height = object.height
										t.layer = layer
										world:add(t, t.x, t.y, object.width, object.height)
										table.insert(collidables, t)
									end
								end
							end
							if colBox == false then
								local t = {properties = tile.properties, x = (x - 1) * map.tilewidth + tile.offset.x + map.offsetx, y = (y - 1) * map.tileheight + tile.offset.y + map.offsety, width = tile.width, height = tile.height, layer = layer }
								world:add(t, t.x,t.y, t.width,t.height )
								table.insert(collidables,t)
							end
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
					if (layer.properties and layer.properties.collidable == true)
					  or (obj.properties and obj.properties.collidable == true) then
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
	-- @param index to layer to be removed
	-- @param world bump world the holds the tiles
	-- @return nil
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
	-- @return nil
	bump_draw = function(map, world)
		for k,collidable in pairs(map.bump_collidables) do
			love.graphics.rectangle("line",world:getRect(collidable))
		end
	end
}
