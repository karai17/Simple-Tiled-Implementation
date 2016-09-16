--- Box2D plugin for STI
-- @module box2d
-- @author Landon Manning
-- @copyright 2016
-- @license MIT/X11

local path  = ...
local utils = require(path .. "utils")

return {
	box2d_LICENSE     = "MIT/X11",
	box2d_URL         = "https://github.com/karai17/Simple-Tiled-Implementation",
	box2d_VERSION     = "2.3.2.3",
	box2d_DESCRIPTION = "Box2D hooks for STI.",

	--- Initialize Box2D physics world.
	-- @param world The Box2D world to add objects to.
	-- @return nil
	box2d_init = function(map, world)
		assert(love.physics, "To use the Box2D plugin, please enable the love.physics module.")

		local body      = love.physics.newBody(world, map.offsetx, map.offsety)
		local collision = {
			body = body,
		}

		local function addObjectToWorld(objshape, vertices, userdata, object)
			local shape

			if objshape == "polyline" then
				if #vertices == 4 then
					shape = love.physics.newEdgeShape(unpack(vertices))
				else
					shape = love.physics.newChainShape(false, unpack(vertices))
				end
			else
				shape = love.physics.newPolygonShape(unpack(vertices))
			end

			local fixture = love.physics.newFixture(body, shape)

			fixture:setUserData(userdata)

			if userdata.properties.sensor == true then
				fixture:setSensor(true)
			end

			local obj = {
				object  = object,
				shape   = shape,
				fixture = fixture,
			}

			table.insert(collision, obj)
		end

		local function getPolygonVertices(object)
			local vertices = {}
			for _, vertex in ipairs(object.polygon) do
				table.insert(vertices, vertex.x)
				table.insert(vertices, vertex.y)
			end

			return vertices
		end

		local function calculateObjectPosition(object, tile)
			local o = {
				shape   = object.shape,
				x       = object.dx or object.x,
				y       = object.dy or object.y,
				w       = object.width,
				h       = object.height,
				polygon = object.polygon or object.polyline or object.ellipse or object.rectangle
			}

			local userdata = {
				object     = o,
				properties = object.properties
			}

			if o.shape == "rectangle" then
				o.r       = object.rotation or 0
				local cos = math.cos(math.rad(o.r))
				local sin = math.sin(math.rad(o.r))
				local oy  = 0

				if object.gid then
					local tileset = map.tilesets[map.tiles[object.gid].tileset]
					local lid     = object.gid - tileset.firstgid
					local tile    = {}

					-- This fixes a height issue
					 o.y = o.y + map.tiles[object.gid].offset.y
					 oy  = tileset.tileheight

					for _, t in ipairs(tileset.tiles) do
						if t.id == lid then
							tile = t
							break
						end
					end

					if tile.objectGroup then
						for _, obj in ipairs(tile.objectGroup.objects) do
							-- Every object in the tile
							calculateObjectPosition(obj, object)
						end

						return
					else
						o.w = map.tiles[object.gid].width
						o.h = map.tiles[object.gid].height
					end
				end

				o.polygon = {
					{ x=o.x+0,   y=o.y+0   },
					{ x=o.x+o.w, y=o.y+0   },
					{ x=o.x+o.w, y=o.y+o.h },
					{ x=o.x+0,   y=o.y+o.h }
				}

				for _, vertex in ipairs(o.polygon) do
					vertex.x, vertex.y = utils.rotate_vertex(map, vertex, o.x, o.y, cos, sin, oy)
				end

				local vertices = getPolygonVertices(o)
				addObjectToWorld(o.shape, vertices, userdata, tile or object)
			elseif o.shape == "ellipse" then
				if not o.polygon then
					o.polygon = utils.convert_ellipse_to_polygon(o.x, o.y, o.w, o.h)
				end
				local vertices  = getPolygonVertices(o)
				local triangles = love.math.triangulate(vertices)

				for _, triangle in ipairs(triangles) do
					addObjectToWorld(o.shape, triangle, userdata, tile or object)
				end
			elseif o.shape == "polygon" then
				local vertices  = getPolygonVertices(o)
				local triangles = love.math.triangulate(vertices)

				for _, triangle in ipairs(triangles) do
					addObjectToWorld(o.shape, triangle, userdata, tile or object)
				end
			elseif o.shape == "polyline" then
				local vertices = getPolygonVertices(o)
				addObjectToWorld(o.shape, vertices, userdata, tile or object)
			end
		end

		for _, tile in pairs(map.tiles) do
			local tileset = map.tilesets[tile.tileset]

			-- Every object in every instance of a tile
			if tile.objectGroup then
				if map.tileInstances[tile.gid] then
					for _, instance in ipairs(map.tileInstances[tile.gid]) do
						for _, object in ipairs(tile.objectGroup.objects) do
							object.dx = object.x + instance.x
							object.dy = object.y + instance.y
							calculateObjectPosition(object, instance)
						end
					end
				end

			-- Every instance of a tile
			elseif tile.properties and tile.properties.collidable == true and map.tileInstances[tile.gid] then
				for _, instance in ipairs(map.tileInstances[tile.gid]) do
					local object = {
						shape      = "rectangle",
						x          = instance.x,
						y          = instance.y,
						width      = tileset.tilewidth,
						height     = tileset.tileheight,
						properties = tile.properties
					}

					calculateObjectPosition(object, instance)
				end
			end
		end

		for _, layer in ipairs(map.layers) do
			-- Entire layer
			if layer.properties.collidable == true then
				if layer.type == "tilelayer" then
					for gid, tiles in pairs(map.tileInstances) do
						local tile = map.tiles[gid]
						local tileset = map.tilesets[tile.tileset]

						for _, instance in ipairs(tiles) do
							if instance.layer == layer then
								local object = {
									shape      = "rectangle",
									x          = instance.x,
									y          = instance.y,
									width      = tileset.tilewidth,
									height     = tileset.tileheight,
									properties = tile.properties
								}

								calculateObjectPosition(object, instance)
							end
						end
					end
				elseif layer.type == "objectgroup" then
					for _, object in ipairs(layer.objects) do
						calculateObjectPosition(object)
					end
				elseif layer.type == "imagelayer" then
					local object = {
						shape      = "rectangle",
						x          = layer.x or 0,
						y          = layer.y or 0,
						width      = layer.width,
						height     = layer.height,
						properties = layer.properties
					}

					calculateObjectPosition(object)
				end
			end

			-- Individual objects
			if layer.type == "objectgroup" then
				for _, object in ipairs(layer.objects) do
					if object.properties.collidable == true then
						calculateObjectPosition(object)
					end
				end
			end
		end

		map.box2d_collision = collision
	end,

	--- Remove Box2D fixtures and shapes from world.
	-- @param index The index or name of the layer being removed
	-- @return nil
	box2d_removeLayer = function(map, index)
		local layer = assert(map.layers[index], "Layer not found: " .. index)
		local collision = map.box2d_collision

		-- Remove collision objects
		for i = #collision, 1, -1 do
			local obj = collision[i]

			if obj.object.layer == layer then
				obj.fixture:destroy()
				table.remove(collision, i)
			end
		end
	end,

	--- Draw Box2D physics world.
	-- @return nil
	box2d_draw = function(map)
		local collision = map.box2d_collision

		for _, obj in ipairs(collision) do
			local points = {collision.body:getWorldPoints(obj.shape:getPoints())}
			local shape_type = obj.shape:getType()

			if shape_type == "edge" or shape_type == "chain" then
				love.graphics.line(points)
			elseif shape_type == "polygon" then
				love.graphics.polygon("line", points)
			else
				error("sti box2d plugin does not support "..shape_type.." shapes")
			end
		end
	end,
}

--- Custom Properties in Tiled are used to tell this plugin what to do.
-- @table Properties
-- @field collidable set to true, can be used on any Layer, Tile, or Object
-- @field sensor set to true, can be used on any Tile or Object that is also collidable
