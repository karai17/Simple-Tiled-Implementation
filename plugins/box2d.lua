--- Box2D plugin for STI
-- @module box2d
-- @author Landon Manning
-- @copyright 2015
-- @license MIT/X11

return {
	box2d_LICENSE     = "MIT/X11",
	box2d_URL         = "https://github.com/karai17/Simple-Tiled-Implementation",
	box2d_VERSION     = "2.3.2.1",
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

		local function rotateVertex(v, x, y, cos, sin, oy)
			oy = oy or 0

			local vertex = {
				x = v.x,
				y = v.y - oy,
			}

			vertex.x = vertex.x - x
			vertex.y = vertex.y - y

			local vx = cos * vertex.x - sin * vertex.y
			local vy = sin * vertex.x + cos * vertex.y

			return vx + x, vy + y + oy
		end

		local function addObjectToWorld(objshape, vertices, userdata, object)
			local shape

			if objshape == "polyline" then
				shape = love.physics.newChainShape(false, unpack(vertices))
			else
				shape = love.physics.newPolygonShape(unpack(vertices))
			end

			local fixture = love.physics.newFixture(body, shape)

			fixture:setUserData(userdata)

			if userdata.properties.sensor == "true" then
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
				table.insert(vertices, vertex.x + object.x)
				table.insert(vertices, vertex.y + object.y)
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
					{ x=0,   y=0   },
					{ x=o.w, y=0   },
					{ x=o.w, y=o.h },
					{ x=0,   y=o.h },
				}

				for _, vertex in ipairs(o.polygon) do
					if map.orientation == "isometric" then
						vertex.x, vertex.y = map:convertIsometricToScreen(vertex.x, vertex.y)
					end

					vertex.x, vertex.y = rotateVertex(vertex, o.x, o.y, cos, sin, oy)
				end

				local vertices = getPolygonVertices(o)
				addObjectToWorld(o.shape, vertices, userdata, tile or object)
			elseif o.shape == "ellipse" then
				if not o.polygon then
					o.polygon = convertEllipseToPolygon(o.x, o.y, o.w, o.h)
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
			elseif tile.properties and tile.properties.collidable == "true" and map.tileInstances[tile.gid] then
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
			if layer.properties.collidable == "true" then
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
					if object.properties.collidable == "true" then
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
		for i=#collision, 1, -1 do
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

			if #points == 4 then
				love.graphics.line(points)
			else
				love.graphics.polygon("line", points)
			end
		end
	end,
}

--- Custom Properties in Tiled are used to tell this plugin what to do.
-- @table Properties
-- @field collidable set to "true", can be used on any Layer, Tile, or Object
-- @field sensor set to "true", can be used on any Tile or Object that is also collidable
