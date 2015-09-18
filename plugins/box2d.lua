--- Box2D plugin for STI
-- @module box2d
-- @usage Create a custom property named "collidable" in any layer, tile, or object with the value set to "true".

return {
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

		local function addObjectToWorld(objshape, vertices, userdata)
			local shape

			if objshape == "polyline" then
				shape = love.physics.newChainShape(false, unpack(vertices))
			else
				shape = love.physics.newPolygonShape(unpack(vertices))
			end

			local fixture = love.physics.newFixture(body, shape)

			fixture:setUserData(userdata)

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

			local t = tile or { x=0, y=0 }

			local userdata = {
				object   = o,
				instance = t,
				tile     = t.gid and map.tiles[t.gid]
			}

			if o.shape == "rectangle" then
				o.r       = object.rotation or 0
				local cos = math.cos(math.rad(o.r))
				local sin = math.sin(math.rad(o.r))

				if object.gid then
					local tileset = map.tiles[object.gid].tileset
					local lid     = object.gid - map.tilesets[tileset].firstgid
					local tile    = {}

					-- This fixes a height issue
					 o.y = o.y + map.tiles[object.gid].offset.y

					for _, t in ipairs(map.tilesets[tileset].tiles) do
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

					vertex.x, vertex.y = rotateVertex(vertex, o.x, o.y, cos, sin)
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

		for _, tileset in ipairs(map.tilesets) do
			for _, tile in ipairs(tileset.tiles) do
				local gid = tileset.firstgid + tile.id

				if tile.objectGroup then
					if map.tileInstances[gid] then
						for _, instance in ipairs(map.tileInstances[gid]) do
							for _, object in ipairs(tile.objectGroup.objects) do
								-- Every object in every instance of a tile
								calculateObjectPosition(object, instance)
							end
						end
					end
				elseif tile.properties and tile.properties.collidable == "true" and map.tileInstances[gid] then
					for _, instance in ipairs(map.tileInstances[gid]) do
						-- Every instance of a tile
						local object = {
							shape  = "rectangle",
							x      = 0,
							y      = 0,
							width  = tileset.tilewidth,
							height = tileset.tileheight,
						}

						calculateObjectPosition(object, instance)
					end
				end
			end
		end

		for _, layer in ipairs(map.layers) do
			if layer.properties.collidable == "true" then
				-- Entire layer
				if layer.type == "tilelayer" then
					for y, tiles in ipairs(layer.data) do
						for x, tile in pairs(tiles) do
							local object = {
								shape  = "rectangle",
								x      = x * map.tilewidth + tile.offset.x,
								y      = y * map.tileheight + tile.offset.y,
								width  = tile.width,
								height = tile.height,
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
						shape  = "rectangle",
						x      = layer.x or 0,
						y      = layer.y or 0,
						width  = layer.width,
						height = layer.height,
					}
					calculateObjectPosition(object)
				end
			end

			if layer.type == "objectgroup" then
				for _, object in ipairs(layer.objects) do
					if object.properties.collidable == "true" then
						-- Individual objects
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
			love.graphics.polygon("line", collision.body:getWorldPoints(obj.shape:getPoints()))
		end
	end,
}
