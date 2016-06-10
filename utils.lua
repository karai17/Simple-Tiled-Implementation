-- Some utility functions that shouldn't be exposed.

local ffi = require "ffi"

return {
	-- https://github.com/stevedonovan/Penlight/blob/master/lua/pl/path.lua#L286
	format_path = function(path)
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
	end,

	-- Compensation for scale/rotation shift
	compensate = function(tile, x, y, tw, th)
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
	end,

	-- Cache images in main STI module
	cache_image = function(sti, path)
		local image = love.graphics.newImage(path)
		image:setFilter("nearest", "nearest")
		sti.cache[path] = image
	end,

	-- We just don't know.
	get_tiles = function(iw, tw, m, s)
		iw = iw - m
		local n = 0

		while iw >= tw do
			iw = iw - tw
			if n ~= 0  then iw = iw - s end
			if iw >= 0 then n  = n + 1  end
		end

		return n
	end,

	-- Decompress tile layer data
	get_decompressed_data = function(data)
		local d       = {}
		local decoded = ffi.cast("uint32_t*", data)

		for i=0, data:len() / ffi.sizeof("uint32_t") do
			table.insert(d, tonumber(decoded[i]))
		end

		return d
	end,

	-- Convert a Tiled ellipse object to a LOVE polygon
	convert_ellipse_to_polygon = function(x, y, w, h, max_segments)
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
			if love and love.physics then
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
	end,

	rotate_vertex = function(self, map, vertex, x, y, cos, sin)
		if map.orientation == "isometric" then
			x, y               = self.convert_isometric_to_screen(map, x, y)
			vertex.x, vertex.y = self.convert_isometric_to_screen(map, vertex.x, vertex.y)
		end

		vertex.x = vertex.x - x
		vertex.y = vertex.y - y

		local vx = cos * vertex.x - sin * vertex.y
		local vy = sin * vertex.x + cos * vertex.y

		return vx + x, vy + y
	end,

	--- Project isometric position to cartesian position
	convert_isometric_to_screen = function(map, x, y)
		local mh = map.height
		local tw = map.tilewidth
		local th = map.tileheight
		local ox = mh * tw / 2

		local tx = x / th
		local ty = y / th


		local sx = (tx - ty) * tw / 2 + ox
		local sy = (tx + ty) * th / 2

		return sx, sy
	end
}
