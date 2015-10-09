--- Box2D plugin for STI
-- @module box2d
-- @author Landon Manning
-- @copyright 2015
-- @license MIT/X11

return {
	box2d_LICENSE     = "MIT/X11",
	box2d_URL         = "https://github.com/karai17/Simple-Tiled-Implementation",
	box2d_VERSION     = "2.3.0.1",
	box2d_DESCRIPTION = "Box2D hooks for STI.",

	--- Initialize Box2D physics world.
	-- @param world The Box2D world to add objects to.
	-- @return table List of collision objects
	box2d_init = function(map, world)
		assert(love.physics, "To use the built-in collision system, please enable the physics module.")

		local body      = love.physics.newBody(world)
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

		local function addObjectToWorld(objshape, vertices, userdata)
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
				shape   = shape,
				fixture = fixture,
			}

			table.insert(collision, obj)
		end

		local function getPolygonVertices(object, tile, precalc)
			local ox, oy = 0, 0

			if not precalc then
				ox = object.x
				oy = object.y
			end

			local vertices = {}
			for _, vertex in ipairs(object.polygon) do
				table.insert(vertices, tile.x + ox + vertex.x)
				table.insert(vertices, tile.y + oy + vertex.y)
			end

			return vertices
		end

		local function calculateObjectPosition(object, tile)
			local o = {
				shape   = object.shape,
				x       = object.x,
				y       = object.y,
				w       = object.width,
				h       = object.height,
				polygon = object.polygon or object.polyline or object.ellipse or object.rectangle
			}

			local t = {
				x = tile and tile.x or 0,
				y = tile and tile.y or 0
			}

			local userdata = {
				object     = o,
				instance   = t,
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
					{ x=o.x,       y=o.y       },
					{ x=o.x + o.w, y=o.y       },
					{ x=o.x + o.w, y=o.y + o.h },
					{ x=o.x,       y=o.y + o.h },
				}

				for _, vertex in ipairs(o.polygon) do
					if map.orientation == "isometric" then
						vertex.x, vertex.y = map:convertIsometricToScreen(vertex.x, vertex.y)
					end

					vertex.x, vertex.y = rotateVertex(vertex, o.x, o.y, cos, sin, oy)
				end

				local vertices = getPolygonVertices(o, t, true)
				addObjectToWorld(o.shape, vertices, userdata)
			elseif o.shape == "ellipse" then
				if not o.polygon then
					o.polygon = convertEllipseToPolygon(o.x, o.y, o.w, o.h)
				end
				local vertices  = getPolygonVertices(o, t, true)
				local triangles = love.math.triangulate(vertices)

				for _, triangle in ipairs(triangles) do
					addObjectToWorld(o.shape, triangle, userdata)
				end
			elseif o.shape == "polygon" then
				local precalc = false
				if not t.gid then precalc = true end

				local vertices  = getPolygonVertices(o, t, precalc)
				local triangles = love.math.triangulate(vertices)

				for _, triangle in ipairs(triangles) do
					addObjectToWorld(o.shape, triangle, userdata)
				end
			elseif o.shape == "polyline" then
				local precalc = false
				if not t.gid then precalc = true end

				local vertices	= getPolygonVertices(o, t, precalc)
				addObjectToWorld(o.shape, vertices, userdata)
			end
		end

		for _, tile in pairs(map.tiles) do
			local tileset = map.tilesets[tile.tileset]

			-- Every object in every instance of a tile
			if tile.objectGroup then
				if map.tileInstances[tile.gid] then
					for _, instance in ipairs(map.tileInstances[tile.gid]) do
						for _, object in ipairs(tile.objectGroup.objects) do
							calculateObjectPosition(object, instance)
						end
					end
				end

			-- Every instance of a tile
			elseif tile.properties and tile.properties.collidable == "true" and map.tileInstances[tile.gid] then
				for _, instance in ipairs(map.tileInstances[tile.gid]) do
					local object = {
						shape      = "rectangle",
						x          = 0,
						y          = 0,
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
					for y, tiles in ipairs(layer.data) do
						for x, tile in pairs(tiles) do
							local object = {
								shape      = "rectangle",
								x          = x * map.tilewidth + tile.offset.x,
								y          = y * map.tileheight + tile.offset.y,
								width      = tile.width,
								height     = tile.height,
								properties = tile.properties
							}

							calculateObjectPosition(object)
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

		return collision
	end,

	--- Draw Box2D physics world.
	-- @param collision A list of collision objects.
	-- @return nil
	box2d_draw = function(map, collision)
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
